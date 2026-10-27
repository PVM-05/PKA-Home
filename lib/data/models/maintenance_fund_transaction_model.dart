class MaintenanceFundTransactionModel {
  final String id;
  final String buildingId;
  final String fundId;
  final String voucherNumber;
  final String transactionType; // 'INCOME' | 'EXPENSE'
  final String category; // 'MAINTENANCE_FEE' | 'EQUIPMENT_REPAIR' | 'BANK_INTEREST' | 'OTHER'
  final double amount;
  final double balanceAfter;
  final String? referenceType;
  final String? referenceId;
  final String recipientOrPayer;
  final String description;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MaintenanceFundTransactionModel({
    required this.id,
    required this.buildingId,
    required this.fundId,
    required this.voucherNumber,
    required this.transactionType,
    required this.category,
    required this.amount,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    required this.recipientOrPayer,
    required this.description,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isIncome => transactionType.toUpperCase() == 'INCOME';
  bool get isExpense => transactionType.toUpperCase() == 'EXPENSE';

  String get typeDisplayName => isIncome ? 'Thu quỹ' : 'Chi quỹ';

  String get categoryDisplayName {
    switch (category.toUpperCase()) {
      case 'MAINTENANCE_FEE':
        return 'Thu phí bảo trì';
      case 'EQUIPMENT_REPAIR':
        return 'Sửa chữa thiết bị';
      case 'BANK_INTEREST':
        return 'Lãi tiền gửi ngân hàng';
      case 'OTHER':
      default:
        return 'Khác';
    }
  }

  factory MaintenanceFundTransactionModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceFundTransactionModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String? ?? '',
      fundId: json['fund_id'] as String? ?? '',
      voucherNumber: json['voucher_number'] as String? ?? '',
      transactionType: json['transaction_type'] as String? ?? 'INCOME',
      category: json['category'] as String? ?? 'OTHER',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      recipientOrPayer: json['recipient_or_payer'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'fund_id': fundId,
      'voucher_number': voucherNumber,
      'transaction_type': transactionType,
      'category': category,
      'amount': amount,
      'balance_after': balanceAfter,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'recipient_or_payer': recipientOrPayer,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceFundTransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
