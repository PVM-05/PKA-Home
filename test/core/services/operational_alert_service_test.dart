import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pka_home/core/config/app_environment.dart';
import 'package:pka_home/core/services/operational_alert_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  late MockHttpClient mockHttpClient;
  late AppEnvironment testEnv;

  setUp(() {
    mockHttpClient = MockHttpClient();
    testEnv = AppEnvironment.fromMap({
      'APP_ENV': 'production',
      'TELEGRAM_BOT_TOKEN': '123456:TEST_TOKEN',
      'TELEGRAM_CHAT_ID': '-100123456789',
      'SLACK_WEBHOOK_URL': 'https://hooks.slack.com/services/TEST/WEBHOOK/123',
    });
  });

  group('OperationalAlertService - Format tests', () {
    test('formatTelegramHtml tạo nội dung HTML chính xác với mã lỗi và metadata', () {
      final service = OperationalAlertService(
        environment: testEnv,
        httpClient: mockHttpClient,
      );

      final alert = OperationalAlert(
        title: 'Lỗi ghi nhận quỹ bảo trì',
        message: 'Số dư quỹ bảo trì không khớp với giao dịch ngân hàng',
        severity: AlertSeverity.critical,
        errorCode: 'MAINT_FUND_MISMATCH',
        metadata: {'diffAmount': 5000000, 'buildingId': 'b_01'},
        timestamp: DateTime(2026, 11, 5, 13, 0, 0),
      );

      final html = service.formatTelegramHtml(alert);

      expect(html, contains('<b>[PKA-HOME] CẢNH BÁO: CRITICAL</b>'));
      expect(html, contains('<b>Môi trường:</b> Sản phẩm (Production)'));
      expect(html, contains('<b>Mã lỗi:</b> MAINT_FUND_MISMATCH'));
      expect(html, contains('<b>Tiêu đề:</b> Lỗi ghi nhận quỹ bảo trì'));
      expect(html, contains('diffAmount: 5000000'));
    });

    test('formatSlackPayload tạo cấu trúc JSON đúng chuẩn Slack blocks', () {
      final service = OperationalAlertService(
        environment: testEnv,
        httpClient: mockHttpClient,
      );

      final alert = OperationalAlert(
        title: 'Cảnh báo nợ xấu tăng cao',
        message: 'Tỷ lệ căn hộ trễ hạn vượt ngưỡng 15%',
        severity: AlertSeverity.warning,
        errorCode: 'DEBT_SPIKE',
      );

      final payload = service.formatSlackPayload(alert);

      expect(payload['text'], contains('[PKA-HOME - WARNING]'));
      expect(payload['blocks'], isList);
      final blocks = payload['blocks'] as List;
      expect(blocks.isNotEmpty, isTrue);
    });
  });

  group('OperationalAlertService - Dispatch & Webhook tests', () {
    test('gửi cảnh báo thành công qua cả Telegram và Slack', () async {
      when(() => mockHttpClient.post(
            any(that: predicate<Uri>((u) => u.host == 'api.telegram.org')),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('{"ok": true}', 200));

      when(() => mockHttpClient.post(
            any(that: predicate<Uri>((u) => u.host == 'hooks.slack.com')),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('ok', 200));

      final service = OperationalAlertService(
        environment: testEnv,
        httpClient: mockHttpClient,
      );

      final alert = OperationalAlert(
        title: 'Sự cố P0: Hệ thống thanh toán gặp lỗi',
        message: 'Cổng thanh toán phản hồi 502',
        severity: AlertSeverity.critical,
        errorCode: 'PAYMENT_GW_502',
      );

      final result = await service.sendAlert(alert);

      expect(result.isSuccess, isTrue);
      expect(result.isThrottled, isFalse);
      expect(result.channelResults[AlertDispatchChannel.telegram], isTrue);
      expect(result.channelResults[AlertDispatchChannel.slack], isTrue);
    });

    test('cơ chế Throttling: cảnh báo trùng lặp trong 60s bị chặn không gửi lại', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('{"ok": true}', 200));

      final service = OperationalAlertService(
        environment: testEnv,
        httpClient: mockHttpClient,
        cooldownDuration: const Duration(seconds: 60),
      );

      final alert = OperationalAlert(
        title: 'Quá tải kết nối CSDL',
        message: 'Số lượng connection vượt 95%',
        severity: AlertSeverity.warning,
        errorCode: 'DB_POOL_EXHAUSTED',
      );

      // Lần 1: gửi thành công
      final result1 = await service.sendAlert(alert);
      expect(result1.isSuccess, isTrue);
      expect(result1.isThrottled, isFalse);

      // Lần 2: gửi ngay lập tức -> bị khóa bởi Throttling
      final result2 = await service.sendAlert(alert);
      expect(result2.isSuccess, isFalse);
      expect(result2.isThrottled, isTrue);
      expect(result2.errorMessage, contains('bị khóa lặp'));

      // Verify HTTP chỉ được gọi cho lần 1 (Telegram + Slack = 2 calls)
      verify(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(2);
    });
  });

  group('OperationalAlertService - Health Check tests', () {
    test('checkHealthStatus trả về healthy khi ping thành công', () async {
      final service = OperationalAlertService(
        environment: testEnv,
        httpClient: mockHttpClient,
        pingFunction: () async {
          await Future.delayed(const Duration(milliseconds: 20));
          return true;
        },
      );

      final status = await service.checkHealthStatus();

      expect(status.isHealthy, isTrue);
      expect(status.latencyMs, greaterThanOrEqualTo(0));
      expect(status.message, contains('Bình thường'));
    });

    test('checkHealthStatus trả về unhealthy khi ping thất bại hoặc exception', () async {
      final service = OperationalAlertService(
        environment: testEnv,
        httpClient: mockHttpClient,
        pingFunction: () async {
          throw Exception('Timeout kết nối máy chủ');
        },
      );

      final status = await service.checkHealthStatus();

      expect(status.isHealthy, isFalse);
      expect(status.message, contains('Timeout kết nối máy chủ'));
    });
  });
}
