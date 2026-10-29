import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_ledger_entry_model.dart';
import 'package:pka_home/data/providers/accounting_providers.dart';
import 'package:pka_home/data/repositories/accounting_repository.dart';
import 'package:pka_home/features/management/screens/apartment_ledger_screen.dart';

class MockAccountingRepoForUI extends AccountingRepository {
  @override
  Future<double> fetchApartmentBalance(String apartmentId) async {
    return 1500000.0;
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
        amount: 1500000.0,
        balanceAfter: 1500000.0,
        period: '2026-10',
        referenceType: 'INVOICE',
        description: 'Phát hành hóa đơn tháng 10/2026',
        createdAt: DateTime(2026, 10, 29, 14, 30),
      ),
      ApartmentLedgerEntryModel(
        id: 'ale-2',
        buildingId: 'bld-1',
        apartmentId: apartmentId,
        entryCode: 'LE-202610-00002',
        entryType: 'CREDIT_NOTE',
        amount: 200000.0,
        balanceAfter: 1300000.0,
        period: '2026-10',
        referenceType: 'CREDIT_NOTE',
        description: 'Giảm trừ tiền nước do đồng hồ sai',
        createdAt: DateTime(2026, 10, 29, 16, 45),
      ),
    ];
  }
}

void main() {
  testWidgets('ApartmentLedgerScreen displays balance card and ledger entries list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountingRepositoryProvider.overrideWithValue(MockAccountingRepoForUI()),
        ],
        child: const MaterialApp(
          home: ApartmentLedgerScreen(
            apartmentId: 'apt-01',
            apartmentCode: 'A0110',
            buildingId: 'bld-01',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and apartment code
    expect(find.text('Sổ Cái Công Nợ Căn Hộ'), findsOneWidget);
    expect(find.textContaining('A0110'), findsWidgets);

    // Verify balance summary
    expect(find.text('Số dư công nợ hiện tại'), findsOneWidget);
    expect(find.textContaining('1.500.000'), findsWidgets);
    expect(find.text('Còn nợ'), findsOneWidget);

    // Verify ledger items
    expect(find.text('LE-202610-00001'), findsOneWidget);
    expect(find.text('LE-202610-00002'), findsOneWidget);
    expect(find.text('Phát hành hóa đơn tháng 10/2026'), findsOneWidget);
    expect(find.text('Giảm trừ tiền nước do đồng hồ sai'), findsOneWidget);

    // Verify action buttons exist
    expect(find.text('Lập phiếu điều chỉnh'), findsOneWidget);
    expect(find.text('Khóa sổ kỳ kế toán'), findsOneWidget);
  });
}
