// Hợp đồng RPC cho Nhóm Tài Chính, Kế Toán & Quỹ Bảo Trì

// -------------------------------------------------------------
// 1. Ghi Sổ Quỹ Bảo Trì (record_maintenance_fund_transaction)
// -------------------------------------------------------------
class RecordMaintenanceTransactionRequestDto {
  final String buildingId;
  final String transactionType; // 'THU' | 'CHI'
  final double amount;
  final String category;
  final String description;
  final String? receiptUrl;
  final String? referenceId;
  final String? createdBy;

  const RecordMaintenanceTransactionRequestDto({
    required this.buildingId,
    required this.transactionType,
    required this.amount,
    required this.category,
    required this.description,
    this.receiptUrl,
    this.referenceId,
    this.createdBy,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_building_id': buildingId,
      'p_transaction_type': transactionType,
      'p_amount': amount,
      'p_category': category,
      'p_description': description,
      'p_receipt_url': receiptUrl,
      'p_reference_id': referenceId,
      'p_created_by': createdBy,
    };
  }
}

class RecordMaintenanceTransactionResponseDto {
  final bool success;
  final String? transactionId;
  final String? voucherNumber;
  final double? newBalance;
  final String message;

  const RecordMaintenanceTransactionResponseDto({
    required this.success,
    this.transactionId,
    this.voucherNumber,
    this.newBalance,
    required this.message,
  });

  factory RecordMaintenanceTransactionResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const RecordMaintenanceTransactionResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return RecordMaintenanceTransactionResponseDto(
      success: map['success'] == true,
      transactionId: map['transaction_id'] as String?,
      voucherNumber: map['voucher_number'] as String?,
      newBalance: map['new_balance'] != null ? (map['new_balance'] as num).toDouble() : null,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 2. Webhook Gạch Nợ Ngân Hàng (process_bank_payment_webhook)
// -------------------------------------------------------------
class ProcessBankPaymentWebhookRequestDto {
  final String gatewayTransactionId;
  final double amount;
  final String content;
  final String? accountNumber;
  final Map<String, dynamic>? additionalMetadata;

  const ProcessBankPaymentWebhookRequestDto({
    required this.gatewayTransactionId,
    required this.amount,
    required this.content,
    this.accountNumber,
    this.additionalMetadata,
  });

  Map<String, dynamic> toRpcParams() {
    final payload = <String, dynamic>{
      'gateway_transaction_id': gatewayTransactionId,
      'amount': amount,
      'content': content,
      if (accountNumber != null) 'account_number': accountNumber,
      ...?additionalMetadata,
    };
    return {'p_payload': payload};
  }
}

class ProcessBankPaymentWebhookResponseDto {
  final bool success;
  final String status; // 'SUCCESS' | 'DUPLICATE' | 'OVERPAID' | 'PARTIAL_PAID' | 'FAILED'
  final String? invoiceId;
  final String? receiptNumber;
  final String message;

  const ProcessBankPaymentWebhookResponseDto({
    required this.success,
    required this.status,
    this.invoiceId,
    this.receiptNumber,
    required this.message,
  });

  factory ProcessBankPaymentWebhookResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const ProcessBankPaymentWebhookResponseDto(
        success: false,
        status: 'FAILED',
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return ProcessBankPaymentWebhookResponseDto(
      success: map['success'] == true,
      status: map['status'] as String? ?? 'FAILED',
      invoiceId: map['invoice_id'] as String?,
      receiptNumber: map['receipt_number'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 3. Onboarding Cấu Hình Tòa Nhà (onboard_building_commercial_config)
// -------------------------------------------------------------
class OnboardBuildingCommercialConfigRequestDto {
  final String buildingId;
  final String bankBin;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final double initialMaintenanceBalance;

  const OnboardBuildingCommercialConfigRequestDto({
    required this.buildingId,
    required this.bankBin,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountName,
    this.initialMaintenanceBalance = 0.0,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_building_id': buildingId,
      'p_bank_bin': bankBin,
      'p_bank_name': bankName,
      'p_bank_account_number': bankAccountNumber,
      'p_bank_account_name': bankAccountName,
      'p_initial_maintenance_balance': initialMaintenanceBalance,
    };
  }
}

class OnboardBuildingCommercialConfigResponseDto {
  final bool success;
  final String? buildingId;
  final String message;

  const OnboardBuildingCommercialConfigResponseDto({
    required this.success,
    this.buildingId,
    required this.message,
  });

  factory OnboardBuildingCommercialConfigResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const OnboardBuildingCommercialConfigResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return OnboardBuildingCommercialConfigResponseDto(
      success: map['success'] == true,
      buildingId: map['building_id'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 4. Dự Báo Rủi Ro Nợ Xấu (calculate_apartment_debt_risk)
// -------------------------------------------------------------
class CalculateApartmentDebtRiskRequestDto {
  final String buildingId;
  final String apartmentId;

  const CalculateApartmentDebtRiskRequestDto({
    required this.buildingId,
    required this.apartmentId,
  });

  Map<String, dynamic> toRpcParams() => {
    'p_building_id': buildingId,
    'p_apartment_id': apartmentId,
  };
}

class CalculateApartmentDebtRiskResponseDto {
  final bool success;
  final String? apartmentId;
  final double riskScore;
  final String riskLevel;
  final String recommendedAction;
  final String message;

  const CalculateApartmentDebtRiskResponseDto({
    required this.success,
    this.apartmentId,
    required this.riskScore,
    required this.riskLevel,
    required this.recommendedAction,
    required this.message,
  });

  factory CalculateApartmentDebtRiskResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const CalculateApartmentDebtRiskResponseDto(
        success: false,
        riskScore: 0.0,
        riskLevel: 'LOW',
        recommendedAction: 'Ghi chú theo dõi',
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return CalculateApartmentDebtRiskResponseDto(
      success: map['success'] == true,
      apartmentId: map['apartment_id'] as String?,
      riskScore: map['risk_score'] != null ? (map['risk_score'] as num).toDouble() : 0.0,
      riskLevel: map['risk_level'] as String? ?? 'LOW',
      recommendedAction: map['recommended_action'] as String? ?? 'Ghi chú theo dõi',
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 5. Thi Hành Hành Động Đôn Đốc (execute_dunning_action)
// -------------------------------------------------------------
class ExecuteDunningActionRequestDto {
  final String buildingId;
  final String apartmentId;
  final String tier; // 'tier_1' | 'tier_2' | 'tier_3'
  final String title;
  final String content;

  const ExecuteDunningActionRequestDto({
    required this.buildingId,
    required this.apartmentId,
    required this.tier,
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_building_id': buildingId,
      'p_apartment_id': apartmentId,
      'p_tier': tier,
      'p_title': title,
      'p_content': content,
    };
  }
}

class ExecuteDunningActionResponseDto {
  final bool success;
  final String? actionId;
  final String? apartmentId;
  final String tier;
  final String status;
  final String? createdAt;
  final String message;

  const ExecuteDunningActionResponseDto({
    required this.success,
    this.actionId,
    this.apartmentId,
    required this.tier,
    required this.status,
    this.createdAt,
    required this.message,
  });

  factory ExecuteDunningActionResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const ExecuteDunningActionResponseDto(
        success: false,
        tier: 'tier_1',
        status: 'FAILED',
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return ExecuteDunningActionResponseDto(
      success: map['success'] == true,
      actionId: map['action_id'] as String?,
      apartmentId: map['apartment_id'] as String?,
      tier: map['tier'] as String? ?? 'tier_1',
      status: map['status'] as String? ?? 'sent',
      createdAt: map['created_at']?.toString(),
      message: map['message'] as String? ?? '',
    );
  }
}
