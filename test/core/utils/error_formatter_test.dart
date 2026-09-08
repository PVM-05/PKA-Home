import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/core/utils/error_formatter.dart';

void main() {
  group('formatErrorMessage Tests', () {
    test('PostgrestException code 23505 returns friendly duplicate error', () {
      const error = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
      final result = formatErrorMessage(error);
      expect(result, contains('Dữ liệu đã tồn tại'));
    });

    test('PostgrestException code 42501 returns friendly permission error', () {
      const error = PostgrestException(
        message: 'permission denied for table apartments',
        code: '42501',
      );
      final result = formatErrorMessage(error);
      expect(result, contains('Bạn không có quyền'));
    });

    test('AuthException invalid credentials returns clear email/password error', () {
      const error = AuthException('Invalid login credentials');
      final result = formatErrorMessage(error);
      expect(result, contains('Email hoặc mật khẩu không chính xác'));
    });

    test('SocketException returns network error', () {
      const error = SocketException('Failed host lookup');
      final result = formatErrorMessage(error);
      expect(result, contains('kết nối mạng'));
    });

    test('Unknown error returns fallback', () {
      final result = formatErrorMessage(Exception('Random unexpected error'));
      expect(result, equals('Đã xảy ra lỗi, vui lòng thử lại sau.'));
    });
  });
}
