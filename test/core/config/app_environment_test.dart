import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/config/app_environment.dart';

void main() {
  group('AppEnvironmentType enum tests', () {
    test('parse chuỗi môi trường hợp lệ', () {
      expect(AppEnvironmentType.parse('dev'), equals(AppEnvironmentType.dev));
      expect(AppEnvironmentType.parse('development'), equals(AppEnvironmentType.dev));
      expect(AppEnvironmentType.parse('staging'), equals(AppEnvironmentType.staging));
      expect(AppEnvironmentType.parse('stage'), equals(AppEnvironmentType.staging));
      expect(AppEnvironmentType.parse('prod'), equals(AppEnvironmentType.prod));
      expect(AppEnvironmentType.parse('production'), equals(AppEnvironmentType.prod));
    });

    test('parse chuỗi không xác định hoặc rỗng mặc định trả về dev', () {
      expect(AppEnvironmentType.parse(''), equals(AppEnvironmentType.dev));
      expect(AppEnvironmentType.parse(null), equals(AppEnvironmentType.dev));
      expect(AppEnvironmentType.parse('unknown_env'), equals(AppEnvironmentType.dev));
    });
  });

  group('AppEnvironment creation and properties tests', () {
    test('tạo môi trường development với cấu hình mặc định', () {
      final env = AppEnvironment.fromMap({
        'APP_ENV': 'dev',
        'API_BASE_URL': 'https://dev-api.pkahome.vn',
        'SUPABASE_URL': 'https://dev-supabase.pkahome.vn',
        'SUPABASE_ANON_KEY': 'dev_anon_key_mock_123',
        'TELEGRAM_BOT_TOKEN': 'dev_bot_token',
        'TELEGRAM_CHAT_ID': '-100123456789',
        'SLACK_WEBHOOK_URL': 'https://hooks.slack.com/services/dev',
      });

      expect(env.type, equals(AppEnvironmentType.dev));
      expect(env.isDevelopment, isTrue);
      expect(env.isStaging, isFalse);
      expect(env.isProduction, isFalse);
      expect(env.enableDebugLogging, isTrue);
      expect(env.displayName, equals('Phát triển (Dev)'));
      expect(env.apiBaseUrl, equals('https://dev-api.pkahome.vn'));
      expect(env.supabaseUrl, equals('https://dev-supabase.pkahome.vn'));
      expect(env.supabaseAnonKey, equals('dev_anon_key_mock_123'));
      expect(env.telegramBotToken, equals('dev_bot_token'));
      expect(env.telegramChatId, equals('-100123456789'));
      expect(env.slackWebhookUrl, equals('https://hooks.slack.com/services/dev'));
    });

    test('tạo môi trường staging', () {
      final env = AppEnvironment.fromMap({
        'APP_ENV': 'staging',
        'API_BASE_URL': 'https://staging-api.pkahome.vn',
        'SUPABASE_URL': 'https://staging-supabase.pkahome.vn',
        'SUPABASE_ANON_KEY': 'staging_anon_key_mock_456',
      });

      expect(env.type, equals(AppEnvironmentType.staging));
      expect(env.isDevelopment, isFalse);
      expect(env.isStaging, isTrue);
      expect(env.isProduction, isFalse);
      expect(env.enableDebugLogging, isTrue);
      expect(env.displayName, equals('Kiểm thử (Staging)'));
    });

    test('tạo môi trường production: tắt debug logging theo mặc định', () {
      final env = AppEnvironment.fromMap({
        'APP_ENV': 'prod',
        'API_BASE_URL': 'https://api.pkahome.vn',
        'SUPABASE_URL': 'https://db.pkahome.vn',
        'SUPABASE_ANON_KEY': 'prod_anon_key_mock_789',
      });

      expect(env.type, equals(AppEnvironmentType.prod));
      expect(env.isDevelopment, isFalse);
      expect(env.isStaging, isFalse);
      expect(env.isProduction, isTrue);
      expect(env.enableDebugLogging, isFalse);
      expect(env.displayName, equals('Sản phẩm (Production)'));
    });

    test('cho phép ghi đè cờ ENABLE_DEBUG_LOGGING tường minh', () {
      final envWithDebug = AppEnvironment.fromMap({
        'APP_ENV': 'prod',
        'ENABLE_DEBUG_LOGGING': 'true',
      });
      expect(envWithDebug.enableDebugLogging, isTrue);

      final envWithoutDebug = AppEnvironment.fromMap({
        'APP_ENV': 'dev',
        'ENABLE_DEBUG_LOGGING': 'false',
      });
      expect(envWithoutDebug.enableDebugLogging, isFalse);
    });

    test('AppEnvironment.setForTesting và current', () {
      final testEnv = AppEnvironment.fromMap({'APP_ENV': 'staging'});
      AppEnvironment.setForTesting(testEnv);

      expect(AppEnvironment.current.type, equals(AppEnvironmentType.staging));
    });
  });
}
