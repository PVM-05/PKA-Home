import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_ledger_entry_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/accounting_providers.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/data/repositories/accounting_repository.dart';
import 'package:pka_home/features/resident/screens/resident_invoice_detail_screen.dart';
import 'package:pka_home/features/resident/widgets/resident_ledger_history_sheet.dart';

class MockAccountingRepoForResident extends AccountingRepository {
  @override
  Future<double> fetchApartmentBalance(String apartmentId) async {
    return 1200000.0;
  }

  @override
  Future<List<ApartmentLedgerEntryModel>> fetchLedgerEntries({
    required String apartmentId,
    String? period,
  }) async {
    return [
      ApartmentLedgerEntryModel(
        id: 'ale-1',
        buildingId: 'bld-1',
        apartmentId: apartmentId,
        entryCode: 'LE-202610-00001',
        entryType: 'DEBIT',
        amount: 1200000.0,
        balanceAfter: 1200000.0,
        period: '2026-10',
        referenceType: 'INVOICE',
        description: 'Hóa đơn dịch vụ tháng 10/2026',
        createdAt: DateTime(2026, 10, 29, 10, 0),
      ),
    ];
  }
}

void main() {
  final testInvoice = InvoiceModel(
    id: 'inv-test-01',
    apartmentId: 'apt-01',
    period: '2026-10',
    dueDate: DateTime(2026, 11, 5),
    totalAmount: 1200000.0,
    status: 'pending',
    createdAt: DateTime(2026, 10, 25),
    apartment: ApartmentModel(
      id: 'apt-01',
      code: 'A0110',
      buildingCode: 'A',
      floorNumber: 1,
      buildingId: 'bld-01',
      area: 65.0,
    ),
  );

  testWidgets('ResidentInvoiceDetailScreen renders ledger history button and opens sheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountingRepositoryProvider.overrideWithValue(MockAccountingRepoForResident()),
          residentInvoiceDetailProvider('inv-test-01').overrideWith(
            (ref) async => [
              {
                'id': 'item-1',
                'invoice_id': 'inv-test-01',
                'fee_type': 'electricity',
                'unit_price': 3500,
                'quantity': 100,
                'subtotal': 350000,
              },
            ],
          ),
        ],
        child: MaterialApp(
          home: ResidentInvoiceDetailScreen(invoice: testInvoice),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify invoice information
    expect(find.text('Chi tiết hóa đơn 2026-10'), findsOneWidget);
    expect(find.text('A0110'), findsOneWidget);

    // Verify button to view ledger history
    final historyBtn = find.text('Lịch sử đối soát công nợ');
    expect(historyBtn, findsOneWidget);

    // Tap to open sheet
    await tester.tap(historyBtn);
    await tester.pumpAndSettle();

    // Verify bottom sheet appears with entries
    expect(find.byType(ResidentLedgerHistorySheet), findsOneWidget);
    expect(find.text('LE-202610-00001'), findsOneWidget);
    expect(find.text('Hóa đơn dịch vụ tháng 10/2026'), findsOneWidget);
  });
}
