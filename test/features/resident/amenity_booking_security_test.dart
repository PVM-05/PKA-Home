import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/network_error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Kiểm thử bảo mật RPC book_amenity_slot', () {
    test('Xử lý lỗi từ chối căn hộ không thuộc quyền sở hữu', () {
      final exception = PostgrestException(
        message: 'Bạn không có quyền đặt tiện ích cho căn hộ này',
        code: 'P0001',
      );
      final msg = NetworkErrorHandler.getMessage(exception);
      expect(msg, contains('Bạn không có quyền'));
    });

    test('Xử lý lỗi vượt sức chứa tối đa', () {
      final exception = PostgrestException(
        message: 'Khung giờ này đã đủ số lượng đặt tối đa (Hết chỗ)',
        code: 'P0001',
      );
      final msg = NetworkErrorHandler.getMessage(exception);
      expect(msg, contains('Hết chỗ'));
    });
  });
}
