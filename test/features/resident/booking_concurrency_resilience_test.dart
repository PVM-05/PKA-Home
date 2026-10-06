import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/core/utils/network_error_handler.dart';

void main() {
  group('Booking Concurrency & Anti-Double-Click Resilience Tests', () {
    test('Xử lý ngoại lệ 23505 trả về thông báo lỗi thân thiện thay vì crash', () {
      final conflictError = PostgrestException(
        message: 'duplicate key value violates unique constraint "uq_active_amenity_slot"',
        code: '23505',
      );

      final friendlyMsg = NetworkErrorHandler.getMessage(conflictError);
      expect(friendlyMsg, contains('Khung giờ vừa được người khác đặt'));
    });

    test('Xử lý ngoại lệ 23503 vi phạm khóa ngoại trả về thông báo an toàn', () {
      final fkError = PostgrestException(
        message: 'update or delete on table violates foreign key constraint',
        code: '23503',
      );

      final friendlyMsg = NetworkErrorHandler.getMessage(fkError);
      expect(friendlyMsg, contains('Không thể xóa dữ liệu này'));
    });
  });
}
