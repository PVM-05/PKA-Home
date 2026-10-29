import 'package:intl/intl.dart';

final NumberFormat _vnCurrencyFormatter = NumberFormat('#,##0 đ', 'vi_VN');

/// Chi tiết từng bậc tính giá (Tier Breakdown)
class TierBreakdownItem {
  final int tier;
  final String name;
  final double? from;
  final double? to;
  final double rate;
  final double units;
  final double amount;

  const TierBreakdownItem({
    required this.tier,
    required this.name,
    this.from,
    this.to,
    required this.rate,
    required this.units,
    required this.amount,
  });

  double get consumption => units;

  String get formattedAmount => _vnCurrencyFormatter.format(amount);

  String get formattedRate => _vnCurrencyFormatter.format(rate);

  String get formattedUnits {
    if (units == units.truncateToDouble()) {
      return units.toInt().toString();
    }
    return units.toStringAsFixed(2);
  }

  factory TierBreakdownItem.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['consumption'] ?? json['units'] ?? json['kwh'] ?? json['m3'] ?? 0;
    return TierBreakdownItem(
      tier: (json['tier'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      from: (json['from'] as num?)?.toDouble(),
      to: (json['to'] as num?)?.toDouble(),
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      units: (rawUnits as num).toDouble(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'name': name,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      'rate': rate,
      'units': units,
      'consumption': units,
      'amount': amount,
    };
  }
}

/// Kết quả phân tích và tính toán phí lũy tiến / định mức (Tiered Calculation Result)
class TieredCalculationResultModel {
  final String? policyId;
  final String policyName;
  final double consumption;
  final double totalAmount;
  final List<TierBreakdownItem> breakdown;
  final int? residentCount;
  final double? baseQuota;

  const TieredCalculationResultModel({
    this.policyId,
    required this.policyName,
    required this.consumption,
    required this.totalAmount,
    required this.breakdown,
    this.residentCount,
    this.baseQuota,
  });

  String get formattedTotalAmount => _vnCurrencyFormatter.format(totalAmount);

  String get formattedConsumption {
    if (consumption == consumption.truncateToDouble()) {
      return consumption.toInt().toString();
    }
    return consumption.toStringAsFixed(2);
  }

  factory TieredCalculationResultModel.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['breakdown'] as List<dynamic>? ?? [];
    final items = rawBreakdown
        .map((item) => TierBreakdownItem.fromJson(item as Map<String, dynamic>))
        .toList();

    final quotaVal = json['base_quota'] ?? json['quota'];

    return TieredCalculationResultModel(
      policyId: json['policy_id'] as String?,
      policyName: json['policy_name'] as String? ?? 'Biểu giá lũy tiến',
      consumption: (json['consumption'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      breakdown: items,
      residentCount: (json['resident_count'] as num?)?.toInt(),
      baseQuota: (quotaVal as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'policy_id': policyId,
      'policy_name': policyName,
      'consumption': consumption,
      'total_amount': totalAmount,
      'breakdown': breakdown.map((e) => e.toJson()).toList(),
      if (residentCount != null) 'resident_count': residentCount,
      if (baseQuota != null) 'base_quota': baseQuota,
      if (baseQuota != null) 'quota': baseQuota,
    };
  }
}

/// Kết quả tính phí dịch vụ/phí gửi xe theo ngày thực tế (Pro-rata Vehicle Fee Result)
class ProratedFeeResultModel {
  final double monthlyRate;
  final String period;
  final DateTime? startDate;
  final int daysInMonth;
  final int daysUsed;
  final bool isProrated;
  final double totalAmount;

  const ProratedFeeResultModel({
    required this.monthlyRate,
    required this.period,
    this.startDate,
    required this.daysInMonth,
    required this.daysUsed,
    required this.isProrated,
    required this.totalAmount,
  });

  String get formattedTotalAmount => _vnCurrencyFormatter.format(totalAmount);

  String get formattedMonthlyRate => _vnCurrencyFormatter.format(monthlyRate);

  String get summaryVietnamese {
    if (isProrated) {
      return '$daysUsed/$daysInMonth ngày (Áp dụng pro-rata)';
    }
    return 'Tròn tháng ($daysUsed/$daysInMonth ngày)';
  }

  factory ProratedFeeResultModel.fromJson(Map<String, dynamic> json) {
    return ProratedFeeResultModel(
      monthlyRate: (json['monthly_rate'] as num?)?.toDouble() ?? 0.0,
      period: json['period'] as String? ?? '',
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      daysInMonth: (json['days_in_month'] as num?)?.toInt() ?? 30,
      daysUsed: (json['days_used'] as num?)?.toInt() ?? 0,
      isProrated: json['is_prorated'] as bool? ?? false,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monthly_rate': monthlyRate,
      'period': period,
      'start_date': startDate?.toIso8601String(),
      'days_in_month': daysInMonth,
      'days_used': daysUsed,
      'is_prorated': isProrated,
      'total_amount': totalAmount,
    };
  }
}

/// Kết quả tính lãi phạt trễ hạn thanh toán (Late Payment Penalty Result)
class LatePenaltyResultModel {
  final String invoiceId;
  final DateTime dueDate;
  final DateTime asOfDate;
  final int daysOverdue;
  final bool inGracePeriod;
  final double penaltyRatePerDay;
  final double penaltyAmount;
  final double totalAmount;

  const LatePenaltyResultModel({
    required this.invoiceId,
    required this.dueDate,
    required this.asOfDate,
    required this.daysOverdue,
    required this.inGracePeriod,
    required this.penaltyRatePerDay,
    required this.penaltyAmount,
    required this.totalAmount,
  });

  double get totalWithPenalty => totalAmount + penaltyAmount;

  String get formattedPenaltyAmount => _vnCurrencyFormatter.format(penaltyAmount);

  String get formattedTotalAmount => _vnCurrencyFormatter.format(totalAmount);

  String get formattedTotalWithPenalty => _vnCurrencyFormatter.format(totalWithPenalty);

  String get statusVietnamese {
    if (daysOverdue <= 0) {
      return 'Chưa quá hạn';
    } else if (inGracePeriod) {
      return 'Trong thời gian ân hạn ($daysOverdue ngày)';
    } else {
      return 'Quá hạn $daysOverdue ngày';
    }
  }

  factory LatePenaltyResultModel.fromJson(Map<String, dynamic> json) {
    return LatePenaltyResultModel(
      invoiceId: json['invoice_id'] as String? ?? '',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      asOfDate: json['as_of_date'] != null
          ? DateTime.tryParse(json['as_of_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      daysOverdue: (json['days_overdue'] as num?)?.toInt() ?? 0,
      inGracePeriod: json['in_grace_period'] as bool? ?? false,
      penaltyRatePerDay: (json['penalty_rate_per_day'] as num?)?.toDouble() ?? 0.0005,
      penaltyAmount: (json['penalty_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'as_of_date': DateFormat('yyyy-MM-dd').format(asOfDate),
      'days_overdue': daysOverdue,
      'in_grace_period': inGracePeriod,
      'penalty_rate_per_day': penaltyRatePerDay,
      'penalty_amount': penaltyAmount,
      'total_amount': totalAmount,
    };
  }
}
