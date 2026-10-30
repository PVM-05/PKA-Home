/// Model tóm tắt chỉ số tài chính tổng quan
class FinancialAgingSummaryModel {
  final double totalBilled;
  final double actualCollected;
  final double totalOutstanding;
  final int totalInvoiceCount;
  final int paidInvoiceCount;
  final int unpaidInvoiceCount;
  final double collectionRate;

  const FinancialAgingSummaryModel({
    required this.totalBilled,
    required this.actualCollected,
    required this.totalOutstanding,
    required this.totalInvoiceCount,
    required this.paidInvoiceCount,
    required this.unpaidInvoiceCount,
    required this.collectionRate,
  });

  factory FinancialAgingSummaryModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FinancialAgingSummaryModel(
        totalBilled: 0.0,
        actualCollected: 0.0,
        totalOutstanding: 0.0,
        totalInvoiceCount: 0,
        paidInvoiceCount: 0,
        unpaidInvoiceCount: 0,
        collectionRate: 0.0,
      );
    }
    return FinancialAgingSummaryModel(
      totalBilled: (json['total_billed'] as num?)?.toDouble() ?? 0.0,
      actualCollected: (json['actual_collected'] as num?)?.toDouble() ?? 0.0,
      totalOutstanding: (json['total_outstanding'] as num?)?.toDouble() ?? 0.0,
      totalInvoiceCount: (json['total_invoice_count'] as num?)?.toInt() ?? 0,
      paidInvoiceCount: (json['paid_invoice_count'] as num?)?.toInt() ?? 0,
      unpaidInvoiceCount: (json['unpaid_invoice_count'] as num?)?.toInt() ?? 0,
      collectionRate: (json['collection_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_billed': totalBilled,
        'actual_collected': actualCollected,
        'total_outstanding': totalOutstanding,
        'total_invoice_count': totalInvoiceCount,
        'paid_invoice_count': paidInvoiceCount,
        'unpaid_invoice_count': unpaidInvoiceCount,
        'collection_rate': collectionRate,
      };
}

/// Model phân loại 4 xô tuổi nợ (Aging Buckets)
class DebtAgingBucketModel {
  final double amount0To30;
  final int count0To30;
  final double amount31To60;
  final int count31To60;
  final double amount61To90;
  final int count61To90;
  final double amountOver90;
  final int countOver90;

  const DebtAgingBucketModel({
    required this.amount0To30,
    required this.count0To30,
    required this.amount31To60,
    required this.count31To60,
    required this.amount61To90,
    required this.count61To90,
    required this.amountOver90,
    required this.countOver90,
  });

  factory DebtAgingBucketModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DebtAgingBucketModel(
        amount0To30: 0.0,
        count0To30: 0,
        amount31To60: 0.0,
        count31To60: 0,
        amount61To90: 0.0,
        count61To90: 0,
        amountOver90: 0.0,
        countOver90: 0,
      );
    }
    final b030 = json['bucket_0_30'] as Map<String, dynamic>?;
    final b3160 = json['bucket_31_60'] as Map<String, dynamic>?;
    final b6190 = json['bucket_61_90'] as Map<String, dynamic>?;
    final bOver = json['bucket_over_90'] as Map<String, dynamic>?;

    return DebtAgingBucketModel(
      amount0To30: (b030?['amount'] as num?)?.toDouble() ?? 0.0,
      count0To30: (b030?['count'] as num?)?.toInt() ?? 0,
      amount31To60: (b3160?['amount'] as num?)?.toDouble() ?? 0.0,
      count31To60: (b3160?['count'] as num?)?.toInt() ?? 0,
      amount61To90: (b6190?['amount'] as num?)?.toDouble() ?? 0.0,
      count61To90: (b6190?['count'] as num?)?.toInt() ?? 0,
      amountOver90: (bOver?['amount'] as num?)?.toDouble() ?? 0.0,
      countOver90: (bOver?['count'] as num?)?.toInt() ?? 0,
    );
  }

  double get totalDebt => amount0To30 + amount31To60 + amount61To90 + amountOver90;
  int get totalCount => count0To30 + count31To60 + count61To90 + countOver90;

  Map<String, dynamic> toJson() => {
        'bucket_0_30': {'amount': amount0To30, 'count': count0To30},
        'bucket_31_60': {'amount': amount31To60, 'count': count31To60},
        'bucket_61_90': {'amount': amount61To90, 'count': count61To90},
        'bucket_over_90': {'amount': amountOver90, 'count': countOver90},
      };
}

/// Thống kê tỷ lệ thu hồi theo từng Block/Tòa
class BlockCollectionRateModel {
  final String blockName;
  final double blockBilled;
  final double blockCollected;
  final double blockOutstanding;
  final double collectionRate;

  const BlockCollectionRateModel({
    required this.blockName,
    required this.blockBilled,
    required this.blockCollected,
    required this.blockOutstanding,
    required this.collectionRate,
  });

  factory BlockCollectionRateModel.fromJson(Map<String, dynamic> json) {
    return BlockCollectionRateModel(
      blockName: json['block_name']?.toString() ?? 'Chung',
      blockBilled: (json['block_billed'] as num?)?.toDouble() ?? 0.0,
      blockCollected: (json['block_collected'] as num?)?.toDouble() ?? 0.0,
      blockOutstanding: (json['block_outstanding'] as num?)?.toDouble() ?? 0.0,
      collectionRate: (json['collection_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'block_name': blockName,
        'block_billed': blockBilled,
        'block_collected': blockCollected,
        'block_outstanding': blockOutstanding,
        'collection_rate': collectionRate,
      };
}

/// Chi tiết căn hộ nợ đọng
class DebtorApartmentModel {
  final String apartmentId;
  final String apartmentCode;
  final String ownerName;
  final String ownerPhone;
  final double totalDebt;
  final int maxDaysOverdue;
  final int unpaidInvoicesCount;
  final DateTime? oldestDueDate;
  final String riskLevel; // '0_30', '31_60', '61_90', 'over_90'

  const DebtorApartmentModel({
    required this.apartmentId,
    required this.apartmentCode,
    required this.ownerName,
    required this.ownerPhone,
    required this.totalDebt,
    required this.maxDaysOverdue,
    required this.unpaidInvoicesCount,
    this.oldestDueDate,
    required this.riskLevel,
  });

  factory DebtorApartmentModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['oldest_due_date'] != null) {
      parsedDate = DateTime.tryParse(json['oldest_due_date'].toString());
    }

    return DebtorApartmentModel(
      apartmentId: json['apartment_id']?.toString() ?? '',
      apartmentCode: json['apartment_code']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? 'Chưa đăng ký',
      ownerPhone: json['owner_phone']?.toString() ?? '',
      totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0.0,
      maxDaysOverdue: (json['max_days_overdue'] as num?)?.toInt() ?? 0,
      unpaidInvoicesCount: (json['unpaid_invoices_count'] as num?)?.toInt() ?? 0,
      oldestDueDate: parsedDate,
      riskLevel: json['risk_level']?.toString() ?? '0_30',
    );
  }

  bool get isSevereRisk => riskLevel == 'over_90' || maxDaysOverdue > 90;

  String get riskLevelText {
    switch (riskLevel) {
      case 'over_90':
        return 'Quá hạn >90 ngày (Nợ xấu)';
      case '61_90':
        return 'Quá hạn 61-90 ngày';
      case '31_60':
        return 'Quá hạn 31-60 ngày';
      default:
        return 'Trong hạn / Quá hạn 0-30 ngày';
    }
  }

  Map<String, dynamic> toJson() => {
        'apartment_id': apartmentId,
        'apartment_code': apartmentCode,
        'owner_name': ownerName,
        'owner_phone': ownerPhone,
        'total_debt': totalDebt,
        'max_days_overdue': maxDaysOverdue,
        'unpaid_invoices_count': unpaidInvoicesCount,
        'oldest_due_date': oldestDueDate?.toIso8601String(),
        'risk_level': riskLevel,
      };
}

/// Model tổng thể Báo Cáo Tài Chính & Tuổi Nợ
class FinancialAgingReportModel {
  final DateTime? generatedAt;
  final String? filterBuildingId;
  final String? filterPeriod;
  final FinancialAgingSummaryModel summary;
  final DebtAgingBucketModel agingBuckets;
  final List<BlockCollectionRateModel> collectionByBlock;
  final List<DebtorApartmentModel> debtors;

  const FinancialAgingReportModel({
    this.generatedAt,
    this.filterBuildingId,
    this.filterPeriod,
    required this.summary,
    required this.agingBuckets,
    required this.collectionByBlock,
    required this.debtors,
  });

  factory FinancialAgingReportModel.fromJson(Map<String, dynamic> json) {
    DateTime? genAt;
    if (json['generated_at'] != null) {
      genAt = DateTime.tryParse(json['generated_at'].toString());
    }

    final blockList = (json['collection_by_block'] as List<dynamic>?)
            ?.map((e) => BlockCollectionRateModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final debtorList = (json['debtors'] as List<dynamic>?)
            ?.map((e) => DebtorApartmentModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return FinancialAgingReportModel(
      generatedAt: genAt,
      filterBuildingId: json['filter_building_id']?.toString(),
      filterPeriod: json['filter_period']?.toString(),
      summary: FinancialAgingSummaryModel.fromJson(json['summary'] as Map<String, dynamic>?),
      agingBuckets: DebtAgingBucketModel.fromJson(json['aging_buckets'] as Map<String, dynamic>?),
      collectionByBlock: blockList,
      debtors: debtorList,
    );
  }

  Map<String, dynamic> toJson() => {
        'generated_at': generatedAt?.toIso8601String(),
        'filter_building_id': filterBuildingId,
        'filter_period': filterPeriod,
        'summary': summary.toJson(),
        'aging_buckets': agingBuckets.toJson(),
        'collection_by_block': collectionByBlock.map((e) => e.toJson()).toList(),
        'debtors': debtors.map((e) => e.toJson()).toList(),
      };
}
