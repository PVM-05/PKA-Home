// Supabase Edge Function: sepay-webhook
// Nhiệm vụ: Tiếp nhận Webhook thông báo biến động số dư ngân hàng 24/7 từ SePay (sepay.vn).
// Bảo mật: Thẩm định nghiêm ngặt API Key (Fail-Closed) trước khi chuyển tiếp vào RPC PostgreSQL.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("ALLOWED_ORIGIN") || "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-sepay-key",
};

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

serve(async (req: Request) => {
  // Xử lý Preflight CORS Request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Chỉ hỗ trợ phương thức POST cho Webhook SePay" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // 1. Trích xuất SePay API Key từ Header hoặc Query Param theo chuẩn SePay
    // SePay gửi header: `Authorization: Apikey <api_key>`
    const authHeader = req.headers.get("Authorization") || req.headers.get("authorization") || "";
    let apiKey = "";

    if (authHeader.startsWith("Apikey ")) {
      apiKey = authHeader.substring(7).trim();
    } else if (authHeader.startsWith("Bearer ")) {
      apiKey = authHeader.substring(7).trim();
    } else if (authHeader.length > 0) {
      apiKey = authHeader.trim();
    }

    if (!apiKey) {
      apiKey = req.headers.get("x-sepay-key") || req.headers.get("x-api-key") || "";
    }

    if (!apiKey) {
      const url = new URL(req.url);
      apiKey = url.searchParams.get("api_key") || "";
    }

    // Chặn đứng ngay tại vành đai Edge nếu thiếu API Key (Fail-Closed)
    if (!apiKey) {
      console.warn("[SePay Webhook Security]: Bị từ chối do thiếu API Key xác thực.");
      return new Response(
        JSON.stringify({
          success: false,
          error: "401 Unauthorized: Thiếu API Key xác thực Webhook SePay. Vui lòng cấu hình Authorization header.",
        }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Tùy chọn kiểm tra Master Key ở vành đai bằng so sánh hằng thời gian
    const masterEnvKey = Deno.env.get("SEPAY_WEBHOOK_MASTER_KEY");
    if (masterEnvKey && !constantTimeEqual(apiKey, masterEnvKey)) {
      console.warn("[SePay Webhook Security]: API Key không khớp với SEPAY_WEBHOOK_MASTER_KEY.");
      return new Response(
        JSON.stringify({
          success: false,
          error: "401 Unauthorized: Chữ ký / API Key xác thực Webhook không hợp lệ.",
        }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Parse JSON Payload từ SePay
    let payload: Record<string, any>;
    try {
      payload = await req.json();
    } catch (_e) {
      return new Response(
        JSON.stringify({ success: false, error: "400 Bad Request: Dữ liệu JSON không hợp lệ." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Khởi tạo Supabase Client với Service Role Key để gọi RPC nội bộ
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("[SePay Webhook Error]: Thiếu cấu hình SUPABASE_URL hoặc SUPABASE_SERVICE_ROLE_KEY.");
      return new Response(
        JSON.stringify({ success: false, error: "Lỗi cấu hình máy chủ cơ sở dữ liệu" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 4. Gọi RPC `process_sepay_webhook` với p_api_key bắt buộc để thẩm định đối chiếu trong DB
    const { data, error } = await supabase.rpc("process_sepay_webhook", {
      p_payload: payload,
      p_api_key: apiKey,
    });

    if (error) {
      console.error("[SePay Webhook RPC Error]:", error);
      const isAuthError = error.message?.includes("401") || error.message?.includes("API Key");
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: isAuthError ? 401 : 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Trả về HTTP 200 OK để SePay xác nhận Webhook thành công (tránh retry lặp)
    return new Response(
      JSON.stringify({
        success: true,
        message: "Đã xử lý biến động số dư SePay thành công",
        data: data,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[SePay Webhook Exception]:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Lỗi không xác định khi xử lý webhook" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
