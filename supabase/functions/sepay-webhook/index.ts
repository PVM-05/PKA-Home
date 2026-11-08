// Supabase Edge Function: sepay-webhook
// Nhiệm vụ: Tiếp nhận Webhook thông báo biến động số dư ngân hàng 24/7 từ SePay (sepay.vn).
// Chuyển tiếp payload vào hàm RPC ACID `process_sepay_webhook` trong PostgreSQL để tự động gạch nợ.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-sepay-key",
};

serve(async (req: Request) => {
  // Xử lý Preflight CORS Request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Chỉ hỗ trợ phương thức POST cho Webhook SePay" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // 1. Trích xuất SePay API Key từ Header hoặc Query Param
    const authHeader = req.headers.get("Authorization") || req.headers.get("authorization") || "";
    let apiKey = "";

    if (authHeader.startsWith("Apikey ")) {
      apiKey = authHeader.substring(7).trim();
    } else if (authHeader.startsWith("Bearer ")) {
      apiKey = authHeader.substring(7).trim();
    } else if (authHeader.isNotEmpty) {
      apiKey = authHeader.trim();
    }

    if (!apiKey) {
      apiKey = req.headers.get("x-sepay-key") || req.headers.get("x-api-key") || "";
    }

    if (!apiKey) {
      const url = new URL(req.url);
      apiKey = url.searchParams.get("api_key") || "";
    }

    // 2. Parse JSON Payload từ SePay
    const payload = await req.json();

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

    // 4. Gọi RPC `process_sepay_webhook` đã được tối ưu ACID & RLS
    const { data, error } = await supabase.rpc("process_sepay_webhook", {
      p_payload: payload,
      p_api_key: apiKey || null,
    });

    if (error) {
      console.error("[SePay Webhook RPC Error]:", error);
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
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
