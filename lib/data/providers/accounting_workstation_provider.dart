import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/accounting_workstation_model.dart';
import '../models/invoice_model.dart';
import 'management_provider.dart';

export '../models/accounting_workstation_model.dart';

class SelectedInvoiceIdsNotifier extends StateNotifier<Set<String>> {
  SelectedInvoiceIdsNotifier() : super(<String>{});

  void toggle(String id) {
    if (state.contains(id)) {
      state = Set<String>.from(state)..remove(id);
    } else {
      state = Set<String>.from(state)..add(id);
    }
  }

  void selectAll(Iterable<String> ids) {
    state = Set<String>.from(ids);
  }

  void clear() {
    state = <String>{};
  }
}

final selectedInvoiceIdsProvider =
    StateNotifierProvider<SelectedInvoiceIdsNotifier, Set<String>>((ref) {
  return SelectedInvoiceIdsNotifier();
});

final accountingWorkstationFilterProvider =
    StateProvider<AccountingWorkstationFilter>((ref) {
  return const AccountingWorkstationFilter();
});

final accountingWorkstationRawInvoicesProvider =
    FutureProvider<List<InvoiceModel>>((ref) async {
  final repo = ref.watch(managementRepositoryProvider);
  return repo.fetchInvoices();
});

final accountingWorkstationRowsProvider =
    Provider<AsyncValue<List<InvoiceTableRowItem>>>((ref) {
  final rawInvoicesAsync = ref.watch(accountingWorkstationRawInvoicesProvider);
  final filter = ref.watch(accountingWorkstationFilterProvider);
  final selectedIds = ref.watch(selectedInvoiceIdsProvider);

  return rawInvoicesAsync.whenData((invoices) {
    final rows = invoices.map((inv) {
      final isSelected = selectedIds.contains(inv.id);
      return InvoiceTableRowItem.fromInvoice(
        inv,
        residentName: 'Cư dân căn hộ',
        isSelected: isSelected,
      );
    }).where((item) => filter.matches(item)).toList();

    return rows;
  });
});

final accountingWorkstationSummaryProvider =
    Provider<AccountingWorkstationSummary>((ref) {
  final rowsAsync = ref.watch(accountingWorkstationRowsProvider);
  return rowsAsync.maybeWhen(
    data: (rows) => AccountingWorkstationSummary.fromRows(rows),
    orElse: () => const AccountingWorkstationSummary(
      totalInvoices: 0,
      totalAmount: 0,
      paidAmount: 0,
      unpaidAmount: 0,
      overdueAmount: 0,
      collectionRate: 0.0,
    ),
  );
});

final accountingWorkstationAvailablePeriodsProvider =
    Provider<List<String>>((ref) {
  final rawInvoicesAsync = ref.watch(accountingWorkstationRawInvoicesProvider);
  return rawInvoicesAsync.maybeWhen(
    data: (invoices) {
      final periods = invoices.map((e) => e.period).toSet().toList();
      periods.sort((a, b) => b.compareTo(a));
      return periods;
    },
    orElse: () => const <String>[],
  );
});

String exportWorkstationToCsv(List<InvoiceTableRowItem> rows) {
  final buffer = StringBuffer();
  // UTF-8 BOM de mo tren Excel khong bi loi font tieng Viet
  buffer.write('\uFEFF');
  buffer.writeln(
      'Mã Căn Hộ,Cư Dân,Kỳ Thu,Tổng Tiền (VNĐ),Trạng Thái,Mã VietQR,Hạn Thanh Toán,Ngày Nộp');

  for (final row in rows) {
    final escapedApartment = _escapeCsv(row.apartmentCode);
    final escapedResident = _escapeCsv(row.residentName);
    final escapedPeriod = _escapeCsv(row.period);
    final amount = row.totalAmount.toStringAsFixed(0);
    final escapedStatus = _escapeCsv(row.displayStatus);
    final escapedQr = _escapeCsv(row.vietQrCode);
    final escapedDueDate = _escapeCsv(row.formattedDueDate);
    final escapedPaidAt = _escapeCsv(row.formattedPaidAt);

    buffer.writeln(
        '$escapedApartment,$escapedResident,$escapedPeriod,$amount,$escapedStatus,$escapedQr,$escapedDueDate,$escapedPaidAt');
  }

  return buffer.toString();
}

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
