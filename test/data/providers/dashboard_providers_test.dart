import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';

void main() {
  group('Dashboard Providers Tests', () {
    test('monthlyRevenueTrendProvider không đếm trùng hóa đơn kỳ T9 tạo vào tháng 10', () async {
      final mockInvoices = [
        {
          'id': 'inv-1',
          'apartment_id': 'apt-1',
          'period': '09/2026',
          'total_amount': 500000.0,
          'status': 'paid',
          'created_at': '2026-10-02T10:00:00Z', // Tạo vào tháng 10 nhưng thuộc kỳ tháng 9
        },
      ];

      final container = ProviderContainer(
        overrides: [
          rawInvoicesStream.overrideWith((ref) => Stream.value(mockInvoices)),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(monthlyRevenueTrendProvider.future);
      
      // Tìm item tháng 9 và tháng 10 năm 2026
      final t9Item = items.firstWhere(
        (it) => it.period == '09/2026',
        orElse: () => MonthlyRevenueItem(period: '09/2026', shortLabel: 'T9', paidAmount: 0, unpaidAmount: 0),
      );
      final t10Item = items.firstWhere(
        (it) => it.period == '10/2026',
        orElse: () => MonthlyRevenueItem(period: '10/2026', shortLabel: 'T10', paidAmount: 0, unpaidAmount: 0),
      );

      // Tháng 9 phải có 500.000 đ
      expect(t9Item.paidAmount, equals(500000.0));
      // Tháng 10 không được đếm trùng (phải là 0 đ)
      expect(t10Item.paidAmount, equals(0.0));
    });

    test('financialStatsProvider chọn đúng kỳ lớn nhất thay vì lấy phần tử đầu tiên', () async {
      // Giả sử kỳ hiện tại chưa có, danh sách có kỳ 08/2026 và 09/2026
      // Hóa đơn kỳ 08 đứng trước trong stream
      final mockInvoices = [
        {
          'id': 'inv-old',
          'apartment_id': 'apt-1',
          'period': '08/2026',
          'total_amount': 200000.0,
          'status': 'paid',
        },
        {
          'id': 'inv-latest',
          'apartment_id': 'apt-2',
          'period': '09/2026',
          'total_amount': 700000.0,
          'status': 'paid',
        },
      ];

      final container = ProviderContainer(
        overrides: [
          rawInvoicesStream.overrideWith((ref) => Stream.value(mockInvoices)),
        ],
      );
      addTearDown(container.dispose);

      final stats = await container.read(financialStatsProvider.future);
      // Kỳ lớn nhất là 09/2026 -> doanh thu phải là 700.000 đ, không phải 200.000 đ
      expect(stats.paidTotal, equals(700000.0));
    });
  });
}
