// Supabase Edge Function: create-vnpay-url
// Nhiệm vụ: Khởi tạo URL thanh toán VNPay 2.1.0 phía server bảo mật (Server-Authoritative).
// Kiểm soát toàn vẹn tài chính từ DB, thẩm định quyền RBAC, đọc secret an toàn từ building_payment_secrets.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/**
 * Tính toán chữ ký HMAC-SHA512 theo chuẩn VNPay
 */
async function computeHmacSha512(secret: string, data: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Định dạng Date thành yyyyMMddHHmmss theo múi giờ Việt Nam (UTC+7)
 */
function formatVnpayDate(date: Date): string {
  // Chuyển sang giờ UTC+7
  const utc = date.getTime() + date.getTimezoneOffset() * 60000;
  const vnTime = new Date(utc + 7 * 3600000);

  const pad = (n: number) => n.toString().padStart(2, "0");
  const y = vnTime.getFullYear().toString();
  const m = pad(vnTime.getMonth() + 1);
  const d = pad(vnTime.getDate());
  const h = pad(vnTime.getHours());
  const min = pad(vnTime.getMinutes());
  const s = pad(vnTime.getSeconds());
  return `${y}${m}${d}${h}${min}${s}`;
}

serve(async (req: Request) => {
  // Xử lý Preflight CORS Request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Yêu cầu đăng nhập để khởi tạo thanh toán" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "").trim();

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: "Lỗi cấu hình Supabase phía máy chủ" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Xác thực người dùng qua JWT
    const { data: userData, error: authError } = await supabase.auth.getUser(token);
    if (authError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Phiên đăng nhập không hợp lệ hoặc đã hết hạn" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const userId = userData.user.id;

    // 2. Parse request body
    const body = await req.json().catch(() => ({}));
    const invoiceId = body.invoice_id as string | undefined;
    const bankCode = body.bank_code as string | undefined;

    if (!invoiceId) {
      return new Response(JSON.stringify({ error: "Thiếu mã định danh hóa đơn (invoice_id)" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Truy vấn thông tin Hóa đơn
    const { data: invoice, error: invoiceErr } = await supabase
      .from("invoices")
      .select("id, total_amount, payment_code, status, apartment_id")
      .eq("id", invoiceId)
      .maybeSingle();

    if (invoiceErr || !invoice) {
      return new Response(JSON.stringify({ error: "Không tìm thấy hóa đơn tương ứng" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (invoice.status === "paid") {
      return new Response(JSON.stringify({ error: "Hóa đơn này đã được thanh toán toàn bộ" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Kiểm tra phân quyền RBAC
    const { data: appUser } = await supabase
      .from("users")
      .select("role")
      .eq("id", userId)
      .maybeSingle();

    const role = appUser?.role ?? "resident";
    const isManagement = role === "admin" || role === "management";

    if (!isManagement) {
      // Nếu là cư dân, bắt buộc phải thuộc căn hộ của hóa đơn
      const { data: linkRecord } = await supabase
        .from("residents_apartments")
        .select("id")
        .eq("user_id", userId)
        .eq("apartment_id", invoice.apartment_id)
        .limit(1)
        .maybeSingle();

      if (!linkRecord) {
        return new Response(JSON.stringify({ error: "Bạn không có quyền thực hiện thanh toán cho căn hộ này" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // 5. Lấy building_id từ apartment
    const { data: apartment } = await supabase
      .from("apartments")
      .select("building_id")
      .eq("id", invoice.apartment_id)
      .maybeSingle();

    const buildingId = apartment?.building_id;
    if (!buildingId) {
      return new Response(JSON.stringify({ error: "Căn hộ không gắn với tòa nhà hợp lệ" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 6. Lấy cấu hình VNPay (2 bước độc lập)
    const { data: paymentConfig } = await supabase
      .from("building_payment_configs")
      .select("vnpay_tmn_code, vnpay_is_active")
      .eq("building_id", buildingId)
      .eq("is_active", true)
      .maybeSingle();

    if (!paymentConfig || !paymentConfig.vnpay_is_active || !paymentConfig.vnpay_tmn_code) {
      return new Response(JSON.stringify({ error: "Tòa nhà hiện chưa kích hoạt cổng thanh toán trực tuyến VNPay" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let hashSecret = Deno.env.get("VNPAY_HASH_SECRET") || "";
    const { data: secretData } = await supabase
      .from("building_payment_secrets")
      .select("vnpay_hash_secret")
      .eq("building_id", buildingId)
      .maybeSingle();

    if (secretData?.vnpay_hash_secret) {
      hashSecret = secretData.vnpay_hash_secret;
    }

    if (!hashSecret) {
      return new Response(JSON.stringify({ error: "Chưa cấu hình khóa bí mật VNPay cho tòa nhà" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 7. Tạo các tham số VNPay 2.1.0
    const rawIp = req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip") || "127.0.0.1";
    const ipAddr = rawIp.split(",")[0].trim();

    const returnUrl = Deno.env.get("VNPAY_RETURN_URL") || "https://pka-home.web.app/payment-result";
    const totalAmount = Number(invoice.total_amount) || 0;
    const vnpAmount = Math.round(totalAmount * 100).toString();
    const txnRef = invoice.payment_code;
    const createDate = formatVnpayDate(new Date());

    const params: Record<string, string> = {
      vnp_Version: "2.1.0",
      vnp_Command: "pay",
      vnp_TmnCode: paymentConfig.vnpay_tmn_code,
      vnp_Amount: vnpAmount,
      vnp_CurrCode: "VND",
      vnp_TxnRef: txnRef,
      vnp_OrderInfo: `Thanh toan hoa don ${txnRef}`,
      vnp_OrderType: "billpayment",
      vnp_Locale: "vn",
      vnp_ReturnUrl: returnUrl,
      vnp_IpAddr: ipAddr,
      vnp_CreateDate: createDate,
    };

    if (bankCode && bankCode.trim().length > 0) {
      params["vnp_BankCode"] = bankCode.trim();
    }

    // Sắp xếp tham số theo alphabet
    const sortedKeys = Object.keys(params).sort();
    const signPairs: string[] = [];
    const queryPairs: string[] = [];

    for (const key of sortedKeys) {
      const val = params[key];
      if (val !== undefined && val !== null && val.length > 0) {
        signPairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(val)}`);
        queryPairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(val)}`);
      }
    }

    const signData = signPairs.join("&");
    const secureHash = await computeHmacSha512(hashSecret, signData);
    queryPairs.push(`vnp_SecureHash=${secureHash}`);

    const isSandbox = Deno.env.get("VNPAY_IS_SANDBOX") !== "false";
    const baseEndpoint = isSandbox
      ? "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html"
      : "https://vnpayment.vn/paymentv2/vpcpay.html";

    const paymentUrl = `${baseEndpoint}?${queryPairs.join("&")}`;

    return new Response(
      JSON.stringify({
        success: true,
        payment_url: paymentUrl,
        txn_ref: txnRef,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("[create-vnpay-url error]:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Lỗi xử lý nội bộ máy chủ khi tạo liên kết VNPay" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
