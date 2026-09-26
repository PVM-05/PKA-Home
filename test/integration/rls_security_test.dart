import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// HƯỚNG DẪN CHẠY TEST NÀY:
/// 1. Đảm bảo file `.env` ở thư mục gốc chứa SUPABASE_URL và SUPABASE_ANON_KEY.
/// 2. Tạo 2 user test trên Supabase Auth và thêm data giả vào bảng `users`, `apartments`.
/// 3. Thay thế email và password bên dưới thành thông tin thật trên Supabase.
/// 4. Chạy: flutter test test/integration/rls_security_test.dart

import 'dart:io';

void main() {
  late SupabaseClient client;
  late String testResidentEmail;
  late String testResidentPassword;
  late String? testResidentApartmentId;
  bool shouldSkip = true;

  setUpAll(() async {
    // Load biến môi trường (ưu tiên biến hệ thống trong CI, sau đó tới file .env)
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {}
    
    testResidentEmail = Platform.environment['TEST_RESIDENT_EMAIL'] ?? 
        dotenv.env['TEST_RESIDENT_EMAIL'] ?? 
        'resident101@test.com';
    testResidentPassword = Platform.environment['TEST_RESIDENT_PASSWORD'] ?? 
        dotenv.env['TEST_RESIDENT_PASSWORD'] ?? 
        'password123';
    testResidentApartmentId = Platform.environment['TEST_RESIDENT_APARTMENT_ID'] ?? 
        dotenv.env['TEST_RESIDENT_APARTMENT_ID'];

    shouldSkip = testResidentApartmentId == null || 
        testResidentApartmentId!.isEmpty || 
        testResidentApartmentId == 'FILL_UUID_HERE';

    final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl != null && supabaseAnonKey != null) {
      client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    } else {
      shouldSkip = true;
    }
  });

  tearDownAll(() async {
    if (!shouldSkip) {
      await client.auth.signOut();
      client.dispose();
    }
  });

  group('Kiểm thử RLS Bảo mật (Integration)', () {

    test(
      'Cư dân chỉ đọc được hóa đơn của căn hộ mình (RLS-01 & RLS-02)',
      () async {
        // 1. Đăng nhập với tư cách cư dân
        final AuthResponse res = await client.auth.signInWithPassword(
          email: testResidentEmail,
          password: testResidentPassword,
        );
        
        expect(res.user, isNotNull, reason: 'Đăng nhập thất bại. Kiểm tra lại user test.');

        // 2. Query hóa đơn chung (không filter căn hộ)
        final List<dynamic> invoices = await client.from('invoices').select();

        // RLS Policy nên giới hạn kết quả chỉ trả về các hóa đơn thuộc về user này
        for (var invoice in invoices) {
          expect(
            invoice['apartment_id'], 
            testResidentApartmentId, 
            reason: 'Bảo mật RLS bị lọt! Cư dân đang đọc được hóa đơn của căn hộ khác.'
          );
        }
      },
      skip: shouldSkip ? 'Chưa cấu hình tài khoản test thực tế trong .env' : null,
    );

    test(
      'Cư dân không được tự sửa trạng thái hóa đơn (RLS-03)',
      () async {
        // 1. Đăng nhập với tư cách cư dân
        await client.auth.signInWithPassword(
          email: testResidentEmail,
          password: testResidentPassword,
        );

      // 2. Cố gắng update trạng thái hóa đơn bất kỳ
      try {
        await client.from('invoices').update({'status': 'paid'}).eq('apartment_id', testResidentApartmentId!);
        // Nếu RLS hoạt động đúng, nó sẽ quăng lỗi PostgrestException vì không có quyền UPDATE
        // Nếu bảng cho phép update thì policy RLS đang sai.
        // Chú ý: Đôi khi Supabase RLS update fail sẽ không throw error mà trả về empty list [], tùy thuộc vào SDK.
        
        // Kiểm tra xem dòng đó có thực sự bị đổi không
        final check = await client.from('invoices').select('status').eq('apartment_id', testResidentApartmentId!).limit(1);
        if (check.isNotEmpty) {
           expect(check.first['status'], isNot('paid'), reason: 'Lỗi RLS: Cư dân đã sửa được trạng thái hóa đơn!');
        }
      } catch (e) {
        // Exception là mong đợi vì bị chặn quyền
        expect(e, isA<PostgrestException>());
      }
    },
    skip: shouldSkip ? 'Chưa cấu hình tài khoản test thực tế trong .env' : null,
  );

    test(
      'Cư dân không thể tự đổi role thành management (RLS-05: Chống leo thang quyền)',
      () async {
        // 1. Đăng nhập với tư cách cư dân
        final AuthResponse res = await client.auth.signInWithPassword(
          email: testResidentEmail,
          password: testResidentPassword,
        );
        final residentId = res.user?.id;
        expect(residentId, isNotNull, reason: 'Đăng nhập thất bại.');

        // 2. Cố tình gửi lệnh UPDATE trực tiếp qua API để tự phong mình thành management
        try {
          await client
              .from('users')
              .update({'role': 'management'})
              .eq('id', residentId!);

          // 3. Kiểm tra xem role trong DB có thực sự bị thay đổi không
          final userCheck = await client
              .from('users')
              .select('role')
              .eq('id', residentId)
              .single();

          expect(
            userCheck['role'], 
            isNot('management'),
            reason: 'LỖ HỔNG BẢO MẬT: Cư dân đã tự nâng quyền thành management thành công!',
          );
        } catch (e) {
          // Ngoại lệ ném ra từ Trigger (trg_prevent_role_self_escalation) hoặc RLS WITH CHECK
          expect(e, isA<PostgrestException>());
        }
      },
      skip: shouldSkip ? 'Chưa cấu hình tài khoản test thực tế trong .env' : null,
    );
  });
}
