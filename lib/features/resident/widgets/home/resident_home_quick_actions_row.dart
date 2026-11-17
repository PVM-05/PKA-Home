import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.r16,
        child: Padding(
          padding: AppSpacing.p4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: AppRadius.r16,
                  border: Border.all(
                    color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              AppSpacing.h6,
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
            Icons.qr_code_scanner,
            'Thanh toán',
            onPaymentTap,
            accentColor: AppTheme.sapphire,
          ).animate().fade(duration: 300.ms).slideY(
            begin: 0.2,
            curve: Curves.easeOutQuad,
          ),
        ),
        Expanded(
          child: _buildQuickAction(
            context,
            Icons.build_circle_outlined,
            'Báo sự cố',
            onIssueTap,
            accentColor: AppTheme.amber,
          ).animate().fade(duration: 300.ms, delay: 100.ms).slideY(
            begin: 0.2,
            curve: Curves.easeOutQuad,
          ),
        ),
        Expanded(
          child: _buildQuickAction(
            context,
            Icons.emergency_outlined,
            'Hotline',
            onHandbookHotlineTap,
            accentColor: AppTheme.error,
          ).animate().fade(duration: 300.ms, delay: 200.ms).slideY(
            begin: 0.2,
            curve: Curves.easeOutQuad,
          ),
        ),
        Expanded(
          child: _buildQuickAction(
            context,
            Icons.menu_book_outlined,
            'Cẩm nang',
            onHandbookGuideTap,
            accentColor: AppTheme.emerald,
          ).animate().fade(duration: 300.ms, delay: 300.ms).slideY(
            begin: 0.2,
            curve: Curves.easeOutQuad,
          ),
        ),
      ],
    );
  }
}

