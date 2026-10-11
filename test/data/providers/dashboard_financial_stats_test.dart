import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';

void main() {
  group('FinancialStats Calculation Tests', () {
    test('FinancialStats tính chính xác doanh thu thực tế và tổng tiền phát hành', () {
      final stats = FinancialStats(
        paidTotal: 10000000,
        unpaidTotal: 3000000,
        pendingConfirmationTotal: 2000000,
        cancelledTotal: 5000000, // Đã hủy
        paidCount: 10,
        unpaidCount: 3,
        pendingConfirmationCount: 2,
        cancelledCount: 5,
      );

      // Doanh thu thực thu phải là 10tr
      expect(stats.actualRevenue, 10000000);
      // Tổng tiền phát hành hợp lệ (bỏ qua đã hủy) = 10tr + 3tr + 2tr = 15tr
      expect(stats.totalBilled, 15000000);
      // Tỷ lệ thu tiền = 10tr / 15tr = 0.6666...
      expect(stats.collectionRate, closeTo(10 / 15, 0.001));
      // Hóa đơn đã hủy không nằm trong nợ
      expect(stats.unpaidTotal, 3000000);
    });

    test('FinancialStats xử lý an toàn khi tổng tiền bằng 0', () {
      final stats = FinancialStats(
        paidTotal: 0,
        unpaidTotal: 0,
        paidCount: 0,
        unpaidCount: 0,
      );

      expect(stats.actualRevenue, 0);
      expect(stats.totalBilled, 0);
      expect(stats.collectionRate, 0.0);
    });
  });
}
