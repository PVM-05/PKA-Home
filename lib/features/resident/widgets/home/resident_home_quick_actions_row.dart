import 'package:flutter/material.dart';
import '../../../../core/motion/app_spring_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bounceable.dart';

class ResidentHomeQuickActionsRow extends StatelessWidget {
  final VoidCallback onPaymentTap;
  final VoidCallback onIssueTap;
  final VoidCallback onHandbookHotlineTap;
  final VoidCallback onHandbookGuideTap;

  const ResidentHomeQuickActionsRow({
    super.key,
    required this.onPaymentTap,
    required this.onIssueTap,
    required this.onHandbookHotlineTap,
    required this.onHandbookGuideTap,
  });

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? AppTheme.primary;
    final textTheme = Theme.of(context).textTheme;

    return Bounceable(
      onTap: onTap,
      scaleFactor: 0.92,
      child: Padding(
        padding: AppSpacing.p4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: AppRadius.r16,
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.3 : 0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            AppSpacing.h8,
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildQuickAction(
            context,
            Icons.receipt_long_rounded,
            'Hóa đơn',
            onPaymentTap,
            accentColor: AppTheme.sapphire,
          ).animateStaggeredItem(index: 0),
        ),
        Expanded(
          child: _buildQuickAction(
            context,
            Icons.build_circle_outlined,
            'Báo sự cố',
            onIssueTap,
            accentColor: AppTheme.amber,
          ).animateStaggeredItem(index: 1),
        ),
        Expanded(
          child: _buildQuickAction(
            context,
            Icons.emergency_outlined,
            'Hotline',
            onHandbookHotlineTap,
            accentColor: AppTheme.error,
          ).animateStaggeredItem(index: 2),
        ),
        Expanded(
          child: _buildQuickAction(
            context,
            Icons.menu_book_outlined,
            'Cẩm nang',
            onHandbookGuideTap,
            accentColor: AppTheme.success,
          ).animateStaggeredItem(index: 3),
        ),
      ],
    );
  }
}
