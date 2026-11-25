import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/accessibility_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/font_size_sheet.dart';
import '../../../core/widgets/pdpl_consent_dialog.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/resident_apartment_provider.dart';
import '../../auth/widgets/mfa_setup_dialog.dart';
import '../widgets/profile/resident_profile_apartments_section.dart';
import '../widgets/profile/resident_profile_dialogs.dart';

class ResidentProfileScreen extends ConsumerWidget {
  const ResidentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);
    final apartmentsAsync = ref.watch(residentApartmentsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    Widget iconBadge(IconData icon, Color tint) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: tint),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản của tôi'),
        automaticallyImplyLeading: false,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Chưa đăng nhập'));

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    AppAvatar(name: user.fullName, size: 92),
                    const SizedBox(height: 14),
                    Text(
                      user.fullName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.phone != null && user.phone!.isNotEmpty
                              ? user.phone!
                              : 'Chưa cập nhật SĐT',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => showEditProfileDialog(context, ref, user),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Chỉnh sửa thông tin'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Căn hộ của bạn
                    ResidentProfileApartmentsSection(
                      apartmentsAsync: apartmentsAsync,
                    ),

                    const SizedBox(height: 20),

                    // Phương tiện căn hộ
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Phương tiện & Gửi xe',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: iconBadge(
                          Icons.two_wheeler_outlined,
                          colorScheme.primary,
                        ),
                        title: const Text(
                          'Phương tiện đã đăng ký',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Quản lý danh sách xe máy, ô tô của căn hộ',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.residentVehicles),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tài chính & Thanh toán
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tài chính & Thanh toán',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: iconBadge(
                          Icons.receipt_long_outlined,
                          colorScheme.primary,
                        ),
                        title: const Text(
                          'Lịch sử thanh toán',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Xem tất cả giao dịch hóa đơn và dịch vụ tiện ích',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push(AppRoutes.residentPaymentHistory),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Quyền riêng tư & Dữ liệu cá nhân
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quyền riêng tư & Dữ liệu cá nhân',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: iconBadge(
                              Icons.shield_outlined,
                              colorScheme.primary,
                            ),
                            title: const Text(
                              'Chính sách quyền riêng tư',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Căn cứ Luật 91/2025/QH15 & NĐ 356/2025/NĐ-CP',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showPrivacyPolicyBottomSheet(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: iconBadge(
                              Icons.fact_check_outlined,
                              colorScheme.primary,
                            ),
                            title: const Text(
                              'Thỏa thuận xử lý dữ liệu',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Xem lại phạm vi chấp thuận và quyền chủ thể dữ liệu',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => const PdplConsentDialog(
                                  isReviewMode: true,
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: iconBadge(
                              Icons.download_for_offline_outlined,
                              colorScheme.primary,
                            ),
                            title: const Text(
                              'Xuất sao kê dữ liệu cá nhân',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Trích xuất bản sao kê hồ sơ, căn hộ, xe, hóa đơn dạng JSON',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                handleExportPersonalData(context, ref, user),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: iconBadge(
                              Icons.person_remove_outlined,
                              warningColor,
                            ),
                            title: Text(
                              'Yêu cầu xóa / đóng băng dữ liệu',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            subtitle: const Text(
                              'Quyền được lãng quên khi chấm dứt hợp đồng thuê / chuyển đi',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showDataAnonymizationDialog(
                              context,
                              ref,
                              user,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Cài đặt & Bảo mật
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cài đặt & Bảo mật',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.lock_outline,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Đổi mật khẩu'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(AppRoutes.changePassword),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.security_outlined,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Xác thực 2 yếu tố'),
                            subtitle: const Text('Bảo vệ tài khoản bằng mã xác thực 6 số'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showMfaManagementDialog(context, ref),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.format_size_outlined,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Cỡ chữ hiển thị'),
                            subtitle: Text(
                              FontSizeOption.fromScale(
                                ref.watch(fontSizeScaleProvider),
                              ).label,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showFontSizeBottomSheet(context, ref),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              ref.watch(themeModeProvider) == ThemeMode.dark
                                  ? Icons.dark_mode
                                  : ref.watch(themeModeProvider) ==
                                        ThemeMode.light
                                  ? Icons.light_mode
                                  : Icons.brightness_auto,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Giao diện'),
                            subtitle: Text(
                              residentThemeModeLabel(
                                ref.watch(themeModeProvider),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                showResidentThemeModeSheet(context, ref),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.logout_outlined,
                              color: errorColor,
                            ),
                            title: Text(
                              'Đăng xuất',
                              style: TextStyle(
                                color: errorColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text('Xác nhận đăng xuất'),
                                  content: const Text(
                                    'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?',
                                  ),
                                  actions: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(64, 48),
                                      ),
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Hủy'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(88, 48),
                                        backgroundColor: AppTheme.textError,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        ref
                                            .read(authProvider.notifier)
                                            .logout();
                                      },
                                      child: const Text('Đăng xuất'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: AppErrorCard(
              error: e,
              onRetry: () => ref.invalidate(authProvider),
            ),
          ),
        ),
      ),
    );
  }
}
