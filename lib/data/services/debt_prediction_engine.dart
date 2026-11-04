import 'dart:math';
import '../models/debt_risk_score_model.dart';

class DebtCalculationResult {
  final int riskScore;
  final DebtRiskLevel riskLevel;
  final DunningTier recommendedTier;
  final List<RiskFactorModel> riskFactors;

  const DebtCalculationResult({
    required this.riskScore,
    required this.riskLevel,
    required this.recommendedTier,
    required this.riskFactors,
  });
}

class DebtPredictionEngine {
  /// Tính toán điểm rủi ro nợ xấu theo mô hình định lượng 3 trọng số:
  /// - Quá hạn: 40%
  /// - Tỷ lệ nợ / Phí trung bình: 35%
  /// - Lịch sử nộp muộn: 25%
  static DebtCalculationResult calculate({
    required double unpaidAmount,
    required int overdueDays,
    required double monthlyFeeAvg,
    required int latePaymentCount,
  }) {
    final effectiveMonthlyFee = monthlyFeeAvg > 0 ? monthlyFeeAvg : 1500000.0;

    // 1. Điểm số ngày quá hạn (0 - 100)
    double scoreOverdue = 0;
    if (overdueDays <= 0) {
      scoreOverdue = 0;
    } else if (overdueDays <= 15) {
      scoreOverdue = min(40.0, overdueDays * 2.6);
    } else if (overdueDays <= 30) {
      scoreOverdue = min(70.0, 40.0 + (overdueDays - 15) * 2.0);
    } else {
      scoreOverdue = min(100.0, 70.0 + (overdueDays - 30) * 1.5);
    }

    // 2. Điểm tỷ lệ nợ (0 - 100)
    final debtRatio = unpaidAmount / effectiveMonthlyFee;
    double scoreRatio = 0;
    if (debtRatio <= 0) {
      scoreRatio = 0;
    } else if (debtRatio <= 1.0) {
      scoreRatio = min(40.0, debtRatio * 40.0);
    } else if (debtRatio <= 2.0) {
      scoreRatio = min(70.0, 40.0 + (debtRatio - 1.0) * 30.0);
    } else {
      scoreRatio = min(100.0, 70.0 + (debtRatio - 2.0) * 30.0);
    }

    // 3. Điểm lịch sử trả muộn (0 - 100)
    double scoreHistory = 0;
    if (latePaymentCount <= 0) {
      scoreHistory = 0;
    } else if (latePaymentCount == 1) {
      scoreHistory = 25;
    } else if (latePaymentCount == 2) {
      scoreHistory = 50;
    } else if (latePaymentCount == 3) {
      scoreHistory = 75;
    } else {
      scoreHistory = 100;
    }

    // Tổng hợp điểm từ 0 đến 100
    final rawTotal = 0.40 * scoreOverdue + 0.35 * scoreRatio + 0.25 * scoreHistory;
    final totalScore = min(100, max(0, rawTotal.round()));

    // Xác định phân cấp rủi ro
    DebtRiskLevel riskLevel;
    DunningTier recommendedTier;

    if (totalScore >= 70) {
      riskLevel = DebtRiskLevel.high;
      recommendedTier = DunningTier.tier3;
    } else if (totalScore >= 40) {
      riskLevel = DebtRiskLevel.medium;
      recommendedTier = DunningTier.tier2;
    } else {
      riskLevel = DebtRiskLevel.low;
      recommendedTier = DunningTier.tier1;
    }

    // Nếu quá hạn nặng > 45 ngày thì nâng mức đôn đốc lên tier3
    if (overdueDays > 45) {
      recommendedTier = DunningTier.tier3;
    }

    // Xây dựng danh sách yếu tố rủi ro
    final factors = <RiskFactorModel>[];
    if (overdueDays > 0) {
      factors.add(
        RiskFactorModel(
          factor: 'overdue_duration',
          label: 'Quá hạn $overdueDays ngày',
          severity: overdueDays > 30 ? 'high' : (overdueDays > 15 ? 'medium' : 'low'),
        ),
      );
    }

    if (debtRatio >= 1.5) {
      factors.add(
        RiskFactorModel(
          factor: 'debt_ratio',
          label: 'Nợ vượt ${debtRatio.toStringAsFixed(1)} lần phí định kỳ',
          severity: debtRatio >= 2.0 ? 'high' : 'medium',
        ),
      );
    }

    if (latePaymentCount >= 2) {
      factors.add(
        RiskFactorModel(
          factor: 'late_history',
          label: 'Từng nộp muộn $latePaymentCount kỳ trong quá khứ',
          severity: latePaymentCount >= 3 ? 'high' : 'medium',
        ),
      );
    }

    return DebtCalculationResult(
      riskScore: totalScore,
      riskLevel: riskLevel,
      recommendedTier: recommendedTier,
      riskFactors: factors,
    );
  }
}
