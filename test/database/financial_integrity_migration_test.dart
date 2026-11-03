import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm tra Migration 20261104_01: Tính Toàn Vẹn Tài Chính & Sổ Quỹ', () {
    const migrationPath = 'supabase/migrations/20261104_01_financial_integrity_and_real_payment.sql';

    test('File migration phải tồn tại và không rỗng', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration 20261104_01 phải tồn tại');
      final content = file.readAsStringSync();
      expect(content.trim().isNotEmpty, isTrue, reason: 'Nội dung migration không được rỗng');
    });

    test('Phải thu hồi quyền gọi simulate_unified_payment từ authenticated', () {
      final content = File(migrationPath).readAsStringSync();
      expect(
        content.contains('REVOKE EXECUTE ON FUNCTION public.simulate_unified_payment') ||
            content.contains('REVOKE ALL ON FUNCTION public.simulate_unified_payment'),
        isTrue,
        reason: 'Phải thu hồi quyền gọi simulate_unified_payment từ authenticated và public',
      );
      expect(content.contains('authenticated'), isTrue);
    });

    test('Phải khởi tạo Sequence và ràng buộc chống trùng số chứng từ sổ quỹ bảo trì', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('maintenance_fund_pt_seq'), isTrue, reason: 'Phải có sequence cho phiếu thu PT');
      expect(content.contains('maintenance_fund_pc_seq'), isTrue, reason: 'Phải có sequence cho phiếu chi PC');
      expect(content.contains('uq_maintenance_fund_building_voucher'), isTrue,
          reason: 'Phải có ràng buộc UNIQUE chống trùng voucher_number theo tòa nhà');
    });

    test('Hàm record_maintenance_fund_transaction phải kiểm tra has_building_role và auth.uid()', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('has_building_role'), isTrue,
          reason: 'Bắt buộc kiểm tra quyền kế toán tòa nhà qua has_building_role');
      expect(content.contains('auth.uid()'), isTrue,
          reason: 'Bắt buộc lấy danh tính người tạo an toàn từ auth.uid()');
      expect(content.contains('nextval'), isTrue,
          reason: 'Bắt buộc sinh số chứng từ bằng nextval từ sequence thay vì COUNT(*)');
    });

    test('Phải định nghĩa RPC create_payment_intent chuẩn an toàn PENDING', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE OR REPLACE FUNCTION public.create_payment_intent'), isTrue,
          reason: 'Phải có RPC create_payment_intent');
      expect(content.contains('FOR UPDATE'), isTrue,
          reason: 'Phải khóa dòng hóa đơn/booking bằng FOR UPDATE chống gửi kép');
      expect(content.contains('PENDING'), isTrue,
          reason: 'create_payment_intent chỉ khởi tạo trạng thái PENDING');
      expect(content.contains('GRANT EXECUTE ON FUNCTION public.create_payment_intent'), isTrue,
          reason: 'Phải cấp quyền thực thi RPC create_payment_intent cho authenticated');
    });
  });
}
