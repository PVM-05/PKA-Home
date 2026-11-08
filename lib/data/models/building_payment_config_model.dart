/// Model cấu hình tài khoản ngân hàng & cổng SePay của từng tòa nhà B2B SaaS
class BuildingPaymentConfigModel {
  final String id;
  final String buildingId;
  final String? sepayApiKey;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final String bankBin;
  final String qrTemplate; // compact, default
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BuildingPaymentConfigModel({
    required this.id,
    required this.buildingId,
    this.sepayApiKey,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountName,
    required this.bankBin,
    this.qrTemplate = 'compact',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Sinh URL ảnh VietQR động tối ưu qua gateway SePay
  String generateSepayQrUrl({
    required double amount,
    required String memo,
  }) {
    final cleanMemo = Uri.encodeComponent(memo);
    final cleanBank = Uri.encodeComponent(bankName);
    return 'https://qr.sepay.vn/img?acc=$bankAccountNumber&bank=$cleanBank&amount=${amount.toInt()}&des=$cleanMemo&template=$qrTemplate';
  }

  factory BuildingPaymentConfigModel.fromJson(Map<String, dynamic> json) {
    return BuildingPaymentConfigModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String? ?? '',
      sepayApiKey: json['sepay_api_key'] as String?,
      bankName: json['bank_name'] as String? ?? '',
      bankAccountNumber: json['bank_account_number'] as String? ?? '',
      bankAccountName: json['bank_account_name'] as String? ?? '',
      bankBin: json['bank_bin'] as String? ?? '',
      qrTemplate: json['qr_template'] as String? ?? 'compact',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'sepay_api_key': sepayApiKey,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
      'bank_bin': bankBin,
      'qr_template': qrTemplate,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  BuildingPaymentConfigModel copyWith({
    String? id,
    String? buildingId,
    String? sepayApiKey,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? bankBin,
    String? qrTemplate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BuildingPaymentConfigModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      sepayApiKey: sepayApiKey ?? this.sepayApiKey,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankBin: bankBin ?? this.bankBin,
      qrTemplate: qrTemplate ?? this.qrTemplate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
