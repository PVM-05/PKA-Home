import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm tra Migration 20261011_03: Đồng bộ hợp đồng RPC', () {
    final migrationFile = File(
      'supabase/migrations_archive/20261011_03_harmonize_amenity_and_invoice_rpcs.sql',
    );

    test('File migration 20261011_03_harmonize_amenity_and_invoice_rpcs.sql phải tồn tại', () {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Cần có migration 20261011_03 để đồng bộ RPC update_invoice_with_items và book_amenity_slot',
      );
    });

    test('Migration phải định nghĩa RPC update_invoice_with_items nguyên tử', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(
        content.contains('FUNCTION public.update_invoice_with_items'),
        isTrue,
        reason: 'Bắt buộc phải tạo lại RPC update_invoice_with_items',
      );
      expect(
        content.contains('is_admin_or_accountant()'),
        isTrue,
        reason: 'Phải kiểm tra quyền is_admin_or_accountant()',
      );
      expect(
        content.contains('DELETE FROM public.invoice_items WHERE invoice_id = p_invoice_id'),
        isTrue,
        reason: 'Phải cập nhật các hạng mục chi phí trong cùng một transaction',
      );
    });

    test('Migration phải định nghĩa RPC book_amenity_slot nhận đầy đủ p_apartment_id và p_allow_waitlist', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(
        content.contains('FUNCTION public.book_amenity_slot'),
        isTrue,
        reason: 'Bắt buộc phải cập nhật RPC book_amenity_slot',
      );
      expect(
        content.contains('p_apartment_id UUID DEFAULT NULL'),
        isTrue,
        reason: 'Chữ ký hàm phải có tham số p_apartment_id tương thích client',
      );
      expect(
        content.contains('p_allow_waitlist BOOLEAN DEFAULT TRUE'),
        isTrue,
        reason: 'Chữ ký hàm phải có tham số p_allow_waitlist tương thích client',
      );
    });
  });
}

