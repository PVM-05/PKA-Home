import 'dart:math';
import '../../data/models/tiered_calculation_result_model.dart';

/// Bộ công cụ tính toán phí lũy tiến EVN, định mức nước, pro-rata và lãi phạt trễ hạn
/// Hỗ trợ tính toán offline trên client hoặc mô phỏng trực quan cho cư dân và BQL
class UtilityFeeCalculator {
  /// Biểu giá điện sinh hoạt 6 bậc mặc định theo Quyết định của Bộ Công Thương
  static const List<Map<String, dynamic>> defaultElectricityTiers = [
    {
      'tier': 1,
      'name': 'Bậc 1 (0 - 50 kWh)',
      'from': 0.0,
      'to': 50.0,
      'rate': 1893.0,
    },
    {
      'tier': 2,
      'name': 'Bậc 2 (51 - 100 kWh)',
      'from': 50.0,
      'to': 100.0,
      'rate': 1956.0,
    },
    {
      'tier': 3,
      'name': 'Bậc 3 (101 - 200 kWh)',
      'from': 100.0,
      'to': 200.0,
      'rate': 2271.0,
    },
    {
      'tier': 4,
      'name': 'Bậc 4 (201 - 300 kWh)',
      'from': 200.0,
      'to': 300.0,
      'rate': 2860.0,
    },
    {
      'tier': 5,
      'name': 'Bậc 5 (301 - 400 kWh)',
      'from': 300.0,
      'to': 400.0,
      'rate': 3197.0,
    },
    {
      'tier': 6,
      'name': 'Bậc 6 (Trên 400 kWh)',
      'from': 400.0,
      'to': null,
      'rate': 3302.0,
    },
  ];

  /// Tính tiền điện sinh hoạt theo 6 bậc lũy tiến chuẩn EVN
  static TieredCalculationResultModel calculateElectricityEVN6Tiers(
    num rawConsumption, {
    List<Map<String, dynamic>>? customTiers,
    String? policyId,
    String? policyName,
  }) {
    final effectiveKwh = max(0.0, rawConsumption.toDouble());
    final tiersToUse = customTiers ?? defaultElectricityTiers;

    double totalAmount = 0.0;
    final List<TierBreakdownItem> breakdown = [];

    for (final tierItem in tiersToUse) {
      final tierNum = (tierItem['tier'] as num?)?.toInt() ?? (breakdown.length + 1);
      final tierName = tierItem['name'] as String? ?? 'Bậc $tierNum';
      final from = (tierItem['from'] as num?)?.toDouble() ?? 0.0;
      final to = (tierItem['to'] as num?)?.toDouble();
      final rate = (tierItem['rate'] as num?)?.toDouble() ?? 0.0;

      double tierKwh = 0.0;
      if (effectiveKwh > from) {
        if (to != null) {
          tierKwh = min(effectiveKwh, to) - from;
        } else {
          tierKwh = effectiveKwh - from;
        }
      }

      final tierAmount = (tierKwh * rate).roundToDouble();
      totalAmount += tierAmount;

      breakdown.add(
        TierBreakdownItem(
          tier: tierNum,
          name: tierName,
          from: from,
          to: to,
          rate: rate,
          units: tierKwh,
          amount: tierAmount,
        ),
      );
    }

    return TieredCalculationResultModel(
      policyId: policyId,
      policyName: policyName ?? 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)',
      consumption: effectiveKwh,
      totalAmount: totalAmount,
      breakdown: breakdown,
    );
  }

  /// Tính tiền nước sinh hoạt theo định mức nhân khẩu (mặc định 4 m³/người/tháng)
  static TieredCalculationResultModel calculateWaterQuota({
    required num consumption,
    int residentCount = 1,
    double quotaPerResident = 4.0,
    double baseRate = 8500.0,
    double excessTier1Ratio = 1.5,
    double excessTier1Rate = 12000.0,
    double excessTier2Rate = 18000.0,
    String? policyId,
    String? policyName,
  }) {
    final effectiveM3 = max(0.0, consumption.toDouble());
    final effectiveResidents = max(1, residentCount);

    final quota = effectiveResidents * quotaPerResident;
    final limit2 = quota * excessTier1Ratio;

    double tier1M3 = 0.0;
    double tier1Amt = 0.0;
    double tier2M3 = 0.0;
    double tier2Amt = 0.0;
    double tier3M3 = 0.0;
    double tier3Amt = 0.0;

    // Bậc 1: Trong định mức [0, quota]
    if (effectiveM3 > 0) {
      tier1M3 = min(effectiveM3, quota);
      tier1Amt = (tier1M3 * baseRate).roundToDouble();
    }

    // Bậc 2: Vượt định mức cấp 1 (quota, limit2]
    if (effectiveM3 > quota) {
      tier2M3 = min(effectiveM3, limit2) - quota;
      tier2Amt = (tier2M3 * excessTier1Rate).roundToDouble();
    }

    // Bậc 3: Vượt định mức cấp 2 (> limit2)
    if (effectiveM3 > limit2) {
      tier3M3 = effectiveM3 - limit2;
      tier3Amt = (tier3M3 * excessTier2Rate).roundToDouble();
    }

    final totalAmount = tier1Amt + tier2Amt + tier3Amt;

    final quotaStr = quota == quota.truncateToDouble() ? quota.toInt().toString() : quota.toStringAsFixed(1);
    final limit2Str = limit2 == limit2.truncateToDouble() ? limit2.toInt().toString() : limit2.toStringAsFixed(1);

    final breakdown = [
      TierBreakdownItem(
        tier: 1,
        name: 'Trong định mức (0 - $quotaStr m³)',
        from: 0.0,
        to: quota,
        rate: baseRate,
        units: tier1M3,
        amount: tier1Amt,
      ),
      TierBreakdownItem(
        tier: 2,
        name: 'Vượt định mức cấp 1 ($quotaStr - $limit2Str m³)',
        from: quota,
        to: limit2,
        rate: excessTier1Rate,
        units: tier2M3,
        amount: tier2Amt,
      ),
      TierBreakdownItem(
        tier: 3,
        name: 'Vượt định mức cấp 2 (> $limit2Str m³)',
        from: limit2,
        to: null,
        rate: excessTier2Rate,
        units: tier3M3,
        amount: tier3Amt,
      ),
    ];

    return TieredCalculationResultModel(
      policyId: policyId,
      policyName: policyName ?? 'Nước sinh hoạt định mức ${quotaPerResident.toInt()}m3/người',
      consumption: effectiveM3,
      totalAmount: totalAmount,
      breakdown: breakdown,
      residentCount: effectiveResidents,
      baseQuota: quota,
    );
  }

  /// Tính phí xe theo tỷ lệ ngày sử dụng thực tế trong tháng (Pro-rata)
  static ProratedFeeResultModel calculateProratedVehicleFee({
    required num monthlyRate,
    DateTime? startDate,
    required String period, // Định dạng YYYY-MM
  }) {
    final rate = max(0.0, monthlyRate.toDouble());

    final parts = period.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;

    final periodStart = DateTime(year, month, 1);
    final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final periodEnd = nextMonth.subtract(const Duration(days: 1));
    final daysInMonth = periodEnd.day;

    final cleanStartDate = startDate != null
        ? DateTime(startDate.year, startDate.month, startDate.day)
        : null;

    int daysUsed;
    bool isProrated;
    double totalAmount;

    if (cleanStartDate == null || !cleanStartDate.isAfter(periodStart)) {
      daysUsed = daysInMonth;
      isProrated = false;
      totalAmount = rate;
    } else if (cleanStartDate.isAfter(periodEnd)) {
      daysUsed = 0;
      isProrated = true;
      totalAmount = 0.0;
    } else {
      daysUsed = periodEnd.difference(cleanStartDate).inDays + 1;
      isProrated = true;
      totalAmount = ((rate * daysUsed) / daysInMonth).roundToDouble();
    }

    return ProratedFeeResultModel(
      monthlyRate: rate,
      period: period,
      startDate: startDate,
      daysInMonth: daysInMonth,
      daysUsed: daysUsed,
      isProrated: isProrated,
      totalAmount: totalAmount,
    );
  }

  /// Tính lãi phạt chậm thanh toán sau khi hết thời gian ân hạn
  static LatePenaltyResultModel calculateLatePaymentPenalty({
    String? invoiceId,
    required num totalAmount,
    required DateTime dueDate,
    DateTime? asOfDate,
    int gracePeriodDays = 3,
    double penaltyRatePerDay = 0.0005,
    bool isPaid = false,
  }) {
    final amount = max(0.0, totalAmount.toDouble());
    final checkDate = asOfDate ?? DateTime.now();

    final cleanDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final cleanCheckDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

    if (isPaid) {
      return LatePenaltyResultModel(
        invoiceId: invoiceId ?? '',
        dueDate: dueDate,
        asOfDate: checkDate,
        daysOverdue: 0,
        inGracePeriod: false,
        penaltyRatePerDay: penaltyRatePerDay,
        penaltyAmount: 0.0,
        totalAmount: amount,
      );
    }

    final diff = cleanCheckDate.difference(cleanDueDate).inDays;
    int daysOverdue = 0;
    bool inGrace = false;
    double penaltyAmount = 0.0;

    if (diff <= 0) {
      daysOverdue = 0;
      inGrace = false;
      penaltyAmount = 0.0;
    } else if (diff <= gracePeriodDays) {
      daysOverdue = diff;
      inGrace = true;
      penaltyAmount = 0.0;
    } else {
      daysOverdue = diff;
      inGrace = false;
      penaltyAmount = (amount * penaltyRatePerDay * diff).roundToDouble();
    }

    return LatePenaltyResultModel(
      invoiceId: invoiceId ?? '',
      dueDate: dueDate,
      asOfDate: checkDate,
      daysOverdue: daysOverdue,
      inGracePeriod: inGrace,
      penaltyRatePerDay: penaltyRatePerDay,
      penaltyAmount: penaltyAmount,
      totalAmount: amount,
    );
  }
}
