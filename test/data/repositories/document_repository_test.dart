import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/repositories/document_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final dynamic _result;
  FakePostgrestFilterBuilder(this._result);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) {
    return Future.value(_result).then(onValue, onError: onError);
  }
}

void main() {
  group('DocumentRepository Unit Tests', () {
    late MockSupabaseClient mockClient;
    late DocumentRepository repository;

    setUp(() {
      mockClient = MockSupabaseClient();
      repository = DocumentRepository(client: mockClient);
    });

    test('Có thể khởi tạo DocumentRepository không cần client', () {
      final repo = DocumentRepository();
      expect(repo, isNotNull);
    });

    test('Có thể khởi tạo DocumentRepository với client được tiêm vào', () {
      final repo = DocumentRepository(client: mockClient);
      expect(repo, isNotNull);
    });

    group('verifyLookupCode', () {
      test('Trả về invalid an toàn khi mã tra cứu rỗng không gọi RPC', () async {
        final result = await repository.verifyLookupCode('');
        expect(result.isValid, isFalse);
        expect(result.message, contains('không được để trống'));
        verifyNever(() => mockClient.rpc(any(), params: any(named: 'params')));
      });

      test('Gọi RPC verify_document_lookup thành công và trả về DocumentLookupResultModel hợp lệ', () async {
        final rpcResponse = {
          'valid': true,
          'lookup_code': 'INV-202610-A1B2C',
          'document_type': 'RECEIPT',
          'document_type_display': 'Biên lai thu tiền điện tử',
          'invoice_id': 'inv-123',
          'period': '10/2026',
          'apartment_code': 'A0110',
          'building_name': 'Tòa nhà Landmark PKA',
          'building_code': 'LANDMARK-PKA',
          'total_amount': 2500000,
          'formatted_amount': '2.500.000 ₫',
          'status': 'paid',
          'status_text': 'Đã thanh toán / Đã thu tiền',
          'issued_date': '2026-10-15T08:00:00Z',
          'paid_date': '2026-10-20T10:30:00Z',
          'payment_method': 'Chuyển khoản QR VietQR',
          'issuer': 'Ban Quản Lý Chung Cư PKA-Home',
          'message': 'Chứng từ hợp lệ và tồn tại trên hệ thống quản lý PKA-Home',
        };

        when(() => mockClient.rpc(
              'verify_document_lookup',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder(rpcResponse));

        final result = await repository.verifyLookupCode('inv-202610-a1b2c');

        verify(() => mockClient.rpc(
              'verify_document_lookup',
              params: {'p_lookup_code': 'INV-202610-A1B2C'},
            )).called(1);

        expect(result.isValid, isTrue);
        expect(result.lookupCode, 'INV-202610-A1B2C');
        expect(result.documentType, 'Biên lai thu tiền điện tử');
        expect(result.apartmentCode, 'A0110');
        expect(result.totalAmount, 2500000);
        expect(result.status, 'paid');
        expect(result.statusText, 'Đã thanh toán / Đã thu tiền');
      });

      test('Trả về DocumentLookupResultModel invalid khi RPC trả về valid = false', () async {
        final rpcResponse = {
          'valid': false,
          'lookup_code': 'INV-UNKNOWN',
          'message': 'Không tìm thấy chứng từ với mã tra cứu tương ứng',
        };

        when(() => mockClient.rpc(
              'verify_document_lookup',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder(rpcResponse));

        final result = await repository.verifyLookupCode('INV-UNKNOWN');

        expect(result.isValid, isFalse);
        expect(result.lookupCode, 'INV-UNKNOWN');
        expect(result.message, 'Không tìm thấy chứng từ với mã tra cứu tương ứng');
      });

      test('Trả về DocumentLookupResultModel invalid an toàn khi RPC ném ngoại lệ mất mạng', () async {
        when(() => mockClient.rpc(
              'verify_document_lookup',
              params: any(named: 'params'),
            )).thenThrow(Exception('Network error'));

        final result = await repository.verifyLookupCode('INV-ERROR');

        expect(result.isValid, isFalse);
        expect(result.lookupCode, 'INV-ERROR');
        expect(result.message, contains('Đã xảy ra lỗi'));
      });
    });

    group('PDF Generation Delegation', () {
      late InvoiceModel sampleInvoice;
      late List<Map<String, dynamic>> sampleItems;
      late pw.Font font;

      setUp(() {
        font = pw.Font.helvetica();
        sampleInvoice = InvoiceModel(
          id: 'inv-test-01',
          apartmentId: 'apt-01',
          period: '10/2026',
          totalAmount: 1500000,
          status: 'paid',
          createdAt: DateTime(2026, 10, 1),
          dueDate: DateTime(2026, 10, 25),
          paidAt: DateTime(2026, 10, 20),
          paymentMethod: 'Chuyển khoản QR',
          einvoiceLookupCode: 'INV-202610-TEST1',
        );

        sampleItems = [
          {
            'fee_type': 'management',
            'fee_name': 'Phí quản lý',
            'quantity': 75.0,
            'unit_price': 12000,
            'amount': 900000,
          },
        ];
      });

      test('generateInvoicePdf ủy quyền cho DocumentPdfBuilder tạo Uint8List', () async {
        final bytes = await repository.generateInvoicePdf(
          invoice: sampleInvoice,
          items: sampleItems,
          baseFont: font,
          boldFont: font,
        );
        expect(bytes, isA<Uint8List>());
        expect(bytes.isNotEmpty, isTrue);
      });

      test('generateReceiptPdfA4 ủy quyền cho DocumentPdfBuilder tạo Uint8List', () async {
        final bytes = await repository.generateReceiptPdfA4(
          invoice: sampleInvoice,
          items: sampleItems,
          baseFont: font,
          boldFont: font,
        );
        expect(bytes, isA<Uint8List>());
        expect(bytes.isNotEmpty, isTrue);
      });

      test('generateReceiptPdf80mm ủy quyền cho DocumentPdfBuilder tạo Uint8List', () async {
        final bytes = await repository.generateReceiptPdf80mm(
          invoice: sampleInvoice,
          items: sampleItems,
          baseFont: font,
          boldFont: font,
        );
        expect(bytes, isA<Uint8List>());
        expect(bytes.isNotEmpty, isTrue);
      });
    });
  });
}
