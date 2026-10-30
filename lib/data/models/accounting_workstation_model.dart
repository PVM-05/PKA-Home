import 'package:intl/intl.dart';
import 'invoice_model.dart';

class AccountingWorkstationFilter {
  final String searchQuery;
  final String? period;
  final String? status;
  final String? buildingId;

  const AccountingWorkstationFilter({
    this.searchQuery = '',
    this.period,
    this.status,
    this.buildingId,
  });

  AccountingWorkstationFilter copyWith({
    String? searchQuery,
    String? period,
    String? status,
    String? buildingId,
  }) {
    return AccountingWorkstationFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      period: period ?? this.period,
      status: status ?? this.status,
      buildingId: buildingId ?? this.buildingId,
    );
  }

  bool matches(InvoiceTableRowItem item) {
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      final matchApartment = item.apartmentCode.toLowerCase().contains(query);
      final matchResident = item.residentName.toLowerCase().contains(query);
      final matchQr = item.vietQrCode.toLowerCase().contains(query);
      if (!matchApartment && !matchResident && !matchQr) {
        return false;
      }
    }

    if (period != null && period!.isNotEmpty) {
      if (item.period != period) {
        return false;
      }
    }

    if (status != null && status!.isNotEmpty) {
      if (item.status != status) {
        return false;
      }
    }

    return true;
  }
}

class InvoiceTableRowItem {
  final String id;
  final String apartmentCode;
  final String residentName;
  final String period;
  final double totalAmount;
  final String status;
  final String displayStatus;
  final String vietQrCode;
  final DateTime? paidAt;
  final DateTime? dueDate;
  final DateTime createdAt;
  final bool isSelected;

  const InvoiceTableRowItem({
    required this.id,
    required this.apartmentCode,
    required this.residentName,
    required this.period,
    required this.totalAmount,
    required this.status,
    required this.displayStatus,
    required this.vietQrCode,
    this.paidAt,
    this.dueDate,
    required this.createdAt,
    this.isSelected = false,
  });

  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(totalAmount);
  }

  String get formattedDueDate {
    if (dueDate == null) return '-';
    return DateFormat('dd/MM/yyyy').format(dueDate!);
  }

  String get formattedPaidAt {
    if (paidAt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(paidAt!);
  }

  static String mapStatusToDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Đã thanh toán';
      case 'unpaid':
        return 'Chờ thanh toán';
      case 'overdue':
        return 'Quá hạn';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  factory InvoiceTableRowItem.fromInvoice(
    InvoiceModel invoice, {
    String? residentName,
    bool isSelected = false,
  }) {
    final rawCode = invoice.apartment?.code ?? '-';
    final code = rawCode.toUpperCase();

    return InvoiceTableRowItem(
      id: invoice.id,
      apartmentCode: code,
      residentName: residentName ?? 'Chưa xác định',
      period: invoice.period,
      totalAmount: invoice.totalAmount,
      status: invoice.status,
      displayStatus: mapStatusToDisplay(invoice.status),
      vietQrCode: invoice.effectivePaymentCode,
      paidAt: invoice.paidAt,
      dueDate: invoice.dueDate,
      createdAt: invoice.createdAt,
      isSelected: isSelected,
    );
  }

  InvoiceTableRowItem copyWith({
    bool? isSelected,
  }) {
    return InvoiceTableRowItem(
      id: id,
      apartmentCode: apartmentCode,
      residentName: residentName,
      period: period,
      totalAmount: totalAmount,
      status: status,
      displayStatus: displayStatus,
      vietQrCode: vietQrCode,
      paidAt: paidAt,
      dueDate: dueDate,
      createdAt: createdAt,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class AccountingWorkstationSummary {
  final int totalInvoices;
  final double totalAmount;
  final double paidAmount;
  final double unpaidAmount;
  final double overdueAmount;
  final double collectionRate;

  const AccountingWorkstationSummary({
    required this.totalInvoices,
    required this.totalAmount,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.overdueAmount,
    required this.collectionRate,
  });

  String get formattedTotalAmount {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(totalAmount);
  }

  String get formattedPaidAmount {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(paidAmount);
  }

  String get formattedUnpaidAmount {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(unpaidAmount);
  }

  String get formattedOverdueAmount {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(overdueAmount);
  }

  factory AccountingWorkstationSummary.fromRows(List<InvoiceTableRowItem> rows) {
    if (rows.isEmpty) {
      return const AccountingWorkstationSummary(
        totalInvoices: 0,
        totalAmount: 0,
        paidAmount: 0,
        unpaidAmount: 0,
        overdueAmount: 0,
        collectionRate: 0.0,
      );
    }

    final totalCount = rows.length;
    double total = 0;
    double paid = 0;
    double unpaid = 0;
    double overdue = 0;

    for (final row in rows) {
      total += row.totalAmount;
      if (row.status == 'paid') {
        paid += row.totalAmount;
      } else if (row.status == 'overdue') {
        overdue += row.totalAmount;
      } else {
        unpaid += row.totalAmount;
      }
    }

    final rate = total > 0 ? (paid / total) * 100 : 0.0;

    return AccountingWorkstationSummary(
      totalInvoices: totalCount,
      totalAmount: total,
      paidAmount: paid,
      unpaidAmount: unpaid,
      overdueAmount: overdue,
      collectionRate: double.parse(rate.toStringAsFixed(1)),
    );
  }
}
