import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/resident_invoice_provider.dart';
import '../../../data/providers/resident_issue_provider.dart';

/// Provider cung cấp thời gian hiện tại - cho phép override trong unit tests
final currentTimeProvider = Provider<DateTime>((ref) => DateTime.now());

/// Mức độ ưu tiên hiển thị nội dung trên màn hình chính cư dân
enum HomePriority {
  /// Có hóa đơn chưa thanh toán sắp đến hạn (trong vòng 5 ngày) hoặc quá hạn
  urgentInvoice,

  /// Có phản ánh sự cố đang xử lý hoặc chờ tiếp nhận
  activeIssueTracking,

  /// Trong cửa sổ ghi chỉ số điện nước (từ ngày 20 đến cuối tháng)
  meterReadingWindow,

  /// Căn hộ bình thường, mọi nghĩa vụ đã hoàn tất và không có sự cố
  allPeaceful,
}

/// Trạng thái cá nhân hóa tổng hợp cho màn hình chính cư dân
class HomePersonalizationState {
  final HomePriority priority;
  final bool showMeterReadingReminder;
  final InvoiceModel? mostUrgentInvoice;
  final IssueModel? activeIssue;
  final int daysUntilDueDate;

  const HomePersonalizationState({
    required this.priority,
    this.showMeterReadingReminder = false,
    this.mostUrgentInvoice,
    this.activeIssue,
    this.daysUntilDueDate = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomePersonalizationState &&
          runtimeType == other.runtimeType &&
          priority == other.priority &&
          showMeterReadingReminder == other.showMeterReadingReminder &&
          mostUrgentInvoice?.id == other.mostUrgentInvoice?.id &&
          activeIssue?.id == other.activeIssue?.id &&
          daysUntilDueDate == other.daysUntilDueDate;

  @override
  int get hashCode => Object.hash(
        priority,
        showMeterReadingReminder,
        mostUrgentInvoice?.id,
        activeIssue?.id,
        daysUntilDueDate,
      );
}

final homePersonalizationProvider = Provider<HomePersonalizationState>((ref) {
  final now = ref.watch(currentTimeProvider);
  final dedicatedUnpaidAsync = ref.watch(residentUnpaidInvoicesProvider);
  final paginatedInvoicesAsync = ref.watch(residentInvoiceProvider);
  final issuesAsync = ref.watch(residentIssueProvider);

  // Ưu tiên danh sách hóa đơn chưa thanh toán đầy đủ không bị giới hạn trang 1;
  // nếu chưa sẵn sàng hoặc trong test chỉ override residentInvoiceProvider thì fallback về danh sách paginated
  final dedicatedList = dedicatedUnpaidAsync.valueOrNull;
  final unpaidInvoices = (dedicatedList != null && dedicatedList.isNotEmpty)
      ? dedicatedList
      : (paginatedInvoicesAsync.valueOrNull ?? [])
          .where((i) => i.status == 'unpaid' || i.status == 'pending_confirmation')
          .toList();

  final issues = issuesAsync.valueOrNull ?? [];

  // 1. Cửa sổ ghi chỉ số điện nước (từ kMeterReadingWindowStartDay đến hết tháng)
  final isMeterReadingWindow =
      now.day >= AppConstants.kMeterReadingWindowStartDay;

  // 2. Tìm hóa đơn chưa thanh toán có hạn gần nhất (hoặc quá hạn xa nhất)
  final today = DateTime(now.year, now.month, now.day);
  InvoiceModel? mostUrgentInvoice;
  int minDaysUntilDue = 999999;

  for (final inv in unpaidInvoices) {
    final due = DateTime(inv.dueDate.year, inv.dueDate.month, inv.dueDate.day);
    final days = due.difference(today).inDays;
    if (days < minDaysUntilDue) {
      minDaysUntilDue = days;
      mostUrgentInvoice = inv;
    }
  }

  // Nếu có hóa đơn chưa thanh toán và sắp đến hạn (trong vòng 5 ngày) hoặc đã quá hạn
  final hasUrgentInvoice = mostUrgentInvoice != null && minDaysUntilDue <= 5;

  // 3. Tìm sự cố đang mở (pending hoặc in_progress)
  IssueModel? activeIssue;
  for (final issue in issues) {
    if (issue.status == 'in_progress') {
      activeIssue = issue;
      break; // Ưu tiên sự cố đang sửa
    } else if (issue.status == 'pending' && activeIssue == null) {
      activeIssue = issue;
    }
  }

  // 4. Quyết định mức độ ưu tiên
  HomePriority priority;
  if (hasUrgentInvoice) {
    priority = HomePriority.urgentInvoice;
  } else if (activeIssue != null) {
    priority = HomePriority.activeIssueTracking;
  } else if (isMeterReadingWindow) {
    priority = HomePriority.meterReadingWindow;
  } else {
    priority = HomePriority.allPeaceful;
  }

  return HomePersonalizationState(
    priority: priority,
    showMeterReadingReminder: isMeterReadingWindow,
    mostUrgentInvoice: mostUrgentInvoice,
    activeIssue: activeIssue,
    daysUntilDueDate: mostUrgentInvoice != null ? minDaysUntilDue : 0,
  );
});

