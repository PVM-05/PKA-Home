import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/document_lookup_result_model.dart';
import 'package:pka_home/data/providers/document_providers.dart';
import 'package:pka_home/data/repositories/document_repository.dart';
import 'package:pka_home/features/document/screens/document_lookup_screen.dart';

class MockDocumentRepositoryForUI extends DocumentRepository {
  final Map<String, DocumentLookupResultModel> cannedResponses;

  MockDocumentRepositoryForUI({required this.cannedResponses});

  @override
  Future<DocumentLookupResultModel> verifyLookupCode(String lookupCode) async {
    final clean = lookupCode.trim().toUpperCase();
    if (clean.isEmpty) {
      return DocumentLookupResultModel.invalid(
        'Mã tra cứu không được để trống',
        lookupCode: '',
      );
    }
    if (cannedResponses.containsKey(clean)) {
      return cannedResponses[clean]!;
    }
    return DocumentLookupResultModel.invalid(
      'Không tìm thấy chứng từ với mã tra cứu tương ứng',
      lookupCode: clean,
    );
  }
}

void main() {
  group('DocumentLookupScreen Widget Tests', () {
    late Map<String, DocumentLookupResultModel> cannedResponses;

    setUp(() {
      cannedResponses = {
        'INV-202610-VALID': const DocumentLookupResultModel(
          isValid: true,
          lookupCode: 'INV-202610-VALID',
          documentType: 'Biên lai thu tiền điện tử',
          invoiceId: 'inv-01',
          period: '10/2026',
          apartmentCode: 'A0110',
          buildingName: 'Tòa Landmark PKA',
          totalAmount: 2500000,
          formattedAmount: '2.500.000 ₫',
          status: 'paid',
          statusText: 'Đã thanh toán / Đã thu tiền',
          paymentMethod: 'Chuyển khoản QR VietQR',
          issuer: 'Ban Quản Lý Chung Cư PKA-Home',
          message: 'Chứng từ hợp lệ và tồn tại trên hệ thống quản lý PKA-Home',
        ),
      };
    });

    testWidgets('Hiển thị đầy đủ AppBar, TextField và nút tra cứu ban đầu', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRepositoryProvider.overrideWithValue(
              MockDocumentRepositoryForUI(cannedResponses: cannedResponses),
            ),
          ],
          child: const MaterialApp(
            home: DocumentLookupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tra Cứu Hóa Đơn & Biên Lai'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tra cứu ngay'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('Nhập mã tra cứu hợp lệ -> Hiển thị card kết quả xác thực hợp lệ', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRepositoryProvider.overrideWithValue(
              MockDocumentRepositoryForUI(cannedResponses: cannedResponses),
            ),
          ],
          child: const MaterialApp(
            home: DocumentLookupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'INV-202610-VALID');
      await tester.tap(find.text('Tra cứu ngay'));
      await tester.pumpAndSettle();

      // Kết quả hợp lệ
      expect(find.textContaining('CHỨNG TỪ HỢP LỆ'), findsOneWidget);
      expect(find.text('INV-202610-VALID'), findsWidgets);
      expect(find.text('Biên lai thu tiền điện tử'), findsWidgets);
      expect(find.textContaining('A0110'), findsWidgets);
      expect(find.textContaining('2.500.000 ₫'), findsWidgets);
      expect(find.textContaining('Đã thanh toán'), findsWidgets);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Nhập mã không hợp lệ -> Hiển thị cảnh báo màu đỏ không tìm thấy', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRepositoryProvider.overrideWithValue(
              MockDocumentRepositoryForUI(cannedResponses: cannedResponses),
            ),
          ],
          child: const MaterialApp(
            home: DocumentLookupScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'INV-INVALID-999');
      await tester.tap(find.text('Tra cứu ngay'));
      await tester.pumpAndSettle();

      expect(find.textContaining('KHÔNG HỢP LỆ'), findsOneWidget);
      expect(find.textContaining('Không tìm thấy chứng từ với mã tra cứu tương ứng'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('Tự động tra cứu khi nhận initialLookupCode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentRepositoryProvider.overrideWithValue(
              MockDocumentRepositoryForUI(cannedResponses: cannedResponses),
            ),
          ],
          child: const MaterialApp(
            home: DocumentLookupScreen(
              initialLookupCode: 'INV-202610-VALID',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Đã tự động gọi search và render thông tin
      expect(find.textContaining('CHỨNG TỪ HỢP LỆ'), findsOneWidget);
      expect(find.text('INV-202610-VALID'), findsWidgets);
      expect(find.textContaining('A0110'), findsWidgets);
    });
  });
}
