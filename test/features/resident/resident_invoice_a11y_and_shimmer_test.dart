import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/widgets/app_empty_state.dart';
import 'package:pka_home/core/widgets/app_skeleton_shimmer.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/features/resident/screens/resident_invoice_screen.dart';

void main() {
  group('ResidentInvoiceScreen A11y & Shimmer Tests', () {
    testWidgets('hiển thị AppSkeletonShimmer khi trạng thái đang tải dữ liệu', (tester) async {
      final completer = Completer<List<InvoiceModel>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: ResidentInvoiceScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AppSkeletonShimmer), findsWidgets);
    });

    testWidgets('hiển thị AppEmptyState khi danh sách hóa đơn rỗng', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceProvider.overrideWith((ref) => Future.value(<InvoiceModel>[])),
          ],
          child: const MaterialApp(
            home: ResidentInvoiceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Danh sách trống'), findsOneWidget);
    });

    testWidgets('thẻ hóa đơn có nhãn Semantics đọc số tiền bằng chữ tiếng Việt tự nhiên', (tester) async {
      final sampleInvoice = InvoiceModel(
        id: 'inv-a11y-001',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: DateTime(2026, 11, 30),
        totalAmount: 1500000,
        status: 'unpaid',
        createdAt: DateTime(2026, 11, 1),
        paymentCode: 'INV2611A0110',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceProvider.overrideWith((ref) => Future.value([sampleInvoice])),
          ],
          child: const MaterialApp(
            home: ResidentInvoiceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('Một triệu năm trăm nghìn đồng chẵn'),
      );

      expect(semanticsFinder, findsOneWidget);
    });
  });
}
