class MaintenanceFundModel {
  final String id;
  final double totalBalance;
  final double annualInterestEarned;
  final double interestRatePercent;
  final double collectedPercent;
  final String bankName;
  final String bankAccountNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MaintenanceFundModel({
    required this.id,
    required this.totalBalance,
    required this.annualInterestEarned,
    required this.interestRatePercent,
    required this.collectedPercent,
    required this.bankName,
    required this.bankAccountNumber,
    this.createdAt,
    this.updatedAt,
  });

  String get bankAccountInfo => '$bankName\nSTK Chuyên dùng: $bankAccountNumber';

  factory MaintenanceFundModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceFundModel(
      id: json['id'] as String,
      totalBalance: (json['total_balance'] as num?)?.toDouble() ?? 0.0,
      annualInterestEarned: (json['annual_interest_earned'] as num?)?.toDouble() ?? 0.0,
      interestRatePercent: (json['interest_rate_percent'] as num?)?.toDouble() ?? 0.0,
      collectedPercent: (json['collected_percent'] as num?)?.toDouble() ?? 100.0,
      bankName: json['bank_name'] as String? ?? 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam (BIDV)',
      bankAccountNumber: json['bank_account_number'] as String? ?? '1234567890',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'total_balance': totalBalance,
    'annual_interest_earned': annualInterestEarned,
    'interest_rate_percent': interestRatePercent,
    'collected_percent': collectedPercent,
    'bank_name': bankName,
    'bank_account_number': bankAccountNumber,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceFundModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
