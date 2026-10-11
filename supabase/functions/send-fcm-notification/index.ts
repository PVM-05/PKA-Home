// Supabase Edge Function: send-fcm-notification
// Nhiệm vụ: Lắng nghe Database Webhook khi có bản ghi mới trong bảng `public.notifications`
// Truy vấn FCM token của người nhận từ `public.user_fcm_tokens` và gửi Push Notification qua Firebase HTTP v1 API.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const notification = payload.record; // Dữ liệu bản ghi mới từ webhook table notifications

    if (!notification || !notification.user_id) {
      return new Response(JSON.stringify({ message: "No recipient user_id found" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Lấy danh sách FCM token còn hiệu lực của user
    const { data: tokens, error: tokenError } = await supabase
      .from("user_fcm_tokens")
      .select("token")
      .eq("user_id", notification.user_id);

    if (tokenError || !tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: "No FCM tokens registered for user" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Cấu hình nội dung Push Notification
    const fcmServerKey = Deno.env.get("FIREBASE_SERVER_KEY");
    if (!fcmServerKey) {
      return new Response(JSON.stringify({ 
        message: "FIREBASE_SERVER_KEY not configured. Notification saved to database for in-app display.",
        inAppOnly: true 
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Gửi thông báo đến từng thiết bị
    const sendResults = await Promise.all(
      tokens.map(async ({ token }) => {
        const response = await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `key=${fcmServerKey}`,
          },
          body: JSON.stringify({
            to: token,
            notification: {
              title: notification.title,
              body: notification.body || notification.content || "",
              sound: "default",
            },
            data: {
              notification_id: notification.id,
              type: notification.type || "general",
              created_at: notification.created_at,
            },
          }),
        });
        return response.ok;
      })
    );

    return new Response(JSON.stringify({ 
      success: true, 
      sentCount: sendResults.filter(Boolean).length 
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
