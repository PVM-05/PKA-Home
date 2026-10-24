// Supabase Edge Function: send-fcm-notification
// Nhiệm vụ: Lắng nghe Database Webhook khi có bản ghi mới trong bảng `public.notifications`
// Truy vấn FCM token của người nhận từ `public.user_fcm_tokens` và gửi Push Notification qua Firebase HTTP v1 API.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/**
 * Mã hóa dữ liệu sang dạng Base64URL
 */
function base64UrlEncode(data: Uint8Array | string): string {
  const uint8 = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (let i = 0; i < uint8.length; i++) {
    binary += String.fromCharCode(uint8[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/**
 * Chuyển chuỗi PEM PKCS#8 private key sang mảng nhị phân Uint8Array
 */
function pemToBinary(pem: string): Uint8Array {
  const cleanPem = pem
    .replace(/-----BEGIN[ A-Z0-9_-]+-----/g, "")
    .replace(/-----END[ A-Z0-9_-]+-----/g, "")
    .replace(/\s+/g, "");
  const raw = atob(cleanPem);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    buf[i] = raw.charCodeAt(i);
  }
  return buf;
}

/**
 * Sinh Google OAuth 2.0 Access Token dùng Google Service Account và Web Crypto API
 */
async function getGoogleAccessToken(clientEmail: string, privateKeyPem: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaimSet}`;

  const keyData = pemToBinary(privateKeyPem);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: { name: "SHA-256" },
    },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const encodedSignature = base64UrlEncode(new Uint8Array(signature));
  const jwt = `${unsignedToken}.${encodedSignature}`;

  // Đổi JWT lấy Access Token từ Google OAuth 2.0
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const errText = await tokenRes.text();
    throw new Error(`Google OAuth error (${tokenRes.status}): ${errText}`);
  }

  const tokenJson = await tokenRes.json();
  return tokenJson.access_token;
}

/**
 * Trích xuất cấu hình Firebase Service Account từ biến môi trường
 */
function getFirebaseCredentials(): { projectId: string; clientEmail: string; privateKey: string } | null {
  const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (serviceAccountRaw) {
    try {
      const sa = JSON.parse(serviceAccountRaw);
      if (sa.project_id && sa.client_email && sa.private_key) {
        return {
          projectId: sa.project_id,
          clientEmail: sa.client_email,
          privateKey: sa.private_key,
        };
      }
    } catch (_) {
      // Bỏ qua lỗi parse JSON để thử các biến môi trường đơn lẻ
    }
  }

  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n");

  if (projectId && clientEmail && privateKey) {
    return { projectId, clientEmail, privateKey };
  }

  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const notification = payload.record; // Dữ liệu bản ghi mới từ webhook bảng notifications

    if (!notification || !notification.user_id) {
      return new Response(JSON.stringify({ message: "No recipient user_id found" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Xác thực nguồn gọi an toàn: Service Role, Webhook Secret hoặc kiểm tra chéo bản ghi CSDL
    const authHeader = req.headers.get("Authorization");
    const webhookSecret = req.headers.get("x-webhook-secret");
    const expectedSecret = Deno.env.get("FCM_WEBHOOK_SECRET");
    const isServiceRole = authHeader === `Bearer ${supabaseServiceKey}`;
    const isSecretMatch = Boolean(expectedSecret && webhookSecret === expectedSecret);

    if (!isServiceRole && !isSecretMatch) {
      if (!notification.id) {
        return new Response(JSON.stringify({ error: "Unauthorized: Missing notification verification" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      // Kiểm tra chéo: Bản ghi thông báo phải thực sự tồn tại trong CSDL và gắn đúng recipient user_id
      const { data: dbNotif, error: verifyError } = await supabase
        .from("notifications")
        .select("id, user_id")
        .eq("id", notification.id)
        .eq("user_id", notification.user_id)
        .maybeSingle();

      if (verifyError || !dbNotif) {
        return new Response(JSON.stringify({ error: "Forbidden: Notification record does not exist or recipient mismatch" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

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

    // 2. Lấy thông tin xác thực Firebase Service Account
    const credentials = getFirebaseCredentials();
    if (!credentials) {
      return new Response(JSON.stringify({ 
        message: "Firebase Service Account not configured. Notification saved to database for in-app display.",
        inAppOnly: true 
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Lấy Google OAuth 2.0 Access Token
    const accessToken = await getGoogleAccessToken(credentials.clientEmail, credentials.privateKey);

    // 4. Gửi thông báo đến từng thiết bị qua Firebase Cloud Messaging HTTP v1 API
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${credentials.projectId}/messages:send`;
    
    const sendResults = await Promise.all(
      tokens.map(async ({ token }) => {
        try {
          const response = await fetch(fcmEndpoint, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: token,
                notification: {
                  title: notification.title || "Thông báo mới",
                  body: notification.body || notification.content || "",
                },
                data: {
                  notification_id: String(notification.id ?? ""),
                  type: String(notification.type ?? "general"),
                  created_at: String(notification.created_at ?? ""),
                },
              },
            }),
          });

          if (!response.ok) {
            const resText = await response.text();
            // Nếu token không còn hợp lệ (UNREGISTERED / NOT_FOUND), tự động dọn dẹp khỏi CSDL
            if (response.status === 404 || resText.includes("UNREGISTERED") || resText.includes("NOT_FOUND")) {
              await supabase.from("user_fcm_tokens").delete().eq("token", token);
            }
            return false;
          }

          return true;
        } catch (_) {
          return false;
        }
      })
    );

    const successCount = sendResults.filter(Boolean).length;
    const isSuccess = successCount > 0;

    return new Response(JSON.stringify({ 
      success: isSuccess, 
      sentCount: successCount,
      totalTokens: tokens.length,
      message: isSuccess 
        ? `Successfully sent to ${successCount}/${tokens.length} devices` 
        : "Failed to deliver to any registered devices"
    }), {
      status: isSuccess ? 200 : 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
