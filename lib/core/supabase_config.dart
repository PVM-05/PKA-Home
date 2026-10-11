import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty || supabaseUrl.contains('your-project-ref')) {
      debugPrint(
        '⚠️ [CẤU HÌNH SUPABASE]: Chưa thiết lập SUPABASE_URL hoặc SUPABASE_ANON_KEY hợp lệ. '
        'Vui lòng sao chép .env.example sang .env và cung cấp URL cùng Anon Key của dự án.',
      );
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl.isNotEmpty ? supabaseUrl : 'https://placeholder.supabase.co',
        publishableKey: supabaseAnonKey.isNotEmpty ? supabaseAnonKey : 'placeholder-anon-key',
      );
    } catch (e) {
      debugPrint('Không thể khởi tạo SupabaseClient: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
