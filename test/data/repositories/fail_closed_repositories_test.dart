import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/guard_helper.dart';

void main() {
  group('FailClosedGuard Tests', () {
    test('Khi USE_MOCK=false (mặc định production), lỗi từ call() phải ném AppException', () async {
      // Đảm bảo cờ mock không bật
      expect(FailClosedGuard.useMock, isFalse);

      expect(
        () => FailClosedGuard.guard(
          operation: 'testFailClosed',
          call: () async => throw Exception('Supabase connection lost'),
          mockFallback: () => ['mock_data_should_not_be_returned'],
        ),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('testFailClosed'),
        )),
      );
    });

    test('Khi call() thành công, trả về đúng dữ liệu thật', () async {
      final result = await FailClosedGuard.guard(
        operation: 'testSuccess',
        call: () async => 'real_production_data',
        mockFallback: () => 'mock_data',
      );

      expect(result, equals('real_production_data'));
    });

    test('Nếu call() ném AppException thì giữ nguyên AppException không bọc lại', () async {
      expect(
        () => FailClosedGuard.guard(
          operation: 'testAppException',
          call: () async => throw const AppException('Lỗi nghiệp vụ tùy chỉnh'),
          mockFallback: () => 'mock_data',
        ),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          equals('Lỗi nghiệp vụ tùy chỉnh'),
        )),
      );
    });
  });
}
