import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/utility_fee_calculator.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/fee_tier_policy_model.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/fee_policy_providers.dart';
import '../widgets/quick_fee_calculator_sheet.dart';

final NumberFormat _vnCurrency = NumberFormat('#,##0 đ', 'vi_VN');

/// Màn hình quản lý các chính sách biểu giá phí cho Ban Quản Lý.
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
    showModalBottomSheet<void>(
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
    final colorScheme = Theme.of(context).colorScheme;

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
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(feePoliciesProvider(buildingId).future),
            child: policiesAsync.when(
              loading: () => ListView(
                padding: AppSpacing.p16,
                children: [
                  AppSkeletonShimmer.cardList(count: 4, itemHeight: 110),
                ],
              ),
              error: (_, _) => _buildContent(context, ref, _defaultPolicies),
              data: (serverPolicies) {
                final policies = serverPolicies.isNotEmpty
                    ? serverPolicies
                    : _defaultPolicies;
                return _buildContent(context, ref, policies);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditPolicyDialog(
    BuildContext context,
    WidgetRef ref,
    FeeTierPolicyModel policy,
  ) async {
    final activeBuilding = ref.read(activeBuildingProvider).value;
    final effectiveBuildingId = buildingId ?? activeBuilding?.id;

    final nameController = TextEditingController(text: policy.name);
    final rateControllers = <TextEditingController>[];

    List<Map<String, dynamic>> currentTiersList = [];
    if (policy.policyType == FeePolicyType.electricityTier) {
      final list = policy.tiers is List
          ? (policy.tiers as List)
          : UtilityFeeCalculator.defaultElectricityTiers;
      currentTiersList = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final t in currentTiersList) {
        final rate = (t['rate'] as num?)?.round() ?? 0;
        rateControllers.add(TextEditingController(text: formatMoney(rate)));
      }
    } else if (policy.policyType == FeePolicyType.waterQuotaTier) {
      final list = policy.tiers is List ? (policy.tiers as List) : [];
      currentTiersList = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (currentTiersList.isEmpty) {
        currentTiersList = [
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
        ];
      }
      for (final t in currentTiersList) {
        final rate = (t['rate'] as num?)?.round() ?? 0;
        rateControllers.add(TextEditingController(text: formatMoney(rate)));
      }
    }

    final gracePeriodController = TextEditingController(
      text: (policy.tiers is Map
              ? (policy.tiers['grace_period_days'] ?? 3)
              : 3)
          .toString(),
    );
    final penaltyRateController = TextEditingController(
      text: (policy.tiers is Map
              ? ((policy.tiers['penalty_rate_per_day'] ?? 0.0005) * 100)
              : 0.05)
          .toString(),
    );

    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.tune_rounded, color: colorScheme.primary),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Điều chỉnh biểu giá ${policy.policyTypeVietnamese.toLowerCase()}',
                  style: ctx.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên chính sách biểu giá',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập tên'
                          : null,
                    ),
                    AppSpacing.h16,
                    if (policy.policyType == FeePolicyType.electricityTier ||
                        policy.policyType == FeePolicyType.waterQuotaTier) ...[
                      Text(
                        'Đơn giá theo từng bậc (${policy.policyType == FeePolicyType.electricityTier ? "đ/kWh" : "đ/m³"}):',
                        style: ctx.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.h8,
                      ...List.generate(currentTiersList.length, (index) {
                        final tier = currentTiersList[index];
                        final tierName =
                            tier['name'] as String? ?? 'Bậc ${tier['tier']}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(tierName, style: ctx.bodySmall),
                              ),
                              AppSpacing.w8,
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: rateControllers[index],
                                  decoration: const InputDecoration(
                                    suffixText: 'đ',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [MoneyInputFormatter()],
                                  validator: (v) => (v == null || parseMoney(v) <= 0)
                                      ? 'Nhập giá'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else if (policy.policyType ==
                        FeePolicyType.latePaymentPenalty) ...[
                      TextFormField(
                        controller: gracePeriodController,
                        decoration: const InputDecoration(
                          labelText: 'Thời gian ân hạn (ngày)',
                          suffixText: 'ngày',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null ||
                                int.tryParse(v) == null ||
                                int.parse(v) < 0)
                            ? 'Vui lòng nhập số ngày hợp lệ'
                            : null,
                      ),
                      AppSpacing.h12,
                      TextFormField(
                        controller: penaltyRateController,
                        decoration: const InputDecoration(
                          labelText: 'Lãi phạt mỗi ngày (%)',
                          suffixText: '%/ngày',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) => (v == null ||
                                double.tryParse(v) == null ||
                                double.parse(v) < 0)
                            ? 'Vui lòng nhập % lãi phạt'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Lưu chính sách'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    dynamic updatedTiers;
    if (policy.policyType == FeePolicyType.electricityTier ||
        policy.policyType == FeePolicyType.waterQuotaTier) {
      final newTiers = <Map<String, dynamic>>[];
      for (int i = 0; i < currentTiersList.length; i++) {
        final t = Map<String, dynamic>.from(currentTiersList[i]);
        t['rate'] = parseMoney(rateControllers[i].text);
        newTiers.add(t);
      }
      updatedTiers = newTiers;
    } else if (policy.policyType == FeePolicyType.latePaymentPenalty) {
      final graceDays = int.tryParse(gracePeriodController.text) ?? 3;
      final penaltyPct = double.tryParse(penaltyRateController.text) ?? 0.05;
      updatedTiers = {
        'grace_period_days': graceDays,
        'penalty_rate_per_day': penaltyPct / 100.0,
      };
    } else {
      updatedTiers = policy.tiers;
    }

    final updatedPolicy = FeeTierPolicyModel(
      id: policy.id.startsWith('default-') ? '' : policy.id,
      buildingId: effectiveBuildingId,
      policyType: policy.policyType,
      name: nameController.text.trim(),
      calculationMethod: policy.calculationMethod,
      tiers: updatedTiers,
      effectiveFrom: DateTime.now(),
      isActive: true,
    );

    await runAction(
      context,
      () async {
        await ref.read(feePolicyRepositoryProvider).upsertPolicy(updatedPolicy);
        ref.invalidate(feePoliciesProvider(buildingId));
        return 'Đã lưu cấu hình biểu giá riêng cho tòa nhà thành công!';
      },
      actionName: 'Lưu chính sách biểu giá',
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<FeeTierPolicyModel> policies,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        // Banner giới thiệu
        Container(
          padding: AppSpacing.p16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.08),
                secondaryColor.withValues(alpha: 0.14),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.r16,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: AppSpacing.p12,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: colorScheme.onPrimary,
                  size: 28,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biểu Giá & Chính Sách Phí',
                      style: context.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    AppSpacing.h4,
                    Text(
                      'Cơ chế tính điện 6 bậc EVN, nước định mức nhân khẩu, phí xe pro-rata và phạt chậm nộp.',
                      style: context.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppSpacing.h16,
        ...policies.map((policy) => _buildPolicyCard(context, ref, policy)),
      ],
    );
  }

  Widget _buildPolicyCard(
    BuildContext context,
    WidgetRef ref,
    FeeTierPolicyModel policy,
  ) {
    final isSystemDefault =
        policy.id.startsWith('default-') || policy.buildingId == null;
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    final Key? tileKey;
    final IconData icon;
    final Color color;
    final int calculatorTab;

    switch (policy.policyType) {
      case FeePolicyType.electricityTier:
        tileKey = const Key('policy_tile_electricity');
        icon = Icons.bolt;
        color = warningColor;
        calculatorTab = 0;
        break;
      case FeePolicyType.waterQuotaTier:
        tileKey = const Key('policy_tile_water');
        icon = Icons.water_drop;
        color = secondaryColor;
        calculatorTab = 1;
        break;
      case FeePolicyType.parkingProrata:
        tileKey = const Key('policy_tile_parking');
        icon = Icons.directions_car;
        color = successColor;
        calculatorTab = 2;
        break;
      case FeePolicyType.latePaymentPenalty:
        tileKey = const Key('policy_tile_penalty');
        icon = Icons.warning_amber_rounded;
        color = errorColor;
        calculatorTab = 3;
        break;
      case FeePolicyType.managementFee:
        tileKey = const Key('policy_tile_management');
        icon = Icons.apartment;
        color = colorScheme.primary;
        calculatorTab = 0;
        break;
    }

    final scopeColor = isSystemDefault ? warningColor : colorScheme.primary;
    final activeColor = policy.isActive
        ? successColor
        : colorScheme.onSurfaceVariant;

    return Card(
      key: Key('card_${policy.id}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.r16,
        side: BorderSide(color: colorScheme.outlineVariant),
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
          style: context.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${policy.calculationMethodVietnamese} • ${policy.formattedEffectiveRange}',
                style: context.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)
                    .tabularFigures(),
              ),
              AppSpacing.h6,
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scopeColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r8,
                      border: Border.all(
                        color: scopeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSystemDefault ? Icons.public : Icons.domain,
                          size: 13,
                          color: scopeColor,
                        ),
                        AppSpacing.w4,
                        Text(
                          isSystemDefault
                              ? 'Mặc định hệ thống'
                              : 'Cấu hình riêng',
                          style: context.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scopeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r8,
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      policy.statusVietnamese,
                      style: context.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          AppSpacing.h12,
          _buildPolicyDetailContent(context, policy),
          AppSpacing.h16,
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditPolicyDialog(context, ref, policy),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Chỉnh sửa biểu giá'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openQuickCalculator(context, calculatorTab),
                  icon: const Icon(Icons.calculate, size: 18),
                  label: Text(
                    'Thử tính nhanh ${policy.policyTypeVietnamese.toLowerCase()}',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    minimumSize: const Size(0, 48),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyDetailContent(
    BuildContext context,
    FeeTierPolicyModel policy,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final errorColor = AppTheme.getSemanticError(context);

    if (policy.policyType == FeePolicyType.electricityTier) {
      final tiersList = policy.tiers is List
          ? (policy.tiers as List)
          : UtilityFeeCalculator.defaultElectricityTiers;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bảng giá 6 bậc lũy tiến hiện hành:',
            style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h8,
          ...tiersList.map((tier) {
            final m = tier is Map<String, dynamic>
                ? tier
                : Map<String, dynamic>.from(tier as Map);
            final name = m['name'] as String? ?? 'Bậc ${m['tier']}';
            final rate = (m['rate'] as num?)?.toDouble() ?? 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: context.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  AppSpacing.w8,
                  Text(
                    '${_vnCurrency.format(rate)}/kWh',
                    style: context.bodySmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        )
                        .tabularFigures(),
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
          Text(
            'Định mức tiêu chuẩn: 4 m³/người/tháng',
            style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h8,
          if (tiersList.isNotEmpty)
            ...tiersList.map((tier) {
              final m = tier is Map<String, dynamic>
                  ? tier
                  : Map<String, dynamic>.from(tier as Map);
              final name = m['name'] as String? ?? 'Bậc ${m['tier']}';
              final rate = (m['rate'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: context.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    AppSpacing.w8,
                    Text(
                      '${_vnCurrency.format(rate)}/m³',
                      style: context.bodySmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          )
                          .tabularFigures(),
                    ),
                  ],
                ),
              );
            })
          else
            Text(
              'Bậc 1 (Trong định mức): 8.500 đ/m³\nBậc 2 (Vượt cấp 1): 12.000 đ/m³\nBậc 3 (Vượt cấp 2): 18.000 đ/m³',
              style: context.bodySmall?.copyWith(height: 1.5).tabularFigures(),
            ),
        ],
      );
    }

    if (policy.policyType == FeePolicyType.parkingProrata) {
      return Container(
        padding: AppSpacing.p12,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: AppRadius.r8,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Công thức phân bổ theo ngày:',
              style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.h4,
            Text(
              'Số tiền = (Đơn giá tháng × Số ngày sử dụng thực tế) / Tổng số ngày trong tháng',
              style: context.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurface,
              ),
            ),
            AppSpacing.h6,
            Text(
              'Áp dụng tự động khi cư dân đăng ký hoặc hủy đăng ký phương tiện giữa chu kỳ tính phí.',
              style: context.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (policy.policyType == FeePolicyType.latePaymentPenalty) {
      return Container(
        padding: AppSpacing.p12,
        decoration: BoxDecoration(
          color: errorColor.withValues(alpha: 0.08),
          borderRadius: AppRadius.r8,
          border: Border.all(color: errorColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quy định xử lý quá hạn thanh toán:',
              style: context.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: errorColor,
              ),
            ),
            AppSpacing.h6,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: successColor),
                AppSpacing.w6,
                Expanded(
                  child: Text(
                    'Thời gian ân hạn: 3 ngày kể từ ngày đến hạn thanh toán.',
                    style: context.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.h4,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: errorColor),
                AppSpacing.w6,
                Expanded(
                  child: Text(
                    'Lãi phạt quá hạn: 0.05% / ngày (~1.5% / tháng) tính trên dư nợ gốc.',
                    style: context.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
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
