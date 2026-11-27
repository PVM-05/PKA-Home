import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/subscription_model.dart';
import '../../../data/models/subscription_plan_model.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../data/repositories/building_repository.dart';

class SubscriptionManagementScreen extends ConsumerStatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  ConsumerState<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends ConsumerState<SubscriptionManagementScreen> {
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusAsync = ref.watch(subscriptionStatusProvider);
    final plansAsync = ref.watch(availablePlansProvider);

    return RoleGuard(
      permission: AppPermissions.subscriptionManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gói Dịch Vụ & Hạn Mức'),
          actions: [
            IconButton(
              tooltip: 'Làm mới',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(subscriptionStatusProvider);
                ref.invalidate(availablePlansProvider);
              },
            ),
          ],
        ),
        body: statusAsync.when(
          data: (status) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(subscriptionStatusProvider);
                    ref.invalidate(availablePlansProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.p16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Thẻ thông tin gói cước hiện tại
                        _buildCurrentSubscriptionCard(context, status),
                        AppSpacing.h16,

                        // Cảnh báo hạn mức hoặc hết hạn nếu có
                        if (status.isExpiringSoon ||
                            status.usage.isNearLimit) ...[
                          _buildAlertBanner(context, status),
                          AppSpacing.h16,
                        ],

                        // Thẻ đo lường hạn mức sử dụng (Quota Gauges)
                        _buildQuotaUsageCard(context, status.usage),
                        AppSpacing.h24,

                        // Tiêu đề bảng gói cước
                        Text(
                          'Bảng Gói Dịch Vụ Nâng Cấp',
                          style: context.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        AppSpacing.h4,
                        Text(
                          'Lựa chọn gói dịch vụ phù hợp với quy mô tòa nhà và nhu cầu vận hành của bạn',
                          style: context.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        AppSpacing.h16,

                        // Danh sách các gói cước mở bán
                        plansAsync.when(
                          data: (plans) =>
                              _buildPlansList(context, status, plans),
                          loading: () => AppSkeletonShimmer.cardList(
                            count: 2,
                            itemHeight: 160,
                          ),
                          error: (_, _) => _buildPlansList(
                            context,
                            status,
                            ref
                                .read(subscriptionRepositoryProvider)
                                .getFallbackPlans(),
                          ),
                        ),
                        AppSpacing.h32,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => ListView(
            padding: AppSpacing.p16,
            children: [
              AppSkeletonShimmer.cardList(count: 3, itemHeight: 150),
            ],
          ),
          error: (err, _) => ListView(
            padding: AppSpacing.p16,
            children: [
              AppErrorCard(
                error: err,
                onRetry: () => ref.invalidate(subscriptionStatusProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSubscriptionCard(
    BuildContext context,
    SubscriptionStatusModel status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expiresStr = status.expiresAt != null
        ? dateFormat.format(status.expiresAt!)
        : 'Vô thời hạn';

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.r16,
        gradient: LinearGradient(
          colors: [colorScheme.primary, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gói Dịch Vụ Đang Sử Dụng',
                    style: context.labelSmall?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AppSpacing.h4,
                  Text(
                    status.planName,
                    style: context.headlineMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: AppRadius.r20,
                  border: Border.all(
                    color: colorScheme.onPrimary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  status.statusBadgeText,
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          Divider(
            color: colorScheme.onPrimary.withValues(alpha: 0.24),
            height: 1,
          ),
          AppSpacing.h12,
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available,
                    color: colorScheme.onPrimary.withValues(alpha: 0.75),
                    size: 16,
                  ),
                  AppSpacing.w6,
                  Text(
                    'Hạn dùng: $expiresStr',
                    style: context.bodySmall?.tabularFigures().copyWith(
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: AppRadius.r6,
                ),
                child: Text(
                  status.remainingDaysText,
                  style: context.labelSmall?.tabularFigures().copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(
    BuildContext context,
    SubscriptionStatusModel status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    String alertMsg = '';
    if (status.usage.isAtLimit) {
      alertMsg =
          'Tòa nhà đã đạt giới hạn tối đa số căn hộ cho phép. Vui lòng nâng cấp gói để tiếp tục thêm căn hộ mới.';
    } else if (status.usage.isNearLimit) {
      alertMsg =
          'Tòa nhà đã sử dụng trên 80% hạn mức căn hộ. Vui lòng cân nhắc nâng cấp gói để tránh gián đoạn vận hành.';
    } else if (status.isExpiringSoon) {
      alertMsg =
          'Gói dịch vụ sắp hết hạn (${status.remainingDaysText}). Vui lòng gia hạn để tiếp tục sử dụng đầy đủ tính năng.';
    }

    return Container(
      padding: AppSpacing.p12,
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.12),
        borderRadius: AppRadius.r12,
        border: Border.all(color: warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: warningColor,
            size: 22,
          ),
          AppSpacing.w10,
          Expanded(
            child: Text(
              alertMsg,
              style: context.bodySmall?.copyWith(
                height: 1.4,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaUsageCard(
    BuildContext context,
    SubscriptionUsageMetricsModel usage,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    Color getProgressColor(double percent) {
      if (percent >= 100.0) return errorColor;
      if (percent >= 80.0) return warningColor;
      return successColor;
    }

    final aptProgress = (usage.apartmentUsagePercent / 100).clamp(0.0, 1.0);
    final bldProgress = usage.isUnlimitedBuildings
        ? 0.1
        : (usage.usedBuildings / usage.maxBuildings).clamp(0.0, 1.0);
    final staffProgress = usage.isUnlimitedStaff
        ? 0.1
        : (usage.usedStaff / usage.maxStaff).clamp(0.0, 1.0);

    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                color: colorScheme.primary,
                size: 20,
              ),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Hạn Mức Sử Dụng Thực Tế',
                  style: context.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h16,

          // 1. Chỉ số căn hộ
          _buildQuotaRow(
            context,
            icon: Icons.apartment,
            title: 'Căn hộ trong tổ chức',
            ratioText: usage.displayApartmentRatio,
            percentText: '${usage.apartmentUsagePercent}%',
            progress: aptProgress,
            progressColor: getProgressColor(usage.apartmentUsagePercent),
          ),
          AppSpacing.h12,

          // 2. Chỉ số tòa nhà
          _buildQuotaRow(
            context,
            icon: Icons.domain,
            title: 'Số tòa nhà quản lý',
            ratioText: usage.displayBuildingRatio,
            percentText: usage.isUnlimitedBuildings ? 'Vô hạn' : '',
            progress: bldProgress,
            progressColor: colorScheme.primary,
          ),
          AppSpacing.h12,

          // 3. Chỉ số nhân viên
          _buildQuotaRow(
            context,
            icon: Icons.badge,
            title: 'Tài khoản nhân viên BQL',
            ratioText: usage.displayStaffRatio,
            percentText: usage.isUnlimitedStaff ? 'Vô hạn' : '',
            progress: staffProgress,
            progressColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String ratioText,
    required String percentText,
    required double progress,
    required Color progressColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
                AppSpacing.w6,
                Text(
                  title,
                  style: context.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ratioText,
                  style: context.bodySmall?.tabularFigures().copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (percentText.isNotEmpty) ...[
                  AppSpacing.w6,
                  Text(
                    '($percentText)',
                    style: context.labelSmall?.tabularFigures().copyWith(
                      fontWeight: FontWeight.w600,
                      color: progressColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        AppSpacing.h6,
        ClipRRect(
          borderRadius: AppRadius.r4,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }

  Widget _buildPlansList(
    BuildContext context,
    SubscriptionStatusModel currentStatus,
    List<SubscriptionPlanModel> plans,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: plans.map((plan) {
        final isCurrent =
            plan.code.toLowerCase() == currentStatus.planCode.toLowerCase();

        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: AppSpacing.p16,
          borderColor: isCurrent
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: context.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (plan.description != null) ...[
                          AppSpacing.h4,
                          Text(
                            plan.description!,
                            style: context.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.r6,
                      ),
                      child: Text(
                        'Gói hiện tại',
                        style: context.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.h12,
              Text(
                plan.formattedPriceMonthly,
                style: context.titleLarge?.tabularFigures().copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              AppSpacing.h12,
              const Divider(height: 1),
              AppSpacing.h12,

              // Danh sách quyền lợi
              _buildBenefitItem(context, 'Quy mô: ${plan.displayMaxApartments}'),
              _buildBenefitItem(context, 'Tối đa: ${plan.displayMaxBuildings}'),
              _buildBenefitItem(context, 'Nhân sự: ${plan.displayMaxStaff}'),
              if (plan.code == 'pro' || plan.code == 'enterprise') ...[
                _buildBenefitItem(
                  context,
                  'Đối soát & Cổng thanh toán VietQR tự động',
                ),
                _buildBenefitItem(
                  context,
                  'Báo cáo phân tích tài chính & tuổi nợ chuyên sâu',
                ),
              ],
              if (plan.code == 'enterprise') ...[
                _buildBenefitItem(
                  context,
                  'Hóa đơn điện tử & kết nối phần mềm kế toán',
                ),
                _buildBenefitItem(context, 'Hỗ trợ kỹ thuật ưu tiên 24/7'),
              ],

              AppSpacing.h16,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrent
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.primary,
                    foregroundColor: isCurrent
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    elevation: isCurrent ? 0 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.r8,
                    ),
                  ),
                  onPressed: isCurrent
                      ? null
                      : () => _showUpgradeDialog(context, plan),
                  child: Text(
                    isCurrent ? 'Đang Sử Dụng' : 'Yêu Cầu Nâng Cấp Gói Này',
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBenefitItem(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: successColor),
          AppSpacing.w8,
          Expanded(
            child: Text(
              text,
              style: context.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, SubscriptionPlanModel plan) {
    final activeBuilding = ref.read(activeBuildingProvider).value;
    final buildingId =
        activeBuilding?.id ?? BuildingRepository.kDefaultCanonicalBuildingId;

    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text('Nâng cấp lên ${plan.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mức giá: ${plan.formattedPriceMonthly} (hoặc ${plan.formattedPriceYearly})',
                  style: ctx.titleSmall?.tabularFigures().copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                AppSpacing.h12,
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại liên hệ (*)',
                    hintText: 'Nhập số điện thoại của BQL',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                AppSpacing.h12,
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú thêm',
                    hintText: 'Nhu cầu mở rộng số căn, thời gian triển khai...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                final phone = _phoneController.text.trim();
                if (phone.isEmpty) {
                  AppSnackBar.showError(
                    context,
                    'Vui lòng nhập số điện thoại liên hệ',
                  );
                  return;
                }

                Navigator.of(ctx).pop();
                final result = await ref
                    .read(subscriptionRepositoryProvider)
                    .requestPlanUpgrade(
                      buildingId: buildingId,
                      targetPlanCode: plan.code,
                      contactPhone: phone,
                      notes: _notesController.text.trim(),
                    );

                if (context.mounted) {
                  AppSnackBar.showSuccess(
                    context,
                    result['message']?.toString() ??
                        'Đã gửi yêu cầu thành công',
                  );
                }
              },
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        );
      },
    );
  }
}
