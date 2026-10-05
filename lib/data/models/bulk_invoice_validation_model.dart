class ValidApartmentBillingItem {
  final String apartmentId;
  final String apartmentCode;
  final double area;
  final double electricUsage;
  final double waterUsage;
  final double estimatedTotal;

  ValidApartmentBillingItem({
    required this.apartmentId,
    required this.apartmentCode,
    required this.area,
    required this.electricUsage,
    required this.waterUsage,
    required this.estimatedTotal,
  });

  factory ValidApartmentBillingItem.fromJson(Map<String, dynamic> json) {
    return ValidApartmentBillingItem(
      apartmentId: json['apartment_id'] as String? ?? '',
      apartmentCode: json['apartment_code'] as String? ?? '',
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      electricUsage: (json['electric_usage'] as num?)?.toDouble() ?? 0.0,
      waterUsage: (json['water_usage'] as num?)?.toDouble() ?? 0.0,
      estimatedTotal: (json['estimated_total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apartment_id': apartmentId,
      'apartment_code': apartmentCode,
      'area': area,
      'electric_usage': electricUsage,
      'water_usage': waterUsage,
      'estimated_total': estimatedTotal,
    };
  }
}

class BulkInvoiceIssueItem {
  final String apartmentId;
  final String apartmentCode;
  final String type; // 'missing_data', 'invalid_reading', 'already_invoiced'
  final String message;

  BulkInvoiceIssueItem({
    required this.apartmentId,
    required this.apartmentCode,
    required this.type,
    required this.message,
  });

  bool get isMissingData => type == 'missing_data';
  bool get isInvalidReading => type == 'invalid_reading';
  bool get isAlreadyInvoiced => type == 'already_invoiced';

  String get typeDisplayName {
    switch (type) {
      case 'missing_data':
        return 'Thiếu dữ liệu';
      case 'invalid_reading':
        return 'Bất thường';
      case 'already_invoiced':
        return 'Đã có hóa đơn';
      default:
        return 'Cần kiểm tra';
    }
  }

  factory BulkInvoiceIssueItem.fromJson(Map<String, dynamic> json) {
    return BulkInvoiceIssueItem(
      apartmentId: json['apartment_id'] as String? ?? '',
      apartmentCode: json['apartment_code'] as String? ?? '',
      type: json['type'] as String? ?? 'missing_data',
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apartment_id': apartmentId,
      'apartment_code': apartmentCode,
      'type': type,
      'message': message,
    };
  }
}

class BulkInvoiceValidationModel {
  final String period;
  final int totalScanned;
  final int validCount;
  final int missingCount;
  final int invalidCount;
  final int alreadyInvoicedCount;
  final double totalEstimatedAmount;
  final List<ValidApartmentBillingItem> validItems;
  final List<BulkInvoiceIssueItem> issues;

  BulkInvoiceValidationModel({
    required this.period,
    required this.totalScanned,
    required this.validCount,
    required this.missingCount,
    required this.invalidCount,
    required this.alreadyInvoicedCount,
    required this.totalEstimatedAmount,
    required this.validItems,
    required this.issues,
  });

  bool get canGenerateAny => validCount > 0;
  int get totalIssuesCount => missingCount + invalidCount;

  factory BulkInvoiceValidationModel.fromJson(Map<String, dynamic> json) {
    final validRaw = json['valid_items'] as List<dynamic>? ?? [];
    final issuesRaw = json['issues'] as List<dynamic>? ?? [];

    return BulkInvoiceValidationModel(
      period: json['period'] as String? ?? '',
      totalScanned: json['total_scanned'] as int? ?? 0,
      validCount: json['valid_count'] as int? ?? 0,
      missingCount: json['missing_count'] as int? ?? 0,
      invalidCount: json['invalid_count'] as int? ?? 0,
      alreadyInvoicedCount: json['already_invoiced_count'] as int? ?? 0,
      totalEstimatedAmount: (json['total_estimated_amount'] as num?)?.toDouble() ?? 0.0,
      validItems: validRaw.map((e) => ValidApartmentBillingItem.fromJson(e as Map<String, dynamic>)).toList(),
      issues: issuesRaw.map((e) => BulkInvoiceIssueItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'total_scanned': totalScanned,
      'valid_count': validCount,
      'missing_count': missingCount,
      'invalid_count': invalidCount,
      'already_invoiced_count': alreadyInvoicedCount,
      'total_estimated_amount': totalEstimatedAmount,
      'valid_items': validItems.map((e) => e.toJson()).toList(),
      'issues': issues.map((e) => e.toJson()).toList(),
    };
  }
}
