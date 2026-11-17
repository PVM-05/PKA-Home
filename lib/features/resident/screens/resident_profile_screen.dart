import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/accessibility_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/co_residents_provider.dart';
import '../../../core/widgets/font_size_sheet.dart';
import '../../../core/theme/theme_mode_provider.dart';

import '../../../data/providers/resident_apartment_provider.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pdpl_consent_dialog.dart';
import '../../../data/services/data_privacy_service.dart';

class ResidentProfileScreen extends ConsumerWidget {
  const ResidentProfileScreen({super.key});

  Future<void> _handleExportData(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: AppCard(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Đang trích xuất và ký số dữ liệu...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final privacyService = ref.read(dataPrivacyServiceProvider);
      final exportData = await privacyService.exportUserData(user: user);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await privacyService.saveAndShareExportFile(
        exportData: exportData,
        userName: user.fullName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã tạo tệp sao kê dữ liệu cá nhân theo Luật 91/2025/QH15 thành công!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xuất dữ liệu: ${formatErrorMessage(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRequestAnonymization(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    String selectedReason = 'Đã chuyển nhượng căn hộ và chuyển nơi cư trú';
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_remove_outlined, color: AppTheme.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yêu Cầu Đóng Băng Dữ Liệu',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thực thi quyền của chủ thể dữ liệu (Điều 16 & 17 Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15):',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lý do yêu cầu đóng băng / xóa dữ liệu:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedReason,
                      items: const [
                        DropdownMenuItem(
                          value: 'Đã chuyển nhượng căn hộ và chuyển nơi cư trú',
                          child: Text(
                            'Đã chuyển nhượng căn hộ & rời đi',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Đã chấm dứt hợp đồng thuê căn hộ',
                          child: Text(
                            'Đã kết thúc hợp đồng thuê nhà',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Không còn nhu cầu sử dụng dịch vụ tòa nhà',
                          child: Text(
                            'Không còn nhu cầu sử dụng dịch vụ',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedReason = val);
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú thêm (tùy chọn)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Lưu ý: Dữ liệu hóa đơn và chứng từ kế toán được lưu giữ tối thiểu 5 năm theo Luật Kế toán 2015. Ban Quản Lý sẽ xác minh và đóng băng danh tính PII trong vòng 72 giờ làm việc.',
                        style: TextStyle(color: AppTheme.slate700, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final privacyService = ref.read(dataPrivacyServiceProvider);
                      await privacyService.requestDataAnonymization(
                        userId: user.id,
                        reason: selectedReason,
                        notes: notesController.text.trim(),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã gửi yêu cầu đóng băng dữ liệu tới Ban Quản Lý và DPO (SLA 72 giờ).',
                            ),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Không thể gửi yêu cầu: ${formatErrorMessage(e)}',
                            ),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Gửi yêu cầu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chỉnh sửa thông tin cá nhân'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập họ tên'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: validatePhoneOptional,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                try {
                  final updatedUser = await ref
                      .read(userRepositoryProvider)
                      .updateProfile(
                        userId: user.id,
                        fullName: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                      );
                  ref.read(authProvider.notifier).updateUser(updatedUser);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cập nhật thông tin thành công!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(formatErrorMessage(e)),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);
    final apartmentsAsync = ref.watch(residentApartmentsProvider);

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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.phone != null && user.phone!.isNotEmpty
                          ? user.phone!
                          : 'Chưa cập nhật SĐT',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showEditProfileDialog(context, ref, user),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Chỉnh sửa thông tin'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Căn hộ của bạn
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Căn hộ của bạn',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await context.push<bool>(
                          AppRoutes.residentLinkRequest,
                        );
                        if (result == true) {
                          ref.invalidate(residentApartmentsProvider);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Xin liên kết'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                apartmentsAsync.when(
                  data: (apartments) {
                    if (apartments.isEmpty) {
                      return AppCard(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.apartment_outlined,
                              size: 48,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bạn chưa được liên kết với căn hộ nào.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                final result = await context.push<bool>(
                                  AppRoutes.residentLinkRequest,
                                );
                                if (result == true) {
                                  ref.invalidate(residentApartmentsProvider);
                                }
                              },
                              child: const Text('Xin liên kết ngay'),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: apartments.map((apt) {
                        return _ApartmentCardWithCoResidents(aptData: apt);
                      }).toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    formatErrorMessage(e),
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),

                const SizedBox(height: 20),

                // Phương tiện căn hộ
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Phương tiện & Gửi xe',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.two_wheeler_outlined,
                        color: AppTheme.primary,
                      ),
                    ),
                    title: const Text(
                      'Phương tiện đã đăng ký',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Quản lý danh sách xe máy, ô tô của căn hộ',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push(AppRoutes.residentVehicles);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Tài chính & Thanh toán
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tài chính & Thanh toán',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppTheme.primary,
                      ),
                    ),
                    title: const Text(
                      'Lịch sử thanh toán',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Xem tất cả giao dịch hóa đơn và dịch vụ tiện ích',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push(AppRoutes.residentPaymentHistory);
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // Quyền riêng tư & Dữ liệu (PDPL 2026)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quyền riêng tư & Dữ liệu (PDPL)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppTheme.primary,
                          ),
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
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fact_check_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        title: const Text(
                          'Thỏa thuận xử lý dữ liệu (Consent)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Xem lại phạm vi chấp thuận và quyền chủ thể dữ liệu',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) =>
                                const PdplConsentDialog(isReviewMode: true),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.download_for_offline_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        title: const Text(
                          'Xuất dữ liệu cá nhân (Data Portability)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Trích xuất bản sao kê hồ sơ, căn hộ, xe, hóa đơn dạng JSON',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _handleExportData(context, ref, user),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_remove_outlined,
                            color: AppTheme.warning,
                          ),
                        ),
                        title: const Text(
                          'Yêu cầu xóa / đóng băng dữ liệu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate800,
                          ),
                        ),
                        subtitle: const Text(
                          'Quyền được lãng quên khi chấm dứt hợp đồng thuê / chuyển đi',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _handleRequestAnonymization(context, ref, user),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Settings Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cài đặt & Bảo mật',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.lock_outline,
                          color: AppTheme.primary,
                        ),
                        title: const Text('Đổi mật khẩu'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.push(AppRoutes.changePassword);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.format_size_outlined,
                          color: AppTheme.primary,
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
                              : ref.watch(themeModeProvider) == ThemeMode.light
                              ? Icons.light_mode
                              : Icons.brightness_auto,
                          color: AppTheme.primary,
                        ),
                        title: const Text('Giao diện'),
                        subtitle: Text(
                          _themeModeLabel(ref.watch(themeModeProvider)),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showThemeModeSheet(context, ref),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.logout_outlined,
                          color: AppTheme.error,
                        ),
                        title: const Text(
                          'Đăng xuất',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          showDialog(
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
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Hủy'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ref.read(authProvider.notifier).logout();
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
              ],
            ),
          ),
        ),
      );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            formatErrorMessage(e),
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
    );
  }
}

String _themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Sáng';
    case ThemeMode.dark:
      return 'Tối';
    case ThemeMode.system:
      return 'Theo hệ thống';
  }
}

void _showThemeModeSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final currentMode = ref.watch(themeModeProvider);
          final entries = [
            (
              ThemeMode.system,
              'Theo hệ thống',
              Icons.brightness_auto,
              'Tự động theo cài đặt thiết bị',
            ),
            (
              ThemeMode.light,
              'Sáng',
              Icons.light_mode,
              'Luôn dùng giao diện sáng',
            ),
            (ThemeMode.dark, 'Tối', Icons.dark_mode, 'Luôn dùng giao diện tối'),
          ];

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn giao diện',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...entries.map(
                  (entry) =>
                      // ignore: deprecated_member_use
                      RadioListTile<ThemeMode>(
                        value: entry.$1,
                        // ignore: deprecated_member_use
                        groupValue: currentMode,
                        // ignore: deprecated_member_use
                        onChanged: (mode) {
                          if (mode != null) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(mode);
                            Navigator.pop(ctx);
                          }
                        },
                        title: Row(
                          children: [
                            Icon(entry.$3, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(entry.$2)),
                          ],
                        ),
                        subtitle: Text(
                          entry.$4,
                        ),
                        activeColor: AppTheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

class _ApartmentCardWithCoResidents extends ConsumerWidget {
  final Map<String, dynamic> aptData;

  const _ApartmentCardWithCoResidents({required this.aptData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartment = aptData['apartments'];
    final apartmentId =
        aptData['apartment_id'] as String? ?? apartment?['id'] as String? ?? '';
    final role = aptData['relation_role'] == 'owner' ? 'Chủ hộ' : 'Người thuê';
    final coResidentsAsync = ref.watch(coResidentsProvider(apartmentId));

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apartment_outlined,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Căn hộ ${apartment?['code'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Diện tích: ${apartment?['area'] ?? 'N/A'} m²',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: const [
              Icon(
                Icons.people_outline,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Thành viên cùng căn hộ:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          coResidentsAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Chưa có thành viên khác.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              }

              return Column(
                children: members.map((m) {
                  final userData = m['users'] as Map<String, dynamic>?;
                  final memberName = userData?['full_name'] ?? 'Cư dân';
                  final memberPhone = userData?['phone'] ?? '';
                  final memberRole = m['relation_role'] == 'owner'
                      ? 'Chủ hộ'
                      : 'Người thuê';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                memberName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (memberPhone.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  memberPhone,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white12
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              memberRole,
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => const Text(
              'Không thể tải danh sách thành viên',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
