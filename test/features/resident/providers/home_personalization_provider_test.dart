import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/data/models/issue_model.dart';
import 'package:vivona/data/providers/resident_invoice_provider.dart';
import 'package:vivona/data/providers/resident_issue_provider.dart';
import 'package:vivona/features/resident/providers/home_personalization_provider.dart';

void main() {
  final nowFixed = DateTime(2026, 11, 22, 10, 0);

  final testUrgentInvoice = InvoiceModel(
    id: 'inv-urgent-1',
    apartmentId: 'apt-1',
    period: '11/2026',
    dueDate: DateTime(2026, 11, 24), // 2 days away
    totalAmount: 1200000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 11, 1),
  );

  final testFarDueDateInvoice = InvoiceModel(
    id: 'inv-far-1',
    apartmentId: 'apt-1',
    period: '11/2026',
    dueDate: DateTime(2026, 12, 15), // 23 days away
    totalAmount: 1500000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 11, 1),
  );

  final testPaidInvoice = InvoiceModel(
    id: 'inv-paid-1',
    apartmentId: 'apt-1',
    period: '10/2026',
    dueDate: DateTime(2026, 11, 5),
    totalAmount: 900000.0,
    status: 'paid',
    createdAt: DateTime(2026, 10, 1),
  );

  final testActiveIssue = IssueModel(
    id: 'issue-active-1',
    apartmentId: 'apt-1',
    reporterId: 'user-1',
    description: 'Rò rỉ ống nước bồn rửa bát',
    status: 'in_progress',
    priority: 'high',
    createdAt: DateTime(2026, 11, 21),
    imageUrls: [],
  );

  final testResolvedIssue = IssueModel(
    id: 'issue-resolved-1',
    apartmentId: 'apt-1',
    reporterId: 'user-1',
    description: 'Thay bóng đèn',
    status: 'resolved',
    priority: 'low',
    createdAt: DateTime(2026, 11, 15),
    imageUrls: [],
  );

  group('HomePersonalizationProvider Tests', () {
    test('ưu tiên urgentInvoice khi có hóa đơn chưa thanh toán sát hạn (<= 5 ngày)', () {
      final container = ProviderContainer(
        overrides: [
          currentTimeProvider.overrideWithValue(nowFixed),
          residentInvoiceProvider.overrideWith((ref) => [testUrgentInvoice]),
          residentIssueProvider.overrideWith((ref) => [testActiveIssue]),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(homePersonalizationProvider);

      expect(state.priority, HomePriority.urgentInvoice);
      expect(state.mostUrgentInvoice?.id, 'inv-urgent-1');
      expect(state.daysUntilDueDate, 2);
      expect(state.showMeterReadingReminder, isTrue); // ngày 22 >= 20
    });

    test('ưu tiên activeIssueTracking khi không có hóa đơn gấp nhưng có sự cố đang xử lý', () {
      final container = ProviderContainer(
        overrides: [
          currentTimeProvider.overrideWithValue(nowFixed),
          residentInvoiceProvider.overrideWith((ref) => [testPaidInvoice]),
          residentIssueProvider.overrideWith((ref) => [testActiveIssue]),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(homePersonalizationProvider);

      expect(state.priority, HomePriority.activeIssueTracking);
      expect(state.activeIssue?.id, 'issue-active-1');
      expect(state.showMeterReadingReminder, isTrue);
    });

    test('kích hoạt meterReadingWindow từ ngày 20 trở đi khi không có hóa đơn gấp hay sự cố', () {
      final container = ProviderContainer(
        overrides: [
          currentTimeProvider.overrideWithValue(DateTime(2026, 11, 25)),
          residentInvoiceProvider.overrideWith((ref) => [testPaidInvoice, testFarDueDateInvoice]),
          residentIssueProvider.overrideWith((ref) => [testResolvedIssue]),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(homePersonalizationProvider);

      expect(state.priority, HomePriority.meterReadingWindow);
      expect(state.showMeterReadingReminder, isTrue);
    });

    test('trả về allPeaceful vào giữa tháng khi không có sự cố và đã thanh toán', () {
      final container = ProviderContainer(
        overrides: [
          currentTimeProvider.overrideWithValue(DateTime(2026, 11, 10)), // ngày 10 < 20
          residentInvoiceProvider.overrideWith((ref) => [testPaidInvoice]),
          residentIssueProvider.overrideWith((ref) => [testResolvedIssue]),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(homePersonalizationProvider);

      expect(state.priority, HomePriority.allPeaceful);
      expect(state.showMeterReadingReminder, isFalse);
    });
  });
}

