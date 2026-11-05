import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';

void main() {
  group('BuildingModel Bank Account Tests (Fail-Closed)', () {
    test('BuildingModel mặc định không có tài khoản ngân hàng và hasValidBankAccount == false', () {
      final building = BuildingModel(
        id: 'b-01',
        organizationId: 'org-01',
        name: 'Tòa Landmark A',
        code: 'A',
      );

      expect(building.bankBin, isEmpty);
      expect(building.bankAccountNumber, isEmpty);
      expect(building.bankAccountName, isEmpty);
      expect(building.hasValidBankAccount, isFalse);
    });

    test('BuildingModel.fromJson không tự ý điền tài khoản BIDV/1234567890 khi json thiếu', () {
      final building = BuildingModel.fromJson({
        'id': 'b-02',
        'organization_id': 'org-01',
        'name': 'Tòa Landmark B',
        'code': 'B',
      });

      expect(building.bankBin, isEmpty);
      expect(building.bankAccountNumber, isEmpty);
      expect(building.bankAccountName, isEmpty);
      expect(building.hasValidBankAccount, isFalse);
    });

    test('BuildingModel.fromJson có tài khoản đầy đủ trả về hasValidBankAccount == true', () {
      final building = BuildingModel.fromJson({
        'id': 'b-03',
        'organization_id': 'org-01',
        'name': 'Tòa Landmark C',
        'code': 'C',
        'bank_bin': '970415',
        'bank_name': 'VietinBank',
        'bank_account_number': '108877665544',
        'bank_account_name': 'BQL TOA NHA LANDMARK C',
      });

      expect(building.bankBin, equals('970415'));
      expect(building.bankAccountNumber, equals('108877665544'));
      expect(building.hasValidBankAccount, isTrue);
    });
  });

  group('InvoiceModel Payment Code Tests (No Client Fabrication)', () {
    test('effectivePaymentCode chỉ trả về payment_code do server cấp, không tự bịa mã', () {
      final invoiceWithCode = InvoiceModel(
        id: 'inv-01',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: DateTime(2026, 11, 25),
        totalAmount: 1500000,
        status: 'unpaid',
        paymentCode: 'INV2026110001',
        createdAt: DateTime(2026, 11, 1),
      );
      expect(invoiceWithCode.effectivePaymentCode, equals('INV2026110001'));

      final invoiceWithoutCode = InvoiceModel(
        id: 'inv-02',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: DateTime(2026, 11, 25),
        totalAmount: 1500000,
        status: 'unpaid',
        paymentCode: null,
        createdAt: DateTime(2026, 11, 1),
      );
      expect(invoiceWithoutCode.effectivePaymentCode, isEmpty);
    });
  });

  group('Resident Building Resolution Provider Tests', () {
    test('residentBuildingIdProvider trích xuất đúng building_id từ căn hộ đang chọn', () {
      final container = ProviderContainer(
        overrides: [
          currentSelectedApartmentProvider.overrideWithValue({
            'apartment_id': 'apt-99',
            'relation_role': 'owner',
            'apartments': {
              'id': 'apt-99',
              'code': 'A0110',
              'building_id': 'b-land-01',
            },
          }),
        ],
      );

      final buildingId = container.read(residentBuildingIdProvider);
      expect(buildingId, equals('b-land-01'));
    });

    test('residentBuildingIdProvider trả về null khi chưa chọn căn hộ', () {
      final container = ProviderContainer(
        overrides: [
          currentSelectedApartmentProvider.overrideWithValue(null),
        ],
      );

      final buildingId = container.read(residentBuildingIdProvider);
      expect(buildingId, isNull);
    });
  });
}
