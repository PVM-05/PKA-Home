import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';

void main() {
  group('MonthlyRevenueItem Tests', () {
    test('calculates totalAmount and collectionRate accurately', () {
      final item = MonthlyRevenueItem(
        period: '09/2026',
        shortLabel: 'T9',
        paidAmount: 80000000.0,
        unpaidAmount: 20000000.0,
      );

      expect(item.totalAmount, equals(100000000.0));
      expect(item.collectionRate, closeTo(0.8, 0.0001));
    });

    test('handles zero revenue safely without division by zero', () {
      final item = MonthlyRevenueItem(
        period: '08/2026',
        shortLabel: 'T8',
        paidAmount: 0.0,
        unpaidAmount: 0.0,
      );

      expect(item.totalAmount, equals(0.0));
      expect(item.collectionRate, equals(0.0));
    });

    test('handles 100% collection rate accurately', () {
      final item = MonthlyRevenueItem(
        period: '07/2026',
        shortLabel: 'T7',
        paidAmount: 50000000.0,
        unpaidAmount: 0.0,
      );

      expect(item.totalAmount, equals(50000000.0));
      expect(item.collectionRate, equals(1.0));
    });
  });
}
