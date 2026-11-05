import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Định nghĩa các loại môi trường triển khai của hệ thống PKA-Home
enum AppEnvironmentType {
  dev,
  staging,
  prod;

  /// Chuyển đổi từ chuỗi sang AppEnvironmentType
  static AppEnvironmentType parse(String? value) {
    if (value == null) return AppEnvironmentType.dev;
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'prod':
      case 'production':
        return AppEnvironmentType.prod;
      case 'staging':
      case 'stage':
        return AppEnvironmentType.staging;
      case 'dev':
      case 'development':
      default:
        return AppEnvironmentType.dev;
    }
  }
}

/// Lớp quản lý cấu hình môi trường chuẩn 12-Factor App
class AppEnvironment {
  final AppEnvironmentType type;
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String telegramBotToken;
  final String telegramChatId;
  final String slackWebhookUrl;
  final bool enableDebugLogging;

  const AppEnvironment({
    required this.type,
    this.apiBaseUrl = '',
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.telegramBotToken = '',
    this.telegramChatId = '',
    this.slackWebhookUrl = '',
    required this.enableDebugLogging,
  });

  bool get isDevelopment => type == AppEnvironmentType.dev;
  bool get isStaging => type == AppEnvironmentType.staging;
  bool get isProduction => type == AppEnvironmentType.prod;

  /// Tên định danh môi trường chuẩn tiếng Việt
  String get displayName {
    switch (type) {
      case AppEnvironmentType.prod:
        return 'Sản phẩm (Production)';
      case AppEnvironmentType.staging:
        return 'Kiểm thử (Staging)';
      case AppEnvironmentType.dev:
        return 'Phát triển (Dev)';
    }
  }

  /// Khởi tạo AppEnvironment từ Map cấu hình (biến môi trường / dotenv)
  factory AppEnvironment.fromMap(Map<String, String?> map) {
    final envRaw = map['APP_ENV'];
    final envType = AppEnvironmentType.parse(envRaw);

    final apiBaseUrl = map['API_BASE_URL'] ?? '';
    final supabaseUrl = map['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = map['SUPABASE_ANON_KEY'] ?? '';
    final telegramBotToken = map['TELEGRAM_BOT_TOKEN'] ?? '';
    final telegramChatId = map['TELEGRAM_CHAT_ID'] ?? '';
    final slackWebhookUrl = map['SLACK_WEBHOOK_URL'] ?? '';

    // Mặc định bật debug logging cho dev/staging, tắt cho prod
    final explicitDebug = map['ENABLE_DEBUG_LOGGING'];
    final bool enableDebugLogging;
    if (explicitDebug != null && explicitDebug.isNotEmpty) {
      enableDebugLogging = explicitDebug.trim().toLowerCase() == 'true';
    } else {
      enableDebugLogging = envType != AppEnvironmentType.prod;
    }

    return AppEnvironment(
      type: envType,
      apiBaseUrl: apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      telegramBotToken: telegramBotToken,
      telegramChatId: telegramChatId,
      slackWebhookUrl: slackWebhookUrl,
      enableDebugLogging: enableDebugLogging,
    );
  }

  static AppEnvironment _current = const AppEnvironment(
    type: AppEnvironmentType.dev,
    enableDebugLogging: true,
  );

  /// Cấu hình môi trường hiện tại đang hoạt động
  static AppEnvironment get current => _current;

  /// Thiết lập môi trường phục vụ Unit Test
  static void setForTesting(AppEnvironment env) {
    _current = env;
  }

  /// Khởi tạo môi trường tự động từ compile-time define và dotenv
  static Future<AppEnvironment> initialize({
    Map<String, String>? overrides,
  }) async {
    const defineEnv = String.fromEnvironment('APP_ENV');
    final combinedMap = <String, String?>{};

    // 1. Lấy dữ liệu từ dotenv nếu đã nạp
    combinedMap.addAll(dotenv.env);

    // 2. Lấy dữ liệu từ compile-time defines nếu có
    if (defineEnv.isNotEmpty) {
      combinedMap['APP_ENV'] = defineEnv;
    }
    const defineApi = String.fromEnvironment('API_BASE_URL');
    if (defineApi.isNotEmpty) combinedMap['API_BASE_URL'] = defineApi;

    const defineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
    if (defineSupabaseUrl.isNotEmpty) combinedMap['SUPABASE_URL'] = defineSupabaseUrl;

    const defineSupabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (defineSupabaseKey.isNotEmpty) combinedMap['SUPABASE_ANON_KEY'] = defineSupabaseKey;

    const defineTelegramToken = String.fromEnvironment('TELEGRAM_BOT_TOKEN');
    if (defineTelegramToken.isNotEmpty) combinedMap['TELEGRAM_BOT_TOKEN'] = defineTelegramToken;

    const defineTelegramChat = String.fromEnvironment('TELEGRAM_CHAT_ID');
    if (defineTelegramChat.isNotEmpty) combinedMap['TELEGRAM_CHAT_ID'] = defineTelegramChat;

    const defineSlackWebhook = String.fromEnvironment('SLACK_WEBHOOK_URL');
    if (defineSlackWebhook.isNotEmpty) combinedMap['SLACK_WEBHOOK_URL'] = defineSlackWebhook;

    // 3. Đè overrides nếu được truyền vào
    if (overrides != null) {
      combinedMap.addAll(overrides);
    }

    _current = AppEnvironment.fromMap(combinedMap);

    if (kDebugMode && _current.enableDebugLogging) {
      debugPrint('[HỆ THỐNG] Đã khởi tạo cấu hình môi trường: ${_current.displayName}');
    }

    return _current;
  }
}
