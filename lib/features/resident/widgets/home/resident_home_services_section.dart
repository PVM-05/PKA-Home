import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:vivona/core/router/route_names.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_card.dart';

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
          padding: const EdgeInsets.symmetric(
            horizontal: 14.0,
            vertical: 12.0,
          ),
          child: Row(
            children: [
              Container(
                padding: AppSpacing.p8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              AppSpacing.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : AppTheme.textSecondary,
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
        final isNarrow = constraints.maxWidth < 380;
        Widget meterAndVehicleRow;
        if (isNarrow) {
          meterAndVehicleRow = Column(
            children: [
              _buildServiceCard(
                context: context,
                title: 'Số điện nước',
                subtitle: 'Quét OCR & Gửi chỉ số',
                icon: Icons.speed_outlined,
                color: AppTheme.amber,
                onTap: () => context.push(AppRoutes.residentMeterReading),
              ),
              AppSpacing.h8,
              _buildServiceCard(
                context: context,
                title: 'Đăng ký gửi xe',
                subtitle: 'Quản lý phương tiện',
                icon: Icons.directions_car_filled_outlined,
                color: AppTheme.sapphire,
                onTap: () => context.push(AppRoutes.residentVehicles),
              ),
            ],
          );
        } else {
          meterAndVehicleRow = Row(
            children: [
              Expanded(
                child: _buildServiceCard(
                  context: context,
                  title: 'Số điện nước',
                  subtitle: 'Quét OCR & Gửi chỉ số',
                  icon: Icons.speed_outlined,
                  color: AppTheme.amber,
                  onTap: () => context.push(AppRoutes.residentMeterReading),
                ),
              ),
              AppSpacing.w8,
              Expanded(
                child: _buildServiceCard(
                  context: context,
                  title: 'Đăng ký gửi xe',
                  subtitle: 'Quản lý phương tiện',
                  icon: Icons.directions_car_filled_outlined,
                  color: AppTheme.sapphire,
                  onTap: () => context.push(AppRoutes.residentVehicles),
                ),
              ),
            ],
          );
        }

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
            meterAndVehicleRow,
            AppSpacing.h8,
            _buildServiceCard(
              context: context,
              title: 'Đón khách & Bưu kiện',
              subtitle: 'Tạo mã QR đón khách & Mã PIN nhận hàng',
              icon: Icons.mark_as_unread_outlined,
              color: AppTheme.secondary,
              onTap: () => context.push(AppRoutes.residentVisitorParcel),
            ),
            AppSpacing.h8,
            _buildServiceCard(
              context: context,
              title: 'Biểu quyết & Ý kiến',
              subtitle: 'Tham gia biểu quyết điện tử & Đóng góp kiến nghị',
              icon: Icons.how_to_vote_outlined,
              color: AppTheme.emerald,
              onTap: () => context.push(AppRoutes.residentCommunity),
            ),
            AppSpacing.h8,
            _buildServiceCard(
              context: context,
              title: 'Bàn giao & Kiểm kê',
              subtitle: 'Biên bản nhận/trả căn hộ & Ký số kiểm kê tài sản',
              icon: Icons.assignment_turned_in_outlined,
              color: AppTheme.primary,
              onTap: () => context.push(AppRoutes.residentHandovers),
            ),
            AppSpacing.h8,
            _buildServiceCard(
              context: context,
              title: 'Tiện ích chung',
              subtitle: 'BBQ, Hồ bơi, Phòng gym & Quy định sinh hoạt',
              icon: Icons.pool_outlined,
              color: AppTheme.emerald,
              onTap: () => context.push(AppRoutes.residentHandbook, extra: 2),
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
