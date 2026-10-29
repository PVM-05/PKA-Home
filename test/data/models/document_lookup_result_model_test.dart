import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/document_lookup_result_model.dart';

void main() {
  group('DocumentLookupResultModel Tests', () {
    test('fromJson parses full valid electronic receipt payload correctly', () {
      final json = {
        'valid': true,
        'lookup_code': 'INV-202610-A7F9B',
        'document_type': 'RECEIPT',
        'document_type_display': 'Biên lai thu tiền điện tử',
        'invoice_id': 'inv-uuid-001',
        'period': '2026-10',
        'apartment_code': 'A0110',
        'building_name': 'Tòa Landmark PKA',
        'building_code': 'LANDMARK-A',
        'total_amount': 1250000,
        'formatted_amount': '1.250.000 đ',
        'status': 'paid',
        'status_text': 'Đã thanh toán / Đã thu tiền',
        'issued_date': '2026-10-25T00:00:00.000Z',
        'paid_date': '2026-10-28T14:30:00.000Z',
        'payment_method': 'Chuyển khoản VietQR',
        'issuer': 'Ban Quản Lý Tòa Nhà Landmark PKA',
        'message': 'Chứng từ hợp lệ và có nguồn gốc chính thức từ hệ thống PKA-Home',
      };

      final model = DocumentLookupResultModel.fromJson(json);

      expect(model.isValid, isTrue);
      expect(model.lookupCode, equals('INV-202610-A7F9B'));
      expect(model.documentType, equals('Biên lai thu tiền điện tử'));
      expect(model.invoiceId, equals('inv-uuid-001'));
      expect(model.period, equals('2026-10'));
      expect(model.apartmentCode, equals('A0110'));
      expect(model.buildingName, equals('Tòa Landmark PKA'));
      expect(model.buildingCode, equals('LANDMARK-A'));
      expect(model.totalAmount, equals(1250000));
      expect(model.formattedAmount, equals('1.250.000 đ'));
      expect(model.status, equals('paid'));
      expect(model.statusText, equals('Đã thanh toán / Đã thu tiền'));
      expect(model.issuedDate, equals(DateTime.parse('2026-10-25T00:00:00.000Z')));
      expect(model.paidDate, equals(DateTime.parse('2026-10-28T14:30:00.000Z')));
      expect(model.paymentMethod, equals('Chuyển khoản VietQR'));
      expect(model.issuer, equals('Ban Quản Lý Tòa Nhà Landmark PKA'));
      expect(model.message, equals('Chứng từ hợp lệ và có nguồn gốc chính thức từ hệ thống PKA-Home'));
    });

    test('fromJson parses RPC verify_document_lookup response keys (due_date, paid_at)', () {
      final rpcJson = {
        'valid': true,
        'lookup_code': 'INV-202610-B1C2D',
        'document_type': 'INVOICE',
        'document_type_display': 'Hóa đơn dịch vụ chung cư',
        'invoice_id': 'inv-uuid-002',
        'period': '2026-10',
        'due_date': '2026-10-30T17:00:00.000Z',
        'paid_at': null,
        'payment_method': null,
        'total_amount': 750000,
        'status': 'unpaid',
        'apartment_code': 'B0205',
        'building_name': 'Tòa Tháp B',
        'organization_name': 'Công ty Quản lý PKA',
        'issuer': 'Tòa Tháp B',
        'message': 'Chứng từ hợp lệ và có nguồn gốc chính thức từ hệ thống PKA-Home',
      };

      final model = DocumentLookupResultModel.fromJson(rpcJson);

      expect(model.isValid, isTrue);
      expect(model.lookupCode, equals('INV-202610-B1C2D'));
      expect(model.documentType, equals('Hóa đơn dịch vụ chung cư'));
      expect(model.totalAmount, equals(750000));
      expect(model.status, equals('unpaid'));
      expect(model.statusText, equals('Chưa thanh toán'));
      expect(model.issuedDate, equals(DateTime.parse('2026-10-30T17:00:00.000Z')));
      expect(model.paidDate, isNull);
      expect(model.formattedAmount, contains('750.000'));
    });

    test('fromJson parses invalid lookup payload (valid == false)', () {
      final json = {
        'valid': false,
        'lookup_code': 'INV-UNKNOWN-00000',
        'message': 'Không tìm thấy chứng từ với mã tra cứu tương ứng',
      };

      final model = DocumentLookupResultModel.fromJson(json);

      expect(model.isValid, isFalse);
      expect(model.lookupCode, equals('INV-UNKNOWN-00000'));
      expect(model.message, equals('Không tìm thấy chứng từ với mã tra cứu tương ứng'));
      expect(model.totalAmount, isNull);
      expect(model.apartmentCode, isNull);
    });

    test('toJson serializes model back to Map with consistent keys', () {
      final model = DocumentLookupResultModel(
        isValid: true,
        lookupCode: 'INV-202610-TEST1',
        documentType: 'Biên lai thu tiền điện tử',
        invoiceId: 'inv-123',
        period: '2026-10',
        apartmentCode: 'A0110',
        buildingName: 'Tòa A',
        buildingCode: 'A',
        totalAmount: 500000,
        formattedAmount: '500.000 đ',
        status: 'paid',
        statusText: 'Đã thanh toán',
        issuedDate: DateTime.parse('2026-10-01T00:00:00.000Z'),
        paidDate: DateTime.parse('2026-10-05T12:00:00.000Z'),
        paymentMethod: 'Chuyển khoản VietQR',
        issuer: 'Ban Quản Lý PKA',
        message: 'Chứng từ hợp lệ',
      );

      final json = model.toJson();

      expect(json['valid'], isTrue);
      expect(json['lookup_code'], equals('INV-202610-TEST1'));
      expect(json['document_type'], equals('Biên lai thu tiền điện tử'));
      expect(json['invoice_id'], equals('inv-123'));
      expect(json['total_amount'], equals(500000));
      expect(json['status'], equals('paid'));
      expect(json['issued_date'], equals('2026-10-01T00:00:00.000Z'));
      expect(json['paid_date'], equals('2026-10-05T12:00:00.000Z'));
    });

    test('DocumentLookupResultModel.invalid creates invalid instance cleanly', () {
      final model = DocumentLookupResultModel.invalid(
        'Mã tra cứu không tồn tại',
        lookupCode: 'INV-NOT-FOUND',
      );

      expect(model.isValid, isFalse);
      expect(model.lookupCode, equals('INV-NOT-FOUND'));
      expect(model.message, equals('Mã tra cứu không tồn tại'));
      expect(model.totalAmount, isNull);
    });
  });
}
