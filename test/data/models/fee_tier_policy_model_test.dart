import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/fee_tier_policy_model.dart';
import 'package:pka_home/data/models/tiered_calculation_result_model.dart';

void main() {
  group('FeePolicyType Enum Tests', () {
    test('fromString parses all enum values and handles unknown fallback', () {
      expect(
        FeePolicyType.fromString('ELECTRICITY_TIER'),
        FeePolicyType.electricityTier,
      );
      expect(
        FeePolicyType.fromString('WATER_QUOTA_TIER'),
        FeePolicyType.waterQuotaTier,
      );
      expect(
        FeePolicyType.fromString('PARKING_PRORATA'),
        FeePolicyType.parkingProrata,
      );
      expect(
        FeePolicyType.fromString('LATE_PAYMENT_PENALTY'),
        FeePolicyType.latePaymentPenalty,
      );
      expect(
        FeePolicyType.fromString('MANAGEMENT_FEE'),
        FeePolicyType.managementFee,
      );
      expect(
        FeePolicyType.fromString('unknown_type'),
        FeePolicyType.electricityTier,
      );
      expect(FeePolicyType.fromString(null), FeePolicyType.electricityTier);
    });

    test('toDbString and vietnameseName return accurate values', () {
      expect(FeePolicyType.electricityTier.toDbString(), 'ELECTRICITY_TIER');
      expect(FeePolicyType.waterQuotaTier.toDbString(), 'WATER_QUOTA_TIER');
      expect(FeePolicyType.parkingProrata.toDbString(), 'PARKING_PRORATA');
      expect(
        FeePolicyType.latePaymentPenalty.toDbString(),
        'LATE_PAYMENT_PENALTY',
      );
      expect(FeePolicyType.managementFee.toDbString(), 'MANAGEMENT_FEE');

      expect(
        FeePolicyType.electricityTier.vietnameseName,
        'Điện sinh hoạt lũy tiến',
      );
      expect(
        FeePolicyType.waterQuotaTier.vietnameseName,
        'Nước sinh hoạt định mức',
      );
      expect(
        FeePolicyType.parkingProrata.vietnameseName,
        'Phí gửi xe theo ngày',
      );
      expect(
        FeePolicyType.latePaymentPenalty.vietnameseName,
        'Lãi phạt trễ hạn',
      );
      expect(FeePolicyType.managementFee.vietnameseName, 'Phí quản lý');
    });
  });

  group('FeeCalculationMethod Enum Tests', () {
    test('fromString parses all calculation methods correctly', () {
      expect(
        FeeCalculationMethod.fromString('PROGRESSIVE_TIER'),
        FeeCalculationMethod.progressiveTier,
      );
      expect(
        FeeCalculationMethod.fromString('PER_CAPITA_QUOTA'),
        FeeCalculationMethod.perCapitaQuota,
      );
      expect(
        FeeCalculationMethod.fromString('PRO_RATA_DAILY'),
        FeeCalculationMethod.proRataDaily,
      );
      expect(
        FeeCalculationMethod.fromString('PERCENTAGE_DAILY'),
        FeeCalculationMethod.percentageDaily,
      );
      expect(
        FeeCalculationMethod.fromString('FLAT_RATE'),
        FeeCalculationMethod.flatRate,
      );
      expect(
        FeeCalculationMethod.fromString('invalid'),
        FeeCalculationMethod.flatRate,
      );
    });

    test('toDbString and vietnameseName return standard strings', () {
      expect(
        FeeCalculationMethod.progressiveTier.toDbString(),
        'PROGRESSIVE_TIER',
      );
      expect(
        FeeCalculationMethod.perCapitaQuota.toDbString(),
        'PER_CAPITA_QUOTA',
      );
      expect(FeeCalculationMethod.proRataDaily.toDbString(), 'PRO_RATA_DAILY');
      expect(
        FeeCalculationMethod.percentageDaily.toDbString(),
        'PERCENTAGE_DAILY',
      );
      expect(FeeCalculationMethod.flatRate.toDbString(), 'FLAT_RATE');

      expect(
        FeeCalculationMethod.progressiveTier.vietnameseName,
        'Lũy tiến nhiều bậc',
      );
      expect(
        FeeCalculationMethod.perCapitaQuota.vietnameseName,
        'Định mức theo nhân khẩu',
      );
      expect(
        FeeCalculationMethod.proRataDaily.vietnameseName,
        'Tỷ lệ theo ngày thực tế',
      );
      expect(
        FeeCalculationMethod.percentageDaily.vietnameseName,
        'Tỷ lệ phần trăm theo ngày',
      );
      expect(FeeCalculationMethod.flatRate.vietnameseName, 'Cố định hàng tháng');
    });
  });

  group('FeeTierPolicyModel Serialization & Helpers Tests', () {
    final electricityPolicyJson = {
      'id': 'ftp-elec-001',
      'building_id': 'bld-001',
      'policy_type': 'ELECTRICITY_TIER',
      'name': 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)',
      'calculation_method': 'PROGRESSIVE_TIER',
      'tiers': [
        {
          'tier': 1,
          'name': 'Bậc 1 (0 - 50 kWh)',
          'from': 0,
          'to': 50,
          'rate': 1893,
        },
        {
          'tier': 2,
          'name': 'Bậc 2 (51 - 100 kWh)',
          'from': 50,
          'to': 100,
          'rate': 1956,
        },
        {
          'tier': 3,
          'name': 'Bậc 3 (101 - 200 kWh)',
          'from': 100,
          'to': 200,
          'rate': 2271,
        },
        {
          'tier': 4,
          'name': 'Bậc 4 (201 - 300 kWh)',
          'from': 200,
          'to': 300,
          'rate': 2860,
        },
        {
          'tier': 5,
          'name': 'Bậc 5 (301 - 400 kWh)',
          'from': 300,
          'to': 400,
          'rate': 3197,
        },
        {
          'tier': 6,
          'name': 'Bậc 6 (Trên 400 kWh)',
          'from': 400,
          'to': null,
          'rate': 3302,
        },
      ],
      'effective_from': '2024-01-01',
      'effective_to': null,
      'is_active': true,
      'created_at': '2024-01-01T00:00:00Z',
      'updated_at': '2024-01-01T00:00:00Z',
    };

    final waterPolicyJson = {
      'id': 'ftp-water-002',
      'building_id': null,
      'policy_type': 'WATER_QUOTA_TIER',
      'name': 'Nước sinh hoạt định mức 4m3/người',
      'calculation_method': 'PER_CAPITA_QUOTA',
      'tiers': {
        'quota_per_resident': 4.0,
        'base_rate': 8500,
        'excess_tier_1_ratio': 1.5,
        'excess_tier_1_rate': 12000,
        'excess_tier_2_rate': 18000,
      },
      'effective_from': '2024-01-01',
      'effective_to': '2024-12-31',
      'is_active': false,
      'created_at': '2024-01-01T00:00:00Z',
      'updated_at': '2024-01-01T00:00:00Z',
    };

    test('fromJson and toJson parse List-based tiers correctly', () {
      final model = FeeTierPolicyModel.fromJson(electricityPolicyJson);

      expect(model.id, 'ftp-elec-001');
      expect(model.buildingId, 'bld-001');
      expect(model.policyType, FeePolicyType.electricityTier);
      expect(model.name, 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)');
      expect(model.calculationMethod, FeeCalculationMethod.progressiveTier);
      expect(model.tiers is List, isTrue);
      expect((model.tiers as List).length, 6);
      expect(model.effectiveFrom, DateTime.parse('2024-01-01'));
      expect(model.effectiveTo, isNull);
      expect(model.isActive, isTrue);

      final json = model.toJson();
      expect(json['id'], 'ftp-elec-001');
      expect(json['policy_type'], 'ELECTRICITY_TIER');
      expect(json['calculation_method'], 'PROGRESSIVE_TIER');
      expect(json['is_active'], isTrue);
    });

    test('fromJson and toJson parse Map-based tiers and closed date correctly', () {
      final model = FeeTierPolicyModel.fromJson(waterPolicyJson);

      expect(model.id, 'ftp-water-002');
      expect(model.buildingId, isNull);
      expect(model.policyType, FeePolicyType.waterQuotaTier);
      expect(model.name, 'Nước sinh hoạt định mức 4m3/người');
      expect(model.calculationMethod, FeeCalculationMethod.perCapitaQuota);
      expect(model.tiers is Map, isTrue);
      expect((model.tiers as Map)['quota_per_resident'], 4.0);
      expect(model.effectiveTo, DateTime.parse('2024-12-31'));
      expect(model.isActive, isFalse);

      final json = model.toJson();
      expect(json['policy_type'], 'WATER_QUOTA_TIER');
      expect(json['calculation_method'], 'PER_CAPITA_QUOTA');
      expect(json['effective_to'], startsWith('2024-12-31'));
    });

    test('Vietnamese formatted helper properties return expected text', () {
      final elecModel = FeeTierPolicyModel.fromJson(electricityPolicyJson);
      final waterModel = FeeTierPolicyModel.fromJson(waterPolicyJson);

      expect(elecModel.policyTypeVietnamese, 'Điện sinh hoạt lũy tiến');
      expect(elecModel.calculationMethodVietnamese, 'Lũy tiến nhiều bậc');
      expect(elecModel.statusVietnamese, 'Đang áp dụng');
      expect(elecModel.formattedEffectiveRange, '01/01/2024 - Hiện tại');

      expect(waterModel.statusVietnamese, 'Tạm ngưng');
      expect(waterModel.formattedEffectiveRange, '01/01/2024 - 31/12/2024');
    });

    test('copyWith creates a new instance with updated properties', () {
      final original = FeeTierPolicyModel.fromJson(electricityPolicyJson);
      final modified = original.copyWith(
        name: 'Chính sách điện cập nhật',
        isActive: false,
      );

      expect(modified.id, original.id);
      expect(modified.name, 'Chính sách điện cập nhật');
      expect(modified.isActive, isFalse);
      expect(original.name, 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)');
    });
  });

  group('TierBreakdownItem and TieredCalculationResultModel Tests', () {
    final breakdownJson = {
      'tier': 1,
      'name': 'Bậc 1 (0 - 50 kWh)',
      'from': 0,
      'to': 50,
      'rate': 1893.0,
      'consumption': 50.0,
      'amount': 94650.0,
    };

    final resultJson = {
      'policy_id': 'ftp-elec-001',
      'policy_name': 'Điện sinh hoạt EVN 6 bậc',
      'consumption': 265.0,
      'total_amount': 605450.0,
      'breakdown': [
        {
          'tier': 1,
          'name': 'Bậc 1',
          'rate': 1893.0,
          'consumption': 50.0,
          'amount': 94650.0,
        },
        {
          'tier': 2,
          'name': 'Bậc 2',
          'rate': 1956.0,
          'consumption': 50.0,
          'amount': 97800.0,
        },
        {
          'tier': 3,
          'name': 'Bậc 3',
          'rate': 2271.0,
          'consumption': 100.0,
          'amount': 227100.0,
        },
        {
          'tier': 4,
          'name': 'Bậc 4',
          'rate': 2860.0,
          'consumption': 65.0,
          'amount': 185900.0,
        },
      ],
      'resident_count': 3,
      'quota': 12.0,
    };

    test('TierBreakdownItem parses JSON and formats currency correctly', () {
      final item = TierBreakdownItem.fromJson(breakdownJson);

      expect(item.tier, 1);
      expect(item.name, 'Bậc 1 (0 - 50 kWh)');
      expect(item.from, 0.0);
      expect(item.to, 50.0);
      expect(item.rate, 1893.0);
      expect(item.units, 50.0);
      expect(item.amount, 94650.0);
      expect(item.formattedAmount, contains('94.650'));
      expect(item.formattedAmount, contains('đ'));
      expect(item.formattedRate, contains('1.893'));
      expect(item.formattedRate, contains('đ'));

      final json = item.toJson();
      expect(json['tier'], 1);
      expect(json['amount'], 94650.0);
    });

    test('TieredCalculationResultModel parses JSON and formats totalAmount', () {
      final result = TieredCalculationResultModel.fromJson(resultJson);

      expect(result.policyId, 'ftp-elec-001');
      expect(result.policyName, 'Điện sinh hoạt EVN 6 bậc');
      expect(result.consumption, 265.0);
      expect(result.totalAmount, 605450.0);
      expect(result.breakdown.length, 4);
      expect(result.residentCount, 3);
      expect(result.baseQuota, 12.0);

      expect(result.formattedTotalAmount, contains('605.450'));
      expect(result.formattedTotalAmount, contains('đ'));

      final json = result.toJson();
      expect(json['total_amount'], 605450.0);
      expect(json['consumption'], 265.0);
    });
  });

  group('ProratedFeeResultModel Tests', () {
    final proratedJson = {
      'monthly_rate': 120000.0,
      'period': '2026-10',
      'start_date': '2026-10-16',
      'days_in_month': 31,
      'days_used': 16,
      'is_prorated': true,
      'total_amount': 61935.0,
    };

    test('ProratedFeeResultModel parses RPC output and formats numbers', () {
      final model = ProratedFeeResultModel.fromJson(proratedJson);

      expect(model.monthlyRate, 120000.0);
      expect(model.period, '2026-10');
      expect(model.startDate, DateTime.parse('2026-10-16'));
      expect(model.daysInMonth, 31);
      expect(model.daysUsed, 16);
      expect(model.isProrated, isTrue);
      expect(model.totalAmount, 61935.0);

      expect(model.formattedTotalAmount, contains('61.935'));
      expect(model.formattedTotalAmount, contains('đ'));
      expect(model.formattedMonthlyRate, contains('120.000'));
      expect(model.formattedMonthlyRate, contains('đ'));
      expect(model.summaryVietnamese, contains('16/31 ngày'));
      expect(model.summaryVietnamese, contains('pro-rata'));

      final json = model.toJson();
      expect(json['total_amount'], 61935.0);
      expect(json['days_used'], 16);
    });
  });

  group('LatePenaltyResultModel Tests', () {
    final penaltyJson = {
      'invoice_id': 'inv-12345',
      'due_date': '2026-10-15',
      'as_of_date': '2026-10-29',
      'days_overdue': 14,
      'in_grace_period': false,
      'penalty_rate_per_day': 0.0005,
      'penalty_amount': 10500.0,
      'total_amount': 1500000.0,
    };

    test('LatePenaltyResultModel parses JSON and computes total with penalty', () {
      final model = LatePenaltyResultModel.fromJson(penaltyJson);

      expect(model.invoiceId, 'inv-12345');
      expect(model.dueDate, DateTime.parse('2026-10-15'));
      expect(model.asOfDate, DateTime.parse('2026-10-29'));
      expect(model.daysOverdue, 14);
      expect(model.inGracePeriod, isFalse);
      expect(model.penaltyRatePerDay, 0.0005);
      expect(model.penaltyAmount, 10500.0);
      expect(model.totalAmount, 1500000.0);
      expect(model.totalWithPenalty, 1510500.0);

      expect(model.formattedPenaltyAmount, contains('10.500'));
      expect(model.formattedPenaltyAmount, contains('đ'));
      expect(model.formattedTotalAmount, contains('1.500.000'));
      expect(model.formattedTotalWithPenalty, contains('1.510.500'));
      expect(model.statusVietnamese, 'Quá hạn 14 ngày');

      final json = model.toJson();
      expect(json['invoice_id'], 'inv-12345');
      expect(json['penalty_amount'], 10500.0);
    });

    test('handles grace period status correctly', () {
      final graceJson = {
        'invoice_id': 'inv-grace',
        'due_date': '2026-10-15',
        'as_of_date': '2026-10-17',
        'days_overdue': 2,
        'in_grace_period': true,
        'penalty_rate_per_day': 0.0005,
        'penalty_amount': 0.0,
        'total_amount': 1500000.0,
      };

      final model = LatePenaltyResultModel.fromJson(graceJson);
      expect(model.inGracePeriod, isTrue);
      expect(model.penaltyAmount, 0.0);
      expect(model.statusVietnamese, 'Trong thời gian ân hạn (2 ngày)');
    });
  });
}
