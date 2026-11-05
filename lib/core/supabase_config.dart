import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    // Ưu tiên 1: Đọc từ compile-time define (--dart-define)
    // Ưu tiên 2: Đọc từ file .env cục bộ (chỉ tồn tại trên máy dev, được bảo vệ bởi .gitignore)
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    const envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    final supabaseUrl = envUrl.isNotEmpty
        ? envUrl
        : (dotenv.env['SUPABASE_URL'] ?? '');
    final supabaseAnonKey = envAnonKey.isNotEmpty
        ? envAnonKey
        : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

    if (supabaseUrl.isEmpty ||
        supabaseAnonKey.isEmpty ||
        supabaseUrl.contains('your-project-ref')) {
      debugPrint(
        '[CẢNH BÁO BẢO MẬT]: Chưa tìm thấy SUPABASE_URL hoặc SUPABASE_ANON_KEY hợp lệ. '
        'Vui lòng cấu hình file .env cục bộ (từ .env.example) hoặc truyền qua --dart-define.',
      );
    } else if (!isValidKeyFormat(supabaseAnonKey)) {
      debugPrint(
        '[CẢNH BÁO BẢO MẬT]: Định dạng SUPABASE_ANON_KEY không đạt chuẩn bảo mật (không phải JWT hợp lệ hoặc prefix sb_publishable).',
      );
    }

    try {
      if (isConfigured) {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
      }
    } catch (e) {
      debugPrint('Không thể khởi tạo SupabaseClient: $e');
    }
  }

  static bool get isConfigured {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    const envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    final url = envUrl.isNotEmpty ? envUrl : (dotenv.env['SUPABASE_URL'] ?? '');
    final key = envAnonKey.isNotEmpty ? envAnonKey : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('your-project-ref') &&
        !url.contains('placeholder');
  }

  /// Kiểm tra định dạng cơ bản của Publishable Key / Anon Key
  static bool isValidKeyFormat(String key) {
    if (key.isEmpty) return false;
    // Khóa Supabase chuẩn là chuỗi JWT gồm 3 phần ngăn cách bởi dấu chấm hoặc bắt đầu bằng sb_publishable_
    if (key.startsWith('sb_publishable_')) return true;
    final parts = key.split('.');
    return parts.length == 3 && parts.every((p) => p.isNotEmpty);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
