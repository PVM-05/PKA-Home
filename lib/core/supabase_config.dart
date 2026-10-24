import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static const String kFallbackUrl = 'https://vpgimjyyechhuofjghsb.supabase.co';
  static const String kFallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwZ2ltanl5ZWNoaHVvZmpnaHNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3MjQ3ODMsImV4cCI6MjEwMzMwMDc4M30._isITp0gCfV_83eOhWJIed-u-FvdgdHoPQ7UJ2sGRlI';

  static Future<void> initialize() async {
    String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseUrl.contains('your-project-ref')) {
      supabaseUrl = kFallbackUrl;
    }
    if (supabaseAnonKey.isEmpty || supabaseAnonKey.contains('your-anon-key')) {
      supabaseAnonKey = kFallbackAnonKey;
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
