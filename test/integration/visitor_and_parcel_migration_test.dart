import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 1: Kiem tra Migration SQL Dang Ky Khach QR & Buu Kien Le Tan D6', () {
    const migrationPath = 'supabase/migrations/20261103_01_visitor_and_parcel_hub.sql';

    test('1. Tap tin migration 20261103_01 phai ton tai', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Tập tin migration 20261103_01_visitor_and_parcel_hub.sql chưa được tạo');
    });

    test('2. Migration phai dinh nghia bang visitor_access_passes va RLS', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      expect(content, contains('CREATE TABLE IF NOT EXISTS public.visitor_access_passes'));
      expect(content, contains('pass_code TEXT NOT NULL UNIQUE'));
      expect(content, contains('apartment_id UUID NOT NULL REFERENCES public.apartments'));
      expect(content, contains('visitor_name TEXT NOT NULL'));
      expect(content, contains('qr_payload TEXT NOT NULL'));
      expect(content, contains('ALTER TABLE public.visitor_access_passes ENABLE ROW LEVEL SECURITY;'));
    });

    test('3. Migration phai dinh nghia bang parcels va RLS', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      expect(content, contains('CREATE TABLE IF NOT EXISTS public.parcels'));
      expect(content, contains('parcel_code TEXT NOT NULL UNIQUE'));
      expect(content, contains('apartment_id UUID NOT NULL REFERENCES public.apartments'));
      expect(content, contains('carrier TEXT NOT NULL'));
      expect(content, contains('tracking_number TEXT'));
      expect(content, contains('shelf_location TEXT NOT NULL'));
      expect(content, contains('pickup_pin TEXT NOT NULL'));
      expect(content, contains('ALTER TABLE public.parcels ENABLE ROW LEVEL SECURITY;'));
    });

    test('4. Migration phai dinh nghia cac triggers sinh ma tu dong', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      expect(content, contains('trg_generate_visitor_pass_code'));
      expect(content, contains('trg_generate_parcel_code_and_pin'));
    });

    test('5. Migration phai dinh nghia day du 4 RPCs ho tro nghiep vu le tan va an ninh', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      expect(content, contains('check_in_visitor_pass('));
      expect(content, contains('check_out_visitor_pass('));
      expect(content, contains('collect_parcel('));
      expect(content, contains('get_front_desk_stats('));
    });
  });
}

