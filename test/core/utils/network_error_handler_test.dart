import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/errors/app_exception.dart';
import 'package:pka_home/core/utils/network_error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('NetworkErrorHandler Tests', () {
    test('Xử lý SocketException trả về thông báo mất mạng thân thiện', () {
      final error = const SocketException('Failed host lookup: db.supabase.co');
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, contains('Không có kết nối mạng'));
    });

    test('Xử lý TimeoutException trả về thông báo quá thời gian', () {
      final error = TimeoutException('Connection timed out');
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, contains('Kết nối máy chủ quá lâu'));
    });

    test('Xử lý PostgrestException 08006 / 08001 lỗi máy chủ', () {
      final error1 = PostgrestException(message: 'Connection failure', code: '08006');
      final error2 = PostgrestException(message: 'Cannot connect', code: '08001');
      expect(NetworkErrorHandler.getMessage(error1), contains('Không thể kết nối đến hệ thống'));
      expect(NetworkErrorHandler.getMessage(error2), contains('Không thể kết nối đến hệ thống'));
    });

    test('Xử lý PostgrestException 23505 trùng lặp slot/dữ liệu', () {
      final error = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, contains('Khung giờ vừa được người khác đặt'));
    });

    test('Xử lý PostgrestException 23503 vi phạm khóa ngoại liên kết dữ liệu', () {
      final error = PostgrestException(
        message: 'violates foreign key constraint',
        code: '23503',
      );
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, contains('Không thể xóa dữ liệu này vì đang được liên kết'));
    });

    test('Xử lý PostgrestException có thông báo tiếng Việt từ PostgreSQL RAISE EXCEPTION', () {
      final error = PostgrestException(
        message: 'Căn hộ đã đạt tối đa 2 xe máy',
      );
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, equals('Căn hộ đã đạt tối đa 2 xe máy'));
    });

    test('Xử lý Exception thông thường dạng chuỗi mạng', () {
      final error = Exception('ClientException with SocketException');
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, contains('Không có kết nối mạng'));
    });

    test('Xử lý AppException trả về nguyên vẹn thông điệp tiếng Việt', () {
      const error = AppException('Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy.');
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, equals('Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy.'));
    });

    test('Xử lý Exception thông thường chứa tiếng Việt có chủ đích', () {
      final error = Exception('Căn hộ đã đạt giới hạn tối đa 2 xe máy');
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, equals('Căn hộ đã đạt giới hạn tối đa 2 xe máy'));
    });

    test('Xử lý PostgrestException P0001 trả về thông báo lỗi nghiệp vụ', () {
      final error = PostgrestException(
        message: 'Khung giờ đặt đã trôi qua so với thời gian hiện tại',
        code: 'P0001',
      );
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, equals('Khung giờ đặt đã trôi qua so với thời gian hiện tại'));
    });

    test('Lọc lỗi SQL tiếng Anh thô (như UUID syntax) về thông báo tiếng Việt an toàn', () {
      final error = PostgrestException(
        message: 'invalid input syntax for type uuid: "abc"',
        code: '22P02',
      );
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, equals('Đã xảy ra lỗi. Vui lòng thử lại.'));
    });

    test('Xử lý AuthException trả về message gốc của auth', () {
      final error = AuthException('Email hoặc mật khẩu không chính xác.');
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, equals('Email hoặc mật khẩu không chính xác.'));
    });

    test('Xử lý lỗi bất định khác trả về thông báo an toàn mặc định', () {
      final error = FormatException('Bad format');
      final msg = NetworkErrorHandler.getMessage(error);
      expect(msg, equals('Đã xảy ra lỗi. Vui lòng thử lại.'));
    });
  });
}

