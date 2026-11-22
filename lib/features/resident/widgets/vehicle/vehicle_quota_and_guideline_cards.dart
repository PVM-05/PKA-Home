import 'package:flutter/material.dart';
import 'package:vivona/core/constants/app_constants.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_card.dart';
import 'package:vivona/core/widgets/app_empty_state.dart';

class VehicleQuotaCard extends StatelessWidget {
  final int motorbikeCount;
  final int carCount;

  const VehicleQuotaCard({
    super.key,
    required this.motorbikeCount,
    required this.carCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final motorbikeBadgeColor = motorbikeCount >= 2
        ? AppTheme.getSemanticWarning(context)
        : AppTheme.getSemanticSuccess(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: AppSpacing.p8,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.10,
                  ),
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(
                  Icons.local_parking,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: Text(
                  'Hạn Mức Đăng Ký Căn Hộ',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h16,
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final motorbikeTile = _QuotaMetricTile(
                label: 'Xe máy',
                badgeText: '$motorbikeCount/2 xe',
                badgeColor: motorbikeBadgeColor,
                feeText: AppConstants.kMotorbikeFeeFormatted,
              );
              final carTile = _QuotaMetricTile(
                label: 'Ô tô',
                badgeText: '$carCount xe',
                badgeColor: colorScheme.primary,
                feeText: AppConstants.kCarFeeFormatted,
              );

              if (isNarrow) {
                return Column(
                  children: [
                    motorbikeTile,
                    AppSpacing.h8,
                    carTile,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: motorbikeTile),
                  AppSpacing.w12,
                  Expanded(child: carTile),
                ],
              );
            },
          ),
          AppSpacing.h12,
          Text(
            'Chỉ các phương tiện đã được Ban Quản Lý phê duyệt mới được tính phí gửi xe vào hóa đơn hàng tháng.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaMetricTile extends StatelessWidget {
  final String label;
  final String badgeText;
  final Color badgeColor;
  final String feeText;

  const _QuotaMetricTile({
    required this.label,
    required this.badgeText,
    required this.badgeColor,
    required this.feeText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: AppSpacing.p12,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.w4,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.14),
                    borderRadius: AppRadius.r8,
                  ),
                  child: Text(
                    badgeText,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              feeText,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleGuidelineCard extends StatelessWidget {
  const VehicleGuidelineCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: colorScheme.primary,
                size: 20,
              ),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Quy Chế & Thủ Tục Bãi Xe',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          const _GuidelineItem(
            icon: Icons.schedule,
            title: 'Thời gian duyệt đơn',
            desc: 'Ban Quản Lý xử lý duyệt đơn trong vòng 24 giờ làm việc.',
          ),
          AppSpacing.h8,
          const _GuidelineItem(
            icon: Icons.contactless,
            title: 'Nhận thẻ xe NFC',
            desc:
                'Sau khi được duyệt, cư dân đến quầy Lễ tân để nhận thẻ gửi xe thông minh.',
          ),
          AppSpacing.h8,
          const _GuidelineItem(
            icon: Icons.local_parking,
            title: 'Vị trí đỗ xe',
            desc:
                'Đỗ đúng ô quy định (Ô tô theo mã ô, xe máy tại khu vực vạch kẻ).',
          ),
        ],
      ),
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _GuidelineItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        ),
        AppSpacing.w8,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.h4,
              Text(
                desc,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VehicleEmptyCard extends StatelessWidget {
  const VehicleEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: AppEmptyState(
        icon: Icons.no_crash_outlined,
        title: 'Căn hộ chưa đăng ký phương tiện nào',
        description:
            'Bấm "Đăng ký mới" để thêm xe máy hoặc ô tô vào danh sách căn hộ.',
      ),
    );
  }
}
