import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/utility_fee_calculator.dart';
import '../../../data/models/fee_tier_policy_model.dart';
import '../../../data/providers/fee_policy_providers.dart';
import '../widgets/quick_fee_calculator_sheet.dart';

final NumberFormat _vnCurrency = NumberFormat('#,##0 đ', 'vi_VN');

/// Màn hình quản lý các chính sách biểu giá phí cho Ban Quản Lý (Milestone C2)
class FeePolicyManagementScreen extends ConsumerWidget {
  final String? buildingId;

  const FeePolicyManagementScreen({super.key, this.buildingId});

  static final List<FeeTierPolicyModel> _defaultPolicies = [
    FeeTierPolicyModel(
      id: 'default-elec',
      policyType: FeePolicyType.electricityTier,
      name: 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)',
      calculationMethod: FeeCalculationMethod.progressiveTier,
      tiers: UtilityFeeCalculator.defaultElectricityTiers,
      effectiveFrom: DateTime(2024, 10, 11),
      isActive: true,
    ),
    FeeTierPolicyModel(
      id: 'default-water',
      policyType: FeePolicyType.waterQuotaTier,
      name: 'Nước sinh hoạt định mức (4 m³/người/tháng)',
      calculationMethod: FeeCalculationMethod.perCapitaQuota,
      tiers: [
        {
          'tier': 1,
          'name': 'Trong định mức (0 - 16 m³)',
          'from': 0,
          'to': 16,
          'rate': 8500,
        },
        {
          'tier': 2,
          'name': 'Vượt định mức cấp 1 (16 - 24 m³)',
          'from': 16,
          'to': 24,
          'rate': 12000,
        },
        {
          'tier': 3,
          'name': 'Vượt định mức cấp 2 (> 24 m³)',
          'from': 24,
          'to': null,
          'rate': 18000,
        },
      ],
      effectiveFrom: DateTime(2024, 1, 1),
      isActive: true,
    ),
    FeeTierPolicyModel(
      id: 'default-parking',
      policyType: FeePolicyType.parkingProrata,
      name: 'Phí gửi xe pro-rata theo ngày thực tế',
      calculationMethod: FeeCalculationMethod.proRataDaily,
      tiers: {'rule': 'Tỷ lệ ngày thực tế trong tháng'},
      effectiveFrom: DateTime(2024, 1, 1),
      isActive: true,
    ),
    FeeTierPolicyModel(
      id: 'default-penalty',
      policyType: FeePolicyType.latePaymentPenalty,
      name: 'Lãi phạt trễ hạn thanh toán (0.05%/ngày)',
      calculationMethod: FeeCalculationMethod.percentageDaily,
      tiers: {'grace_period_days': 3, 'penalty_rate_per_day': 0.0005},
      effectiveFrom: DateTime(2024, 1, 1),
      isActive: true,
    ),
  ];

  void _openQuickCalculator(BuildContext context, [int initialTab = 0]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: QuickFeeCalculatorSheet(initialTabIndex: initialTab),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(feePoliciesProvider(buildingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Biểu Giá & Phí'),
        actions: [
          IconButton(
            key: const Key('btn_open_quick_calculator_appbar'),
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Công cụ tính nhanh',
            onPressed: () => _openQuickCalculator(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('btn_open_quick_calculator'),
        onPressed: () => _openQuickCalculator(context),
        icon: const Icon(Icons.calculate_outlined),
        label: const Text('Công cụ tính nhanh'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(feePoliciesProvider(buildingId).future),
        child: policiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => _buildContent(context, _defaultPolicies),
          data: (serverPolicies) {
            final policies = serverPolicies.isNotEmpty
                ? serverPolicies
                : _defaultPolicies;
            return _buildContent(context, policies);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<FeeTierPolicyModel> policies,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        // Banner giới thiệu
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.08),
                AppTheme.secondary.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biểu Giá & Chính Sách Phí',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Cơ chế tính điện 6 bậc EVN, nước định mức nhân khẩu, phí xe pro-rata và phạt chậm nộp.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Danh sách các chính sách biểu giá
        ...policies.map((policy) => _buildPolicyCard(context, policy)),
      ],
    );
  }

  Widget _buildPolicyCard(BuildContext context, FeeTierPolicyModel policy) {
    Key? tileKey;
    IconData icon;
    Color color;
    int calculatorTab = 0;

    switch (policy.policyType) {
      case FeePolicyType.electricityTier:
        tileKey = const Key('policy_tile_electricity');
        icon = Icons.bolt;
        color = Colors.amber.shade800;
        calculatorTab = 0;
        break;
      case FeePolicyType.waterQuotaTier:
        tileKey = const Key('policy_tile_water');
        icon = Icons.water_drop;
        color = Colors.blue.shade700;
        calculatorTab = 1;
        break;
      case FeePolicyType.parkingProrata:
        tileKey = const Key('policy_tile_parking');
        icon = Icons.directions_car;
        color = Colors.teal.shade700;
        calculatorTab = 2;
        break;
      case FeePolicyType.latePaymentPenalty:
        tileKey = const Key('policy_tile_penalty');
        icon = Icons.warning_amber_rounded;
        color = Colors.deepOrange.shade700;
        calculatorTab = 3;
        break;
      case FeePolicyType.managementFee:
        tileKey = const Key('policy_tile_management');
        icon = Icons.apartment;
        color = Colors.indigo.shade700;
        calculatorTab = 0;
        break;
    }

    return Card(
      key: Key('card_${policy.id}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: tileKey,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          policy.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${policy.calculationMethodVietnamese} • ${policy.formattedEffectiveRange}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: policy.isActive
                ? Colors.green.shade50
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: policy.isActive
                  ? Colors.green.shade400
                  : Colors.grey.shade400,
            ),
          ),
          child: Text(
            policy.statusVietnamese,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: policy.isActive
                  ? Colors.green.shade700
                  : Colors.grey.shade700,
            ),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildPolicyDetailContent(policy),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openQuickCalculator(context, calculatorTab),
              icon: const Icon(Icons.calculate, size: 18),
              label: Text(
                'Thử tính nhanh ${policy.policyTypeVietnamese.toLowerCase()}',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyDetailContent(FeeTierPolicyModel policy) {
    if (policy.policyType == FeePolicyType.electricityTier) {
      final tiersList = policy.tiers is List
          ? (policy.tiers as List)
          : UtilityFeeCalculator.defaultElectricityTiers;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bảng giá 6 bậc lũy tiến hiện hành:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...tiersList.map((tier) {
            final m = tier is Map<String, dynamic>
                ? tier
                : Map<String, dynamic>.from(tier as Map);
            final name = m['name'] as String? ?? 'Bậc ${m['tier']}';
            final rate = (m['rate'] as num?)?.toDouble() ?? 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${_vnCurrency.format(rate)}/kWh',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }

    if (policy.policyType == FeePolicyType.waterQuotaTier) {
      final tiersList = policy.tiers is List ? (policy.tiers as List) : [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Định mức tiêu chuẩn: 4 m³/người/tháng',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (tiersList.isNotEmpty)
            ...tiersList.map((tier) {
              final m = tier is Map<String, dynamic>
                  ? tier
                  : Map<String, dynamic>.from(tier as Map);
              final name = m['name'] as String? ?? 'Bậc ${m['tier']}';
              final rate = (m['rate'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${_vnCurrency.format(rate)}/m³',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            const Text(
              'Bậc 1 (Trong định mức): 8.500 đ/m³\nBậc 2 (Vượt cấp 1): 12.000 đ/m³\nBậc 3 (Vượt cấp 2): 18.000 đ/m³',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
        ],
      );
    }

    if (policy.policyType == FeePolicyType.parkingProrata) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Công thức phân bổ theo ngày:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Số tiền = (Đơn giá tháng × Số ngày sử dụng thực tế) / Tổng số ngày trong tháng',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Áp dụng tự động khi cư dân đăng ký hoặc hủy đăng ký phương tiện giữa chu kỳ tính phí.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (policy.policyType == FeePolicyType.latePaymentPenalty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quy định xử lý quá hạn thanh toán:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.error,
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Thời gian ân hạn: 3 ngày kể từ ngày đến hạn thanh toán.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppTheme.error,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lãi phạt quá hạn: 0.05% / ngày (~1.5% / tháng) tính trên dư nợ gốc.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Text(policy.name);
  }
}
