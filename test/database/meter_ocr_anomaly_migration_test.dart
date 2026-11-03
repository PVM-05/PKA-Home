import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261103_03_meter_ocr_and_anomaly.sql', () {
    late String migrationSql;

    setUpAll(() {
      final file = File('supabase/migrations/20261103_03_meter_ocr_and_anomaly.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration file 20261103_03 phải tồn tại.');
      migrationSql = file.readAsStringSync();
    });

    test('Chứa lệnh thêm các cột OCR và Anomaly vào meter_reading_submissions', () {
      expect(migrationSql, contains('ALTER TABLE public.meter_reading_submissions'));
      expect(migrationSql, contains('ocr_confidence'));
      expect(migrationSql, contains('is_anomaly'));
      expect(migrationSql, contains('anomaly_severity'));
      expect(migrationSql, contains('anomaly_reason'));
      expect(migrationSql, contains('previous_electric_reading'));
      expect(migrationSql, contains('previous_water_reading'));
      expect(migrationSql, contains('avg_electric_usage'));
      expect(migrationSql, contains('avg_water_usage'));
    });

    test('Chứa chỉ mục tìm kiếm và lọc bản ghi bất thường', () {
      expect(migrationSql, contains('idx_meter_submissions_anomaly'));
    });

    test('Chứa RPC detect_meter_reading_anomaly với đầy đủ tham số', () {
      expect(migrationSql, contains('CREATE OR REPLACE FUNCTION public.detect_meter_reading_anomaly'));
      expect(migrationSql, contains('p_apartment_id UUID'));
      expect(migrationSql, contains('p_electric_reading NUMERIC'));
      expect(migrationSql, contains('p_water_reading NUMERIC'));
      expect(migrationSql, contains('SECURITY DEFINER'));
    });

    test('Chứa trigger tự động đánh dấu bất thường khi thêm hoặc cập nhật chỉ số', () {
      expect(migrationSql, contains('trg_check_meter_reading_anomaly'));
      expect(migrationSql, contains('fn_check_meter_reading_anomaly'));
    });
  });
}

