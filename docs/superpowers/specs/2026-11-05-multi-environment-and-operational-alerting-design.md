# Đặc Tả Thiết Kế: Hạ Tầng Đa Môi Trường (Dev/Staging/Prod) & Giám Sát Cảnh Báo Vận Hành (F1)

## 1. Tổng Quan & Mục Tiêu

Trong quy trình vận hành và thương mại hóa nền tảng Quản lý Chung cư PKA-Home, việc tách bạch các môi trường triển khai và thiết lập cơ chế giám sát sự cố thời gian thực là yếu tố sống còn nhằm đảm bảo:
1. **Cô lập dữ liệu tuyệt đối (Data Isolation):** Các hoạt động kiểm thử tính năng mới, tạo mock data, chạy load test ở môi trường Phát triển (Dev) hoặc Tiền phát hành (Staging) không được phép ảnh hưởng đến cơ sở dữ liệu Vận hành thực tế (Production).
2. **Quản lý cấu hình linh hoạt (Configuration Management):** Hỗ trợ cấu hình qua cờ biên dịch `--dart-define=APP_ENV=...` kết hợp nạp file `.env.[environment]` tương ứng theo chuẩn 12-Factor App.
3. **Giám sát & Cảnh báo chủ động (Proactive Operational Alerting):** Phát hiện tức thì các sự cố P0/P1 (Lỗi quỹ bảo trì, Lỗi gạch nợ thanh toán, Tấn công Brute-force) và gửi cảnh báo trực tiếp về nhóm Kỹ thuật/DevOps qua kênh Telegram Bot và Slack Webhook.
4. **Cơ chế chống bão cảnh báo (Alert Throttling/Debouncing):** Khóa trùng lặp cảnh báo trong 60 giây, tránh tình trạng spam hàng trăm tin nhắn gây nghẽn kênh liên lạc khi có vòng lặp lỗi.
5. **Kiểm tra sức khỏe hệ thống (Uptime Health Check):** Tự động đo độ trễ (latency) và kiểm tra khả năng kết nối tới cơ sở dữ liệu Supabase.

---

## 2. Kiến Trúc & Cấu Trúc Thư Mục

```text
.env.development.example                       # Mẫu cấu hình môi trường Phát triển
.env.staging.example                           # Mẫu cấu hình môi trường Kiểm thử (Staging)
.env.production.example                        # Mẫu cấu hình môi trường Sản phẩm (Production)
lib/
├── core/
│   ├── config/
│   │   └── app_environment.dart               # Quản lý cấu hình môi trường Dev/Staging/Prod
│   └── services/
│       ├── operational_alert_service.dart     # Dịch vụ gửi cảnh báo Telegram/Slack & Health Check
│       └── operational_alert_provider.dart    # Riverpod provider cho OperationalAlertService
test/
├── core/
│   ├── config/
│   │   └── app_environment_test.dart          # Unit test cấu hình đa môi trường
│   └── services/
│       └── operational_alert_service_test.dart # Unit test gửi cảnh báo, throttling, health check
```

---

## 3. Đặc Tả Chi Tiết Từng Thành Phần

### 3.1. Cấu Hình Đa Môi Trường (`AppEnvironment`)

- **Enum môi trường:**
  ```dart
  enum AppEnvironmentType {
    dev,
    staging,
    prod,
  }
  ```
- **Nguyên tắc nạp cấu hình:**
  1. Đọc cờ `--dart-define=APP_ENV=dev|staging|prod` (mặc định là `dev` nếu không truyền).
  2. Nạp file `.env.[environment]` tương ứng (ví dụ `.env.development`, `.env.staging`, `.env.production`). Nếu không tìm thấy, tự động fallback sang `.env` hoặc `.env.example`.
  3. Giá trị từ `--dart-define` luôn có độ ưu tiên cao nhất, đè lên giá trị trong file `.env`.
- **Các trường thuộc tính chính:**
  - `type`: `AppEnvironmentType`
  - `name`: Tên định danh tiếng Việt chuẩn ("Phát triển", "Kiểm thử (Staging)", "Sản phẩm (Production)")
  - `apiBaseUrl`: URL máy chủ backend/edge functions
  - `supabaseUrl`: URL dự án Supabase tương ứng của từng môi trường
  - `supabaseAnonKey`: Publishable key tương ứng
  - `isProduction`: `bool` (chỉ true khi `type == AppEnvironmentType.prod`)
  - `enableDebugLogging`: `bool` (tắt trên Production)
  - `telegramBotToken`: Token của bot Telegram nhận cảnh báo
  - `telegramChatId`: ID phòng chat / kênh nhận thông báo sự cố
  - `slackWebhookUrl`: URL Incoming Webhook của Slack/Discord

---

### 3.2. Dịch Vụ Cảnh Báo Vận Hành (`OperationalAlertService`)

- **Phân cấp mức độ sự cố (`AlertSeverity`):**
  - `info`: Thông tin vận hành (Khởi động hệ thống, hoàn tất backup).
  - `warning`: Cảnh báo chậm trễ, tỷ lệ retry cao, phản hồi mạng suy giảm.
  - `critical`: Sự cố P0 nghiêm trọng (Lỗi sai lệch quỹ bảo trì, lỗi thanh toán ngân hàng, Brute-force liên tục).

- **Cấu trúc dữ liệu cảnh báo (`OperationalAlert`):**
  ```dart
  class OperationalAlert {
    final String title;
    final String message;
    final AlertSeverity severity;
    final String? errorCode;
    final Map<String, dynamic>? metadata;
    final DateTime timestamp;
  }
  ```

- **Cơ chế chống bão cảnh báo (Throttling & Debouncing):**
  - Duy trì bảng băm in-memory `Map<String, DateTime> _lastAlertTimes`.
  - Khóa trùng lặp (Deduplication key) cấu thành từ: `[severity]:[errorCode ?? title]`.
  - Nếu khoảng thời gian giữa 2 lần gửi của cùng một khóa nhỏ hơn `cooldownDuration` (mặc định 60 giây), cảnh báo mới sẽ bị chặn (suppressed) và trả về `AlertDispatchResult.throttled`.

- **Kênh thông báo Telegram:**
  - Định dạng tin nhắn chuẩn HTML:
    ```html
    <b>[PKA-HOME] CẢNH BÁO HỆ THỐNG: CRITICAL</b>
    <b>Môi trường:</b> Sản phẩm (Production)
    <b>Mã lỗi:</b> SEC_BRUTE_FORCE
    <b>Tiêu đề:</b> Phát hiện tấn công dò mật khẩu
    <b>Chi tiết:</b> Tài khoản 0901234567 bị khóa sau 5 lần nhập sai
    <b>Thời gian:</b> 2026-11-05 13:30:00
    ```
  - Gọi HTTP POST `https://api.telegram.org/bot<token>/sendMessage`.

- **Kênh thông báo Slack / Discord:**
  - Định dạng JSON Payload:
    ```json
    {
      "text": "[PKA-HOME ALERT - CRITICAL]: Phát hiện tấn công dò mật khẩu",
      "blocks": [
        {
          "type": "header",
          "text": {"type": "plain_text", "text": "CẢNH BÁO VẬN HÀNH PKA-HOME"}
        },
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "*Mức độ:* CRITICAL\n*Môi trường:* Production\n*Chi tiết:* Tài khoản 0901234567 bị khóa"}
        }
      ]
    }
    ```

- **Kiểm tra sức khỏe hệ thống (Health Check Ping):**
  - Thực hiện lệnh truy vấn siêu nhẹ (ping) tới máy chủ CSDL Supabase.
  - Đo thời gian phản hồi (round-trip latency).
  - Trả về `HealthStatus`: `isHealthy`, `latencyMs`, `message`.

---

## 4. Kế Hoạch Kiểm Thử Tự Động (TDD)

1. **`app_environment_test.dart`:**
   - Parse môi trường từ string (`dev`, `staging`, `prod`).
   - Kiểm tra giá trị mặc định khi thiếu cấu hình.
   - Kiểm tra các cờ logic (`isProduction`, `enableDebugLogging`).
2. **`operational_alert_service_test.dart`:**
   - Mock HTTP Client giả lập phản hồi thành công và thất bại.
   - Kiểm thử định dạng tin nhắn gửi Telegram Bot API.
   - Kiểm thử payload gửi Slack Webhook.
   - Kiểm thử cơ chế Throttling: gửi 2 cảnh báo giống nhau trong vòng 10 giây -> cảnh báo thứ hai bị khóa lại.
   - Kiểm thử Health Check: giả lập ping thành công và timeout/lỗi.
