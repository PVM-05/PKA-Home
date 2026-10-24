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
        '⚠️ [LỖI CẤU HÌNH SUPABASE]: Chưa tìm thấy SUPABASE_URL hoặc SUPABASE_ANON_KEY hợp lệ. '
        'Vui lòng cấu hình file .env cục bộ (từ .env.example) hoặc truyền qua --dart-define.',
      );
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Không thể khởi tạo SupabaseClient: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
