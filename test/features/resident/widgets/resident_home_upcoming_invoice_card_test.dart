import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/features/resident/widgets/home/resident_home_upcoming_invoice_card.dart';

void main() {
  final testUnpaidInvoice = InvoiceModel(
    id: 'inv-unpaid-1',
    apartmentId: 'apt-1',
    period: '11/2026',
    dueDate: DateTime(2026, 11, 10),
    totalAmount: 1500000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 11, 1),
  );

  group('ResidentHomeUpcomingInvoiceCard Tests', () {
    testWidgets('hiển thị badge Quá hạn X ngày khi daysUntilDueDate < 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResidentHomeUpcomingInvoiceCard(
              invoiceAsync: AsyncValue.data([testUnpaidInvoice]),
              mostUrgentInvoice: testUnpaidInvoice,
              daysUntilDueDate: -8, // Quá hạn 8 ngày
              onNavigateToInvoices: () {},
              onRetry: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Quá hạn 8 ngày'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('hiển thị badge Đến hạn sau X ngày khi 0 <= daysUntilDueDate <= 5', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResidentHomeUpcomingInvoiceCard(
              invoiceAsync: AsyncValue.data([testUnpaidInvoice]),
              mostUrgentInvoice: testUnpaidInvoice,
              daysUntilDueDate: 3, // Còn 3 ngày
              onNavigateToInvoices: () {},
              onRetry: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đến hạn sau 3 ngày'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('hiển thị trạng thái hoàn thành khi không còn hóa đơn chưa thanh toán', (tester) async {
      final paidInvoice = InvoiceModel(
        id: 'inv-paid-1',
        apartmentId: 'apt-1',
        period: '11/2026',
        dueDate: DateTime(2026, 11, 10),
        totalAmount: 1500000.0,
        status: 'paid',
        createdAt: DateTime(2026, 11, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResidentHomeUpcomingInvoiceCard(
              invoiceAsync: AsyncValue.data([paidInvoice]),
              onNavigateToInvoices: () {},
              onRetry: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đã hoàn tất'), findsOneWidget);
    });
  });
}
