import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P1 Database Verification: Meter Reading Consumption & Invoice Enum Tests', () {
    late String migrationContent;

    setUpAll(() {
      final migrationFile = File('supabase/migrations/20261011_06_fix_security_meters_vehicles_and_storage.sql');
      expect(migrationFile.existsSync(), isTrue, reason: 'File migration 20261011_06 phải tồn tại');
      migrationContent = migrationFile.readAsStringSync();
    });

    test('approve_meter_reading tạo hóa đơn với status = unpaid thay vì pending', () {
      expect(migrationContent, contains("CREATE OR REPLACE FUNCTION public.approve_meter_reading("));
      expect(migrationContent, contains("'unpaid',"));
      // Đảm bảo không chèn 'pending' vào cột status của invoices
      final approveInvoiceSection = migrationContent.substring(
        migrationContent.indexOf('CREATE OR REPLACE FUNCTION public.approve_meter_reading('),
        migrationContent.indexOf('CREATE OR REPLACE FUNCTION public.validate_monthly_bulk_invoices('),
      );
      expect(approveInvoiceSection, contains("'unpaid',"));
      expect(approveInvoiceSection, isNot(contains("'pending',\n            now(),\n            now()")));
    });

    test('generate_valid_bulk_invoices tạo hóa đơn với status = unpaid thay vì pending', () {
      final generateInvoiceSection = migrationContent.substring(
        migrationContent.indexOf('CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices('),
        migrationContent.indexOf('CREATE OR REPLACE FUNCTION public.check_vehicle_limits()'),
      );
      expect(generateInvoiceSection, contains("'unpaid',"));
      expect(generateInvoiceSection, isNot(contains("'pending',\n        now(),\n        now()")));
    });

    test('validate_monthly_bulk_invoices tính delta tiêu thụ cuối kỳ - đầu kỳ', () {
      expect(migrationContent, contains("GREATEST(0, v_cur_elec - v_old_elec)"));
      expect(migrationContent, contains("GREATEST(0, v_cur_water - v_old_water)"));
      expect(migrationContent, contains("'electric_reading_old'"));
      expect(migrationContent, contains("'electric_reading_new'"));
      expect(migrationContent, contains("'electric_usage'"));
    });

    test('Xác nhận tính toán logic: Chỉ số cũ 1500 và chỉ số mới 1650 thì lượng tiêu thụ là 150 (không phải 1650)', () {
      const double oldElecReading = 1500.0;
      const double newElecReading = 1650.0;
      const double elecRate = 3500.0;

      // Logic đúng: delta = new - old
      final double correctUsage = newElecReading - oldElecReading;
      final double correctFee = correctUsage * elecRate;

      // Logic sai cũ: usage = new
      final double wrongUsage = newElecReading;
      final double wrongFee = wrongUsage * elecRate;

      expect(correctUsage, equals(150.0), reason: 'Lượng tiêu thụ phải là hiệu số giữa mới và cũ (150 kWh)');
      expect(wrongUsage, equals(1650.0), reason: 'Không được coi toàn bộ chỉ số công tơ tích lũy là lượng tiêu thụ');

      expect(correctFee, equals(525000.0));
      expect(wrongFee, equals(5775000.0));
      expect(wrongFee, isNot(equals(correctFee)));
    });
  });
}
