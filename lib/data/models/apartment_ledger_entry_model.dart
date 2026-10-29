import 'package:intl/intl.dart';

class ApartmentLedgerEntryModel {
  final String id;
  final String buildingId;
  final String apartmentId;
  final String entryCode;
  final String entryType;
  final double amount;
  final double balanceAfter;
  final String period;
  final String referenceType;
  final String? referenceId;
  final String description;
  final String? createdBy;
  final DateTime createdAt;

  const ApartmentLedgerEntryModel({
    required this.id,
    required this.buildingId,
    required this.apartmentId,
    required this.entryCode,
    required this.entryType,
    required this.amount,
    required this.balanceAfter,
    required this.period,
    required this.referenceType,
    this.referenceId,
    required this.description,
    this.createdBy,
    required this.createdAt,
  });

  factory ApartmentLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return ApartmentLedgerEntryModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      entryCode: json['entry_code'] as String? ?? '',
      entryType: json['entry_type'] as String? ?? 'DEBIT',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      period: json['period'] as String? ?? '',
      referenceType: json['reference_type'] as String? ?? 'MANUAL',
      referenceId: json['reference_id'] as String?,
      description: json['description'] as String? ?? '',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'apartment_id': apartmentId,
      'entry_code': entryCode,
      'entry_type': entryType,
      'amount': amount,
      'balance_after': balanceAfter,
      'period': period,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isDebit => entryType == 'DEBIT' || entryType == 'DEBIT_NOTE' || entryType == 'REFUND';

  String get entryTypeVietnamese {
    switch (entryType) {
      case 'DEBIT':
        return 'Phát sinh nợ (Hóa đơn)';
      case 'CREDIT':
        return 'Thanh toán thu tiền';
      case 'CREDIT_NOTE':
        return 'Phiếu giảm nợ';
      case 'DEBIT_NOTE':
        return 'Phiếu tăng nợ (Truy thu)';
      case 'REFUND':
        return 'Hoàn tiền';
      default:
        return 'Điều chỉnh';
    }
  }

  String get formattedPeriod {
    if (period.contains('-')) {
      final parts = period.split('-');
      if (parts.length == 2) {
        return 'Tháng ${parts[1]}/${parts[0]}';
      }
    }
    return period;
  }

  String get formattedAmount {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);
  }

  String get formattedBalanceAfter {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(balanceAfter);
  }

  String get formattedCreatedAt {
    return DateFormat('dd/MM/yyyy').format(createdAt);
  }

  String get formattedCreatedAtWithTime {
    return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  }
}
