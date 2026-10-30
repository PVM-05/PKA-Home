import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/batch_import_model.dart';
import 'package:pka_home/data/repositories/batch_import_repository.dart';

void main() {
  group('BatchImportRepository Tests', () {
    test('BatchImportRepository can be instantiated', () {
      final repo = BatchImportRepository();
      expect(repo, isNotNull);
    });

    test('mapApartmentsPayload maps items to JSON structure matching RPC schema', () {
      final repo = BatchImportRepository();
      final items = [
        ApartmentImportItem(code: 'A0110', area: 68.5, isEmpty: true),
        ApartmentImportItem(code: 'B0205', area: 85.0, isEmpty: false),
      ];

      final payload = repo.mapApartmentsPayload(items);
      expect(payload.length, 2);
      expect(payload[0]['code'], 'A0110');
      expect(payload[0]['area'], 68.5);
      expect(payload[0]['is_empty'], true);
      expect(payload[0]['block'], 'A');
      expect(payload[0]['floor'], 1);
    });

    test('mapResidentsPayload maps items to JSON structure matching RPC schema', () {
      final repo = BatchImportRepository();
      final items = [
        const ResidentImportItem(
          apartmentCode: 'A0110',
          fullName: 'Nguyễn Văn An',
          phone: '0901234567',
          relationRole: 'owner',
          email: 'an@example.com',
        ),
      ];

      final payload = repo.mapResidentsPayload(items);
      expect(payload.length, 1);
      expect(payload[0]['apartment_code'], 'A0110');
      expect(payload[0]['full_name'], 'Nguyễn Văn An');
      expect(payload[0]['phone'], '0901234567');
      expect(payload[0]['relation_role'], 'owner');
      expect(payload[0]['email'], 'an@example.com');
    });

    test('mapMeterReadingsPayload maps items to JSON structure matching RPC schema', () {
      final repo = BatchImportRepository();
      final items = [
        const MeterReadingImportItem(
          apartmentCode: 'A0110',
          electricReading: 150.5,
          waterReading: 24.0,
          period: '2026-10',
        ),
      ];

      final payload = repo.mapMeterReadingsPayload(items);
      expect(payload.length, 1);
      expect(payload[0]['apartment_code'], 'A0110');
      expect(payload[0]['electric_reading'], 150.5);
      expect(payload[0]['water_reading'], 24.0);
      expect(payload[0]['period'], '2026-10');
    });

    test('parseRpcResult handles standard RPC responses correctly', () {
      final repo = BatchImportRepository();
      final successMap = {
        'success': true,
        'total_imported': 5,
        'message': 'Đã nhập thành công 5 căn hộ',
      };

      final parsed = repo.parseRpcResult(successMap);
      expect(parsed['success'], isTrue);
      expect(parsed['total_imported'], 5);
      expect(parsed['message'], contains('5 căn hộ'));
    });
  });
}

