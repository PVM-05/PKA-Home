import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
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
    final statusAsync = ref.watch(subscriptionStatusProvider);
    final plansAsync = ref.watch(availablePlansProvider);

    return Scaffold(
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thẻ thông tin gói cước hiện tại
                _buildCurrentSubscriptionCard(status),
                const SizedBox(height: 16),

                // Cảnh báo hạn mức hoặc hết hạn nếu có
                if (status.isExpiringSoon || status.usage.isNearLimit)
                  _buildAlertBanner(status),
                if (status.isExpiringSoon || status.usage.isNearLimit)
                  const SizedBox(height: 16),

                // Thẻ đo lường hạn mức sử dụng (Quota Gauges)
                _buildQuotaUsageCard(status.usage),
                const SizedBox(height: 24),

                // Tiêu đề bảng gói cước
                const Text(
                  'Bảng Gói Dịch Vụ Nâng Cấp',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Lựa chọn gói dịch vụ phù hợp với quy mô tòa nhà và nhu cầu vận hành của bạn',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Danh sách các gói cước mở bán
                plansAsync.when(
                  data: (plans) => _buildPlansList(context, status, plans),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => _buildPlansList(
                    context,
                    status,
                    ref.read(subscriptionRepositoryProvider).getFallbackPlans(),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(
                'Lỗi khi tải thông tin gói cước: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.error),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                onPressed: () => ref.invalidate(subscriptionStatusProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSubscriptionCard(SubscriptionStatusModel status) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final expiresStr = status.expiresAt != null
        ? dateFormat.format(status.expiresAt!)
        : 'Vô thời hạn';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              AppTheme.primary,
              AppTheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18.0),
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
                      const Text(
                        'Gói Dịch Vụ Đang Sử Dụng',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.planName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    status.statusBadgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.event_available,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Hạn dùng: $expiresStr',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.remainingDaysText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(SubscriptionStatusModel status) {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alertMsg,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaUsageCard(SubscriptionUsageMetricsModel usage) {
    Color getProgressColor(double percent) {
      if (percent >= 100.0) return AppTheme.error;
      if (percent >= 80.0) return AppTheme.warning;
      return AppTheme.success;
    }

    final aptProgress = (usage.apartmentUsagePercent / 100).clamp(0.0, 1.0);
    final bldProgress = usage.isUnlimitedBuildings
        ? 0.1
        : (usage.usedBuildings / usage.maxBuildings).clamp(0.0, 1.0);
    final staffProgress = usage.isUnlimitedStaff
        ? 0.1
        : (usage.usedStaff / usage.maxStaff).clamp(0.0, 1.0);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_outline,
                    color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Hạn Mức Sử Dụng Thực Tế',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Chỉ số căn hộ
            _buildQuotaRow(
              icon: Icons.apartment,
              title: 'Căn hộ trong tổ chức',
              ratioText: usage.displayApartmentRatio,
              percentText: '${usage.apartmentUsagePercent}%',
              progress: aptProgress,
              progressColor: getProgressColor(usage.apartmentUsagePercent),
            ),
            const SizedBox(height: 14),

            // 2. Chỉ số tòa nhà
            _buildQuotaRow(
              icon: Icons.domain,
              title: 'Số tòa nhà quản lý',
              ratioText: usage.displayBuildingRatio,
              percentText: usage.isUnlimitedBuildings ? 'Vô hạn' : '',
              progress: bldProgress,
              progressColor: AppTheme.primary,
            ),
            const SizedBox(height: 14),

            // 3. Chỉ số nhân viên
            _buildQuotaRow(
              icon: Icons.badge,
              title: 'Tài khoản nhân viên BQL',
              ratioText: usage.displayStaffRatio,
              percentText: usage.isUnlimitedStaff ? 'Vô hạn' : '',
              progress: staffProgress,
              progressColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaRow({
    required IconData icon,
    required String title,
    required String ratioText,
    required String percentText,
    required double progress,
    required Color progressColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              ratioText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            if (percentText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '($percentText)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: Colors.grey.shade200,
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
    return Column(
      children: plans.map((plan) {
        final isCurrent =
            plan.code.toLowerCase() == currentStatus.planCode.toLowerCase();

        return Card(
          elevation: isCurrent ? 2 : 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isCurrent
                  ? AppTheme.primary
                  : Colors.grey.withValues(alpha: 0.2),
              width: isCurrent ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (plan.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              plan.description!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Gói hiện tại',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.formattedPriceMonthly,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Danh sách quyền lợi
                _buildBenefitItem('Quy mô: ${plan.displayMaxApartments}'),
                _buildBenefitItem('Tối đa: ${plan.displayMaxBuildings}'),
                _buildBenefitItem('Nhân sự: ${plan.displayMaxStaff}'),
                if (plan.code == 'pro' || plan.code == 'enterprise') ...[
                  _buildBenefitItem('Đối soát & Cổng thanh toán VietQR tự động'),
                  _buildBenefitItem('Báo cáo phân tích tài chính & tuổi nợ chuyên sâu'),
                ],
                if (plan.code == 'enterprise') ...[
                  _buildBenefitItem('Hóa đơn điện tử & kết nối phần mềm kế toán'),
                  _buildBenefitItem('Hỗ trợ kỹ thuật ưu tiên 24/7'),
                ],

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isCurrent ? Colors.grey.shade200 : AppTheme.primary,
                      foregroundColor:
                          isCurrent ? AppTheme.textSecondary : Colors.white,
                      elevation: isCurrent ? 0 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isCurrent
                        ? null
                        : () => _showUpgradeDialog(context, plan),
                    child: Text(
                      isCurrent ? 'Đang Sử Dụng' : 'Yêu Cầu Nâng Cấp Gói Này',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textPrimary,
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
      builder: (ctx) => AlertDialog(
        title: Text('Nâng cấp lên ${plan.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mức giá: ${plan.formattedPriceMonthly} (hoặc ${plan.formattedPriceYearly})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
            onPressed: () async {
              final phone = _phoneController.text.trim();
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập số điện thoại liên hệ'),
                    backgroundColor: AppTheme.error,
                  ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']?.toString() ??
                        'Đã gửi yêu cầu thành công'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
  }
}
