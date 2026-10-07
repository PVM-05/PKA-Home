import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/error_formatter.dart';
import 'package:pka_home/core/utils/network_error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Unified Error Handling Tests', () {
    test('Handles SocketException and network issues gracefully', () {
      const socketEx = SocketException('Failed host lookup');
      expect(NetworkErrorHandler.getMessage(socketEx), contains('Không có kết nối mạng'));
      expect(formatErrorMessage(socketEx), contains('Không có kết nối mạng'));
    });

    test('Handles TimeoutException gracefully', () {
      final timeoutEx = TimeoutException('Timed out');
      expect(NetworkErrorHandler.getMessage(timeoutEx), contains('Kết nối máy chủ quá lâu'));
      expect(formatErrorMessage(timeoutEx), contains('Kết nối máy chủ quá lâu'));
    });

    test('Preserves Vietnamese message from PostgreSQL triggers and RPCs', () {
      const pgEx = PostgrestException(
        message: 'Đồng hồ nước không thể quay ngược: chỉ số mới phải lớn hơn hoặc bằng chỉ số cũ',
        code: 'P0001',
      );
      expect(NetworkErrorHandler.getMessage(pgEx), contains('Đồng hồ nước không thể quay ngược'));
      expect(formatErrorMessage(pgEx), contains('Đồng hồ nước không thể quay ngược'));
    });

    test('Maps common PostgreSQL error codes to friendly Vietnamese messages', () {
      const dupEx = PostgrestException(message: 'duplicate key value', code: '23505');
      expect(NetworkErrorHandler.getMessage(dupEx), contains('đã tồn tại'));

      const permEx = PostgrestException(message: 'permission denied', code: '42501');
      expect(NetworkErrorHandler.getMessage(permEx), contains('không có quyền'));

      const fkEx = PostgrestException(message: 'foreign key constraint', code: '23503');
      expect(NetworkErrorHandler.getMessage(fkEx), contains('liên kết'));
    });

    test('Maps AuthException to friendly Vietnamese messages', () {
      const credEx = AuthException('Invalid login credentials');
      expect(NetworkErrorHandler.getMessage(credEx), contains('Email hoặc mật khẩu không chính xác'));
      expect(formatErrorMessage(credEx), contains('Email hoặc mật khẩu không chính xác'));

      const regEx = AuthException('User already registered');
      expect(NetworkErrorHandler.getMessage(regEx), contains('đã được đăng ký'));
    });

    test('Source code check: bulk_invoice_dialog.dart does not use raw \$e error string', () {
      final file = File('lib/features/management/widgets/bulk_invoice_dialog.dart');
      final content = file.readAsStringSync();
      expect(content.contains(r'Lỗi khi kiểm tra dữ liệu: $e'), isFalse);
      expect(content.contains(r'Lỗi khi tạo hóa đơn hàng loạt: $e'), isFalse);
    });
  });
}
