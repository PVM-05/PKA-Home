import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:vivona/core/router/route_names.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_card.dart';

/// Danh mục dịch vụ & tiện ích dành cho cư dân:
/// - Bố cục lưới 2 cột gọn gàng (2-column Grid) tiết kiệm ~40% chiều cao cuộn màn hình.
/// - Nhãn chuẩn hóa "Phương tiện & Gửi xe" theo sơ đồ thông tin (IA) 2026.
/// - Cảm ứng mượt mà và chuyển hướng nhanh.
class ResidentHomeServicesSection extends StatelessWidget {
  const ResidentHomeServicesSection({super.key});

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppRadius.r16,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              AppSpacing.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          _buildServiceCard(
            context: context,
            title: 'Số điện nước',
            subtitle: 'Quét OCR & Gửi chỉ số',
            icon: Icons.speed_outlined,
            color: AppTheme.amber,
            onTap: () => context.push(AppRoutes.residentMeterReading),
          ),
          _buildServiceCard(
            context: context,
            title: 'Phương tiện & Gửi xe',
            subtitle: 'Quản lý phương tiện',
            icon: Icons.directions_car_filled_outlined,
            color: AppTheme.sapphire,
            onTap: () => context.push(AppRoutes.residentVehicles),
          ),
          _buildServiceCard(
            context: context,
            title: 'Đón khách & Bưu kiện',
            subtitle: 'Mã QR & PIN nhận hàng',
            icon: Icons.mark_as_unread_outlined,
            color: AppTheme.secondary,
            onTap: () => context.push(AppRoutes.residentVisitorParcel),
          ),
          _buildServiceCard(
            context: context,
            title: 'Tiện ích chung',
            subtitle: 'BBQ, Hồ bơi, Gym',
            icon: Icons.pool_outlined,
            color: AppTheme.emerald,
            onTap: () => context.push(AppRoutes.residentAmenities),
          ),
          _buildServiceCard(
            context: context,
            title: 'Biểu quyết & Ý kiến',
            subtitle: 'Biểu quyết & Kiến nghị',
            icon: Icons.how_to_vote_outlined,
            color: AppTheme.emerald,
            onTap: () => context.push(AppRoutes.residentCommunity),
          ),
          _buildServiceCard(
            context: context,
            title: 'Bàn giao & Kiểm kê',
            subtitle: 'Biên bản & Ký kiểm kê',
            icon: Icons.assignment_turned_in_outlined,
            color: AppTheme.primary,
            onTap: () => context.push(AppRoutes.residentHandovers),
          ),
        ];

        final isSingleCol = constraints.maxWidth < 340;
        final colCount = isSingleCol ? 1 : 2;
        final spacing = 8.0;
        final itemWidth = (constraints.maxWidth - (colCount - 1) * spacing) / colCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dịch vụ & Tiện ích',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.h8,
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: items
                  .map(
                    (card) => SizedBox(
                      width: itemWidth,
                      child: card,
                    ),
                  )
                  .toList(),
            ),
          ],
        )
            .animate()
            .fade(duration: 350.ms, delay: 150.ms)
            .slideY(begin: 0.1, curve: Curves.easeOutQuad);
      },
    );
  }
}
