import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/maintenance_fund_repository.dart';

void main() {
  group('MaintenanceFundRepository Unit Tests', () {
    test('MaintenanceFundRepository initializes gracefully without crash', () {
      final repo = MaintenanceFundRepository();
      expect(repo, isNotNull);
    });

    test('fetchFundByBuilding returns null gracefully without crash when offline', () async {
      final repo = MaintenanceFundRepository();
      final fund = await repo.fetchFundByBuilding('b-1');
      expect(fund, isNull);
    });

    test('fetchTransactions returns empty list gracefully without crash when offline', () async {
      final repo = MaintenanceFundRepository();
      final list = await repo.fetchTransactions(buildingId: 'b-1');
      expect(list, isEmpty);
    });

    test('recordTransaction returns null gracefully without crash when offline', () async {
      final repo = MaintenanceFundRepository();
      final result = await repo.recordTransaction(
        buildingId: 'b-1',
        transactionType: 'INCOME',
        category: 'MAINTENANCE_FEE',
        amount: 1000000,
        description: 'Test thu phí',
        recipientOrPayer: 'Cư dân',
      );
      expect(result, isNull);
    });
  });
}
