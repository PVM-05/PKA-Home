import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pka_home/core/widgets/unified_payment_sheet.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/providers/building_provider.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  testWidgets('UnifiedPaymentSheet displays real VietQR Napas 247 without DEMO watermark', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testBuilding = BuildingModel(
      id: 'b-001',
      organizationId: 'org-001',
      name: 'PKA Landmark 1',
      code: 'PKAL',
      bankBin: '970418',
      bankName: 'BIDV - Ngân hàng TMCP Đầu tư và Phát triển Việt Nam',
      bankAccountNumber: '9876543210',
      bankAccountName: 'BQL PKA LANDMARK 1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBuildingProvider.overrideWith((ref) => Future.value(testBuilding)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: UnifiedPaymentSheet(
              type: PaymentType.invoice,
              referenceId: 'inv-123',
              title: 'Hóa đơn tháng 10/2026',
              referenceCode: 'INV-A0110-202610',
              amount: 1500000,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify method header
    expect(find.text('Chuyển khoản VietQR (Napas 247)'), findsOneWidget);

    // Verify bank info from BuildingModel
    expect(find.textContaining('BIDV'), findsWidgets);
    expect(find.textContaining('9876543210'), findsWidgets);
    expect(find.textContaining('BQL PKA LANDMARK 1'), findsWidgets);

    // Verify QrImageView contains valid EMVCo string
    final qrFinder = find.byType(QrImageView);
    expect(qrFinder, findsOneWidget);
    final qrWidget = tester.widget<QrImageView>(qrFinder);
    final qrKey = qrWidget.key as ValueKey<String>;
    expect(qrKey.value.startsWith('vietqr_000201'), isTrue, reason: 'Must be EMVCo format');
    expect(qrKey.value, contains('A000000727'), reason: 'Must have Napas AID');
    expect(qrKey.value, contains('9876543210'), reason: 'Must contain building bank account');

    // Verify NO "DEMO ONLY" banner exists
    expect(find.text('DEMO ONLY'), findsNothing);
  });
}
