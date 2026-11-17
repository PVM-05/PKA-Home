import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/supabase_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  test('SupabaseConfig: isConfigured và initialize không ném ngoại lệ khi dotenv chưa initialized', () async {
    // Đảm bảo dotenv chưa initialized (hoặc kiểm tra thuộc tính isInitialized)
    expect(dotenv.isInitialized, isFalse);

    // Không được crash với NotInitializedError
    expect(() => SupabaseConfig.isConfigured, returnsNormally);
    expect(SupabaseConfig.isConfigured, isFalse);

    // initialize cũng không được ném lỗi
    await expectLater(SupabaseConfig.initialize(), completes);
  });

  test('SupabaseConfig: isConfigured trả về true khi có config hợp lệ', () {
    dotenv.loadFromString(
      envString: 'SUPABASE_URL=https://example-project.supabase.co\n'
          'SUPABASE_ANON_KEY=sb_publishable_test_token_123456789',
    );

    expect(dotenv.isInitialized, isTrue);
    expect(SupabaseConfig.isConfigured, isTrue);
  });
}
