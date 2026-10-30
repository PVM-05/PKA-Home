import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/batch_import_model.dart';

void main() {
  group('Batch Import Models Tests', () {
    test('BatchImportType provides correct Vietnamese labels and titles', () {
      expect(BatchImportType.apartments.label, 'Căn hộ');
      expect(BatchImportType.residents.label, 'Cư dân');
      expect(BatchImportType.meterReadings.label, 'Điện nước');
      expect(BatchImportType.apartments.fileNamePrefix, 'Mau_Nhap_Can_Ho');
    });

    test('BatchRowErrorModel stores error detail correctly', () {
      const error = BatchRowErrorModel(
        rowNumber: 4,
        columnName: 'Số Điện Thoại',
        invalidValue: '09123',
        errorMessage: 'Số điện thoại phải gồm 10 chữ số',
      );

      expect(error.rowNumber, 4);
      expect(error.columnName, 'Số Điện Thoại');
      expect(error.invalidValue, '09123');
      expect(error.errorMessage, 'Số điện thoại phải gồm 10 chữ số');
      expect(error.displayText, 'Dòng 4 [Số Điện Thoại]: Số điện thoại phải gồm 10 chữ số (Giá trị: "09123")');
    });

    test('ApartmentImportItem serialization and normalization', () {
      final item = ApartmentImportItem(
        code: 'A0110',
        area: 68.5,
        isEmpty: true,
      );

      expect(item.code, 'A0110');
      expect(item.area, 68.5);
      expect(item.block, 'A');
      expect(item.floor, 1);
      expect(item.toJson(), {
        'code': 'A0110',
        'area': 68.5,
        'is_empty': true,
        'block': 'A',
        'floor': 1,
      });
    });

    test('ResidentImportItem serialization and relationRole normalization', () {
      final item = ResidentImportItem(
        apartmentCode: 'A0110',
        fullName: 'Nguyễn Văn A',
        phone: '0901234567',
        relationRole: 'owner',
      );

      expect(item.apartmentCode, 'A0110');
      expect(item.fullName, 'Nguyễn Văn A');
      expect(item.phone, '0901234567');
      expect(item.relationRoleText, 'Chủ hộ');
      expect(item.toJson(), {
        'apartment_code': 'A0110',
        'full_name': 'Nguyễn Văn A',
        'phone': '0901234567',
        'relation_role': 'owner',
      });
    });

    test('MeterReadingImportItem serialization', () {
      final item = MeterReadingImportItem(
        apartmentCode: 'A0110',
        electricReading: 150.5,
        waterReading: 24.0,
      );

      expect(item.apartmentCode, 'A0110');
      expect(item.electricReading, 150.5);
      expect(item.waterReading, 24.0);
      expect(item.toJson(), {
        'apartment_code': 'A0110',
        'electric_reading': 150.5,
        'water_reading': 24.0,
      });
    });

    test('BatchImportResultModel calculates counts and statuses correctly', () {
      final result = BatchImportResultModel<ApartmentImportItem>(
        totalRows: 3,
        validItems: [
          ApartmentImportItem(code: 'A0110', area: 70.0),
          ApartmentImportItem(code: 'B0205', area: 85.0),
        ],
        rowErrors: const [
          BatchRowErrorModel(
            rowNumber: 4,
            columnName: 'Mã Căn Hộ',
            invalidValue: 'XYZ',
            errorMessage: 'Sai định dạng chuẩn',
          )
        ],
      );

      expect(result.totalRows, 3);
      expect(result.validCount, 2);
      expect(result.errorCount, 1);
      expect(result.hasValidItems, isTrue);
      expect(result.hasErrors, isTrue);
      expect(result.isAllValid, isFalse);
    });
  });
}

