// Supabase Edge Function: vnpay-ipn
// Nhiệm vụ: Tiếp nhận IPN (Instant Payment Notification) từ cổng thanh toán trực tuyến VNPay.
// Thẩm định chữ ký số HMAC-SHA512, sau đó kích hoạt RPC `process_bank_payment_webhook` bằng service_role để tự động gạch nợ.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("ALLOWED_ORIGIN") || "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

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
 * Tạo chuỗi hash data chuẩn hóa từ danh sách tham số VNPay
 */
function buildVnpaySignData(params: Record<string, string>): string {
  const sortedKeys = Object.keys(params)
    .filter((k) => k.startsWith("vnp_") && k !== "vnp_SecureHash" && k !== "vnp_SecureHashType")
    .sort();

  const pairs: string[] = [];
  for (const key of sortedKeys) {
    const val = params[key];
    if (val !== undefined && val !== null && val.length > 0) {
      pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(val)}`);
    }
  }
  return pairs.join("&");
}

serve(async (req: Request) => {
  // Xử lý Preflight CORS Request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const params: Record<string, string> = {};

    // 1. Trích xuất tham số từ Query Params (GET) hoặc URLSearchParams (POST)
    if (req.method === "GET") {
      url.searchParams.forEach((val, key) => {
        params[key] = val;
      });
    } else if (req.method === "POST") {
      const contentType = req.headers.get("content-type") || "";
      if (contentType.includes("application/x-www-form-urlencoded")) {
        const bodyText = await req.text();
        const bodyParams = new URLSearchParams(bodyText);
        bodyParams.forEach((val, key) => {
          params[key] = val;
        });
      } else if (contentType.includes("application/json")) {
        const json = await req.json();
        for (const [key, val] of Object.entries(json)) {
          params[key] = String(val);
        }
      } else {
        // Dự phòng query string trên URL nếu POST body rỗng
        url.searchParams.forEach((val, key) => {
          params[key] = val;
        });
      }
    }

    const secureHash = params["vnp_SecureHash"] || "";
    const tmnCode = params["vnp_TmnCode"] || "";
    const responseCode = params["vnp_ResponseCode"] || "";
    const transactionStatus = params["vnp_TransactionStatus"] || "";
    const txnRef = params["vnp_TxnRef"] || "";
    const amountStr = params["vnp_Amount"] || "0";
    const orderInfo = params["vnp_OrderInfo"] || "";
    const transactionNo = params["vnp_TransactionNo"] || txnRef;

    if (!secureHash) {
      console.error("[VNPay IPN]: Thiếu tham số chữ ký vnp_SecureHash");
      return new Response(
        JSON.stringify({ RspCode: "97", Message: "Thieu chu ky xac thuc vnp_SecureHash" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Kết nối Supabase với Service Role Key
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("[VNPay IPN Error]: Thiếu cấu hình SUPABASE_URL hoặc SUPABASE_SERVICE_ROLE_KEY.");
      return new Response(
        JSON.stringify({ RspCode: "99", Message: "Loi he thong may chu" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 3. Tìm cấu hình Secret Key tương ứng với TMN Code (Fail-Closed & Tenant-Scoped theo building_id)
    let hashSecret = "";
    let verifiedBuildingId: string | null = null;

    if (!tmnCode) {
      return new Response(
        JSON.stringify({ RspCode: "01", Message: "Thieu ma merchant vnp_TmnCode" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: configData } = await supabase
      .from("building_payment_configs")
      .select("building_id, vnpay_is_active")
      .eq("vnpay_tmn_code", tmnCode)
      .eq("vnpay_is_active", true)
      .limit(1)
      .maybeSingle();

    if (configData && configData.building_id) {
      verifiedBuildingId = configData.building_id;
      const { data: secretData } = await supabase
        .from("building_payment_secrets")
        .select("vnpay_hash_secret")
        .eq("building_id", configData.building_id)
        .maybeSingle();

      if (secretData && secretData.vnpay_hash_secret) {
        hashSecret = secretData.vnpay_hash_secret;
      }
    }

    if (!hashSecret || !verifiedBuildingId) {
      console.error(`[VNPay IPN]: Khong tim thay cau hinh active cho TMN Code: ${tmnCode}`);
      return new Response(
        JSON.stringify({ RspCode: "01", Message: "Khong tim thay cau hinh merchant hoac chua kich hoat" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Kiểm tra chữ ký số HMAC-SHA512 bằng so sánh hằng thời gian (không log expectedHash)
    const signData = buildVnpaySignData(params);
    const expectedHash = await computeHmacSha512(hashSecret, signData);

    if (!constantTimeEqual(expectedHash.toLowerCase(), secureHash.toLowerCase())) {
      console.error(`[VNPay IPN]: Sai chu ky HMAC-SHA512 cho TMN=${tmnCode}, TxnRef=${txnRef}`);
      return new Response(
        JSON.stringify({ RspCode: "97", Message: "Chu ky khong hop le (Invalid Checksum)" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Kiểm tra kết quả giao dịch từ VNPay
    if (responseCode !== "00" || (transactionStatus && transactionStatus !== "00")) {
      console.warn(`[VNPay IPN]: Giao dich that bai tai VNPay. Ma loi: ${responseCode}`);
      return new Response(
        JSON.stringify({ RspCode: "00", Message: "Giao dich that bai, da xac nhan ghi nhan" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Số tiền VNPay trả về nhân 100 lần (VND * 100)
    const amount = Number(amountStr) / 100;
    const basePaymentCode = txnRef.split("_")[0] || txnRef;

    // 7. Gọi RPC `process_bank_payment_webhook` kèm verified_building_id chống Cross-Tenant Spoofing
    const { data: rpcResult, error: rpcError } = await supabase.rpc(
      "process_bank_payment_webhook",
      {
        p_payload: {
          gateway_transaction_id: transactionNo || txnRef,
          content: orderInfo || basePaymentCode,
          amount: amount,
          payment_code: basePaymentCode,
          verified_building_id: verifiedBuildingId,
          vnp_txn_ref: txnRef,
          vnp_bank_code: params["vnp_BankCode"] || "",
          vnp_pay_date: params["vnp_PayDate"] || "",
          raw_gateway: "VNPAY",
        },
      }
    );

    if (rpcError) {
      console.error("[VNPay IPN RPC Error]:", rpcError);
      return new Response(
        JSON.stringify({ RspCode: "99", Message: rpcError.message || "Loi khi cap nhat hoa don" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 8. Đánh giá trạng thái trả về từ RPC
    if (rpcResult && rpcResult.status === "DUPLICATE") {
      return new Response(
        JSON.stringify({ RspCode: "02", Message: "Giao dich da duoc cap nhat truoc do" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (rpcResult && rpcResult.status === "UNMATCHED") {
      return new Response(
        JSON.stringify({ RspCode: "01", Message: "Khong tim thay hoa don tuong ung" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.info(`[VNPay IPN]: Gach no thanh cong giao dich ${transactionNo} cho hoa don ${txnRef}`);
    return new Response(
      JSON.stringify({ RspCode: "00", Message: "Confirm Success" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[VNPay IPN Exception]:", err);
    return new Response(
      JSON.stringify({ RspCode: "99", Message: err.message || "Loi he thong khong xac dinh" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

