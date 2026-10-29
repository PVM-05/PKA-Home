import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/utility_fee_calculator.dart';

void main() {
  group('UtilityFeeCalculator.calculateElectricityEVN6Tiers Tests', () {
    test('calculates 0 kWh as 0 VND with 6 empty tiers', () {
      final result = UtilityFeeCalculator.calculateElectricityEVN6Tiers(0);

      expect(result.consumption, 0);
      expect(result.totalAmount, 0);
      expect(result.breakdown.length, 6);
      expect(result.breakdown.every((t) => t.units == 0 && t.amount == 0), isTrue);
    });

    test('calculates 45 kWh strictly within Tier 1 (0 - 50 kWh @ 1893)', () {
      final result = UtilityFeeCalculator.calculateElectricityEVN6Tiers(45);

      expect(result.consumption, 45);
      expect(result.breakdown[0].units, 45);
      expect(result.breakdown[0].rate, 1893);
      expect(result.breakdown[0].amount, 45 * 1893); // 85,185
      expect(result.totalAmount, 85185);
      expect(result.breakdown[1].units, 0);
    });

    test('calculates 75 kWh across Tier 1 (50 kWh) and Tier 2 (25 kWh @ 1956)', () {
      final result = UtilityFeeCalculator.calculateElectricityEVN6Tiers(75);

      expect(result.consumption, 75);
      expect(result.breakdown[0].units, 50);
      expect(result.breakdown[0].amount, 50 * 1893); // 94,650
      expect(result.breakdown[1].units, 25);
      expect(result.breakdown[1].amount, 25 * 1956); // 48,900
      expect(result.totalAmount, 94650 + 48900); // 143,550
      expect(result.breakdown[2].units, 0);
    });

    test('calculates 265 kWh across Tiers 1-4 (total 605,450 VND)', () {
      final result = UtilityFeeCalculator.calculateElectricityEVN6Tiers(265);

      expect(result.consumption, 265);
      expect(result.breakdown[0].units, 50);
      expect(result.breakdown[0].amount, 94650);
      expect(result.breakdown[1].units, 50);
      expect(result.breakdown[1].amount, 97800);
      expect(result.breakdown[2].units, 100);
      expect(result.breakdown[2].amount, 227100);
      expect(result.breakdown[3].units, 65);
      expect(result.breakdown[3].amount, 185900);
      expect(result.breakdown[4].units, 0);
      expect(result.breakdown[5].units, 0);
      expect(result.totalAmount, 605450);
    });

    test('calculates 450 kWh across all 6 tiers', () {
      final result = UtilityFeeCalculator.calculateElectricityEVN6Tiers(450);

      expect(result.consumption, 450);
      expect(result.breakdown[0].units, 50); // 94,650
      expect(result.breakdown[1].units, 50); // 97,800
      expect(result.breakdown[2].units, 100); // 227,100
      expect(result.breakdown[3].units, 100); // 286,000
      expect(result.breakdown[4].units, 100); // 319,700
      expect(result.breakdown[5].units, 50); // 165,100
      expect(
        result.totalAmount,
        94650 + 97800 + 227100 + 286000 + 319700 + 165100,
      ); // 1,190,350
    });

    test('handles negative consumption safely as 0', () {
      final result = UtilityFeeCalculator.calculateElectricityEVN6Tiers(-10);
      expect(result.consumption, 0);
      expect(result.totalAmount, 0);
    });
  });

  group('UtilityFeeCalculator.calculateWaterQuota Tests', () {
    test('calculates 0 m3 as 0 VND', () {
      final result = UtilityFeeCalculator.calculateWaterQuota(
        consumption: 0,
        residentCount: 3,
      );

      expect(result.consumption, 0);
      expect(result.totalAmount, 0);
      expect(result.residentCount, 3);
      expect(result.baseQuota, 12.0); // 3 * 4.0
    });

    test('calculates 10 m3 with 3 residents (within 12 m3 quota)', () {
      // Quota: 3 * 4 = 12 m3. All 10 m3 is in Tier 1 @ 8500
      final result = UtilityFeeCalculator.calculateWaterQuota(
        consumption: 10,
        residentCount: 3,
      );

      expect(result.consumption, 10);
      expect(result.baseQuota, 12);
      expect(result.breakdown[0].units, 10);
      expect(result.breakdown[0].amount, 85000);
      expect(result.breakdown[1].units, 0);
      expect(result.breakdown[2].units, 0);
      expect(result.totalAmount, 85000);
    });

    test('calculates 15 m3 with 3 residents (exceeds quota, Tier 1 + Tier 2)', () {
      // Quota: 12 m3 @ 8500 = 102,000
      // Excess Tier 1: 15 - 12 = 3 m3 @ 12000 = 36,000
      // Total: 138,000
      final result = UtilityFeeCalculator.calculateWaterQuota(
        consumption: 15,
        residentCount: 3,
      );

      expect(result.consumption, 15);
      expect(result.breakdown[0].units, 12);
      expect(result.breakdown[0].amount, 102000);
      expect(result.breakdown[1].units, 3);
      expect(result.breakdown[1].amount, 36000);
      expect(result.breakdown[2].units, 0);
      expect(result.totalAmount, 138000);
    });

    test('calculates 20 m3 with 3 residents (reaches Excess Tier 2)', () {
      // Quota: 12 m3 @ 8500 = 102,000
      // Limit 2: 12 * 1.5 = 18 m3
      // Excess Tier 1: (18 - 12) = 6 m3 @ 12000 = 72,000
      // Excess Tier 2: (20 - 18) = 2 m3 @ 18000 = 36,000
      // Total: 102,000 + 72,000 + 36,000 = 210,000
      final result = UtilityFeeCalculator.calculateWaterQuota(
        consumption: 20,
        residentCount: 3,
      );

      expect(result.consumption, 20);
      expect(result.breakdown[0].units, 12);
      expect(result.breakdown[0].amount, 102000);
      expect(result.breakdown[1].units, 6);
      expect(result.breakdown[1].amount, 72000);
      expect(result.breakdown[2].units, 2);
      expect(result.breakdown[2].amount, 36000);
      expect(result.totalAmount, 210000);
    });

    test('calculates 10 m3 with 1 resident (quota 4 m3, limit2 6 m3)', () {
      // Quota: 4 m3 @ 8500 = 34,000
      // Tier 2: 2 m3 @ 12000 = 24,000
      // Tier 3: 4 m3 @ 18000 = 72,000
      // Total: 34,000 + 24,000 + 72,000 = 130,000
      final result = UtilityFeeCalculator.calculateWaterQuota(
        consumption: 10,
        residentCount: 1,
      );

      expect(result.baseQuota, 4);
      expect(result.breakdown[0].units, 4);
      expect(result.breakdown[0].amount, 34000);
      expect(result.breakdown[1].units, 2);
      expect(result.breakdown[1].amount, 24000);
      expect(result.breakdown[2].units, 4);
      expect(result.breakdown[2].amount, 72000);
      expect(result.totalAmount, 130000);
    });

    test('calculates 15 m3 with 4 residents (quota 16 m3 - within quota)', () {
      final result = UtilityFeeCalculator.calculateWaterQuota(
        consumption: 15,
        residentCount: 4,
      );

      expect(result.baseQuota, 16);
      expect(result.breakdown[0].units, 15);
      expect(result.breakdown[0].amount, 15 * 8500); // 127,500
      expect(result.totalAmount, 127500);
    });
  });

  group('UtilityFeeCalculator.calculateProratedVehicleFee Tests', () {
    test('startDate on 1st of month returns full monthly rate (not prorated)', () {
      final result = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: 120000,
        startDate: DateTime(2026, 10, 1),
        period: '2026-10',
      );

      expect(result.daysInMonth, 31);
      expect(result.daysUsed, 31);
      expect(result.isProrated, isFalse);
      expect(result.totalAmount, 120000);
    });

    test('startDate null returns full rate as unprorated', () {
      final result = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: 120000,
        startDate: null,
        period: '2026-10',
      );

      expect(result.isProrated, isFalse);
      expect(result.daysUsed, 31);
      expect(result.totalAmount, 120000);
    });

    test('startDate 2026-10-16 in 31-day month calculates 16 days (61,935 VND)', () {
      // 31 - 16 + 1 = 16 days. (120,000 * 16) / 31 = 61,935.48 -> 61,935
      final result = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: 120000,
        startDate: DateTime(2026, 10, 16),
        period: '2026-10',
      );

      expect(result.daysInMonth, 31);
      expect(result.daysUsed, 16);
      expect(result.isProrated, isTrue);
      expect(result.totalAmount, 61935);
    });

    test('startDate in leap year February (2024-02: 29 days)', () {
      // 2024-02-15: 29 - 15 + 1 = 15 days. (120,000 * 15) / 29 = 62,068.96 -> 62,069
      final result = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: 120000,
        startDate: DateTime(2024, 2, 15),
        period: '2024-02',
      );

      expect(result.daysInMonth, 29);
      expect(result.daysUsed, 15);
      expect(result.isProrated, isTrue);
      expect(result.totalAmount, 62069);
    });

    test('startDate in non-leap year February (2025-02: 28 days)', () {
      // 2025-02-15: 28 - 15 + 1 = 14 days. (120,000 * 14) / 28 = 60,000
      final result = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: 120000,
        startDate: DateTime(2025, 2, 15),
        period: '2025-02',
      );

      expect(result.daysInMonth, 28);
      expect(result.daysUsed, 14);
      expect(result.isProrated, isTrue);
      expect(result.totalAmount, 60000);
    });

    test('startDate after month end calculates 0 days and 0 VND', () {
      final result = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: 120000,
        startDate: DateTime(2026, 11, 5),
        period: '2026-10',
      );

      expect(result.daysUsed, 0);
      expect(result.isProrated, isTrue);
      expect(result.totalAmount, 0);
    });
  });

  group('UtilityFeeCalculator.calculateLatePaymentPenalty Tests', () {
    test('returns 0 penalty if invoice is already paid', () {
      final result = UtilityFeeCalculator.calculateLatePaymentPenalty(
        totalAmount: 1500000,
        dueDate: DateTime(2026, 10, 15),
        asOfDate: DateTime(2026, 10, 29),
        isPaid: true,
      );

      expect(result.daysOverdue, 0);
      expect(result.inGracePeriod, isFalse);
      expect(result.penaltyAmount, 0);
      expect(result.totalWithPenalty, 1500000);
    });

    test('returns 0 penalty when not yet overdue', () {
      final result = UtilityFeeCalculator.calculateLatePaymentPenalty(
        totalAmount: 1500000,
        dueDate: DateTime(2026, 10, 20),
        asOfDate: DateTime(2026, 10, 18),
      );

      expect(result.daysOverdue, 0);
      expect(result.inGracePeriod, isFalse);
      expect(result.penaltyAmount, 0);
      expect(result.totalWithPenalty, 1500000);
    });

    test('returns 0 penalty when within 3-day grace period', () {
      // Due: Oct 15, as of: Oct 18 (diff: 3 days -> within grace)
      final result = UtilityFeeCalculator.calculateLatePaymentPenalty(
        totalAmount: 1500000,
        dueDate: DateTime(2026, 10, 15),
        asOfDate: DateTime(2026, 10, 18),
        gracePeriodDays: 3,
      );

      expect(result.daysOverdue, 3);
      expect(result.inGracePeriod, isTrue);
      expect(result.penaltyAmount, 0);
      expect(result.totalWithPenalty, 1500000);
    });

    test('calculates 10,500 VND penalty for 14 days overdue at 0.05%/day', () {
      // Due: Oct 15, as of: Oct 29 (diff: 14 days)
      // Penalty: 1,500,000 * 0.0005 * 14 = 10,500
      final result = UtilityFeeCalculator.calculateLatePaymentPenalty(
        invoiceId: 'inv-12345',
        totalAmount: 1500000,
        dueDate: DateTime(2026, 10, 15),
        asOfDate: DateTime(2026, 10, 29),
        gracePeriodDays: 3,
        penaltyRatePerDay: 0.0005,
      );

      expect(result.invoiceId, 'inv-12345');
      expect(result.daysOverdue, 14);
      expect(result.inGracePeriod, isFalse);
      expect(result.penaltyAmount, 10500);
      expect(result.totalWithPenalty, 1510500);
    });
  });
}
