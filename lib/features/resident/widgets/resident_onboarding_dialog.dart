import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bounceable.dart';
import '../../../data/models/user_model.dart';

/// Hộp thoại chào mừng và hướng dẫn các tính năng cốt lõi cho Cư Dân lần đầu đăng nhập
class ResidentOnboardingDialog {
  static const String _prefPrefix = 'has_seen_resident_onboarding_';

  static Future<void> checkAndShow(BuildContext context, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefPrefix${user.id}';
    final hasSeen = prefs.getBool(key) ?? false;

    if (hasSeen || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo / Icon chào mừng
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Chào mừng ${user.fullName}!',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'CƯ DÂN VIVONA',
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Nền tảng quản lý căn hộ & dịch vụ số giúp bạn tận hưởng cuộc sống chung cư tiện nghi, an tâm và chủ động.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // Danh sách 4 trụ cột tiện ích chính
              _buildFeatureItem(
                context: ctx,
                icon: Icons.receipt_long_rounded,
                iconColor: AppTheme.primary,
                title: 'Hóa đơn & VietQR tức thì',
                subtitle: 'Tra cứu phí minh bạch, thanh toán một chạm chuẩn VietQR & VNPay an toàn.',
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context: ctx,
                icon: Icons.handyman_rounded,
                iconColor: AppTheme.warning,
                title: 'Báo cáo sự cố 24/7',
                subtitle: 'Gửi hình ảnh phản ánh sự cố điện nước và theo dõi kỹ thuật xử lý trực tiếp.',
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context: ctx,
                icon: Icons.speed_rounded,
                iconColor: AppTheme.success,
                title: 'Chỉ số điện nước AI',
                subtitle: 'Chụp ảnh công tơ với nhận diện thông minh, cảnh báo bất thường kịp thời.',
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context: ctx,
                icon: Icons.menu_book_rounded,
                iconColor: AppTheme.secondary,
                title: 'Cẩm nang & Tiện ích tòa nhà',
                subtitle: 'Hotline khẩn cấp, nội quy, đặt lịch phòng sinh hoạt & gửi xe dễ dàng.',
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Bounceable(
              onTap: () async {
                await prefs.setBool(key, true);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  await prefs.setBool(key, true);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                },
                child: const Text(
                  'BẮT ĐẦU TRẢI NGHIỆM',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFeatureItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

