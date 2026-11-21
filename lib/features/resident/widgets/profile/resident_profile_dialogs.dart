import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/co_residents_provider.dart';
import '../../../../data/services/data_privacy_service.dart';

Future<void> handleExportPersonalData(
  BuildContext context,
  WidgetRef ref,
  UserModel user,
) async {
  showDialog<void>(
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
          backgroundColor: AppTheme.textSuccess,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xuất dữ liệu: ${formatErrorMessage(e)}'),
          backgroundColor: AppTheme.textError,
        ),
      );
    }
  }
}

Future<void> showDataAnonymizationDialog(
  BuildContext context,
  WidgetRef ref,
  UserModel user,
) async {
  String selectedReason = 'Đã chuyển nhượng căn hộ và chuyển nơi cư trú';
  final notesController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          final theme = Theme.of(modalContext);
          final colorScheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;
          final warningColor = AppTheme.getSemanticWarning(modalContext);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.person_remove_outlined, color: warningColor),
                const SizedBox(width: 8),
                const Expanded(
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
                  Text(
                    'Thực thi quyền của chủ thể dữ liệu (Điều 16 & 17 Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15):',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Lý do yêu cầu đóng băng / xóa dữ liệu:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.radiusMd,
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppTheme.radiusMd,
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: notesController,
                    maxLines: 2,
                    labelText: 'Ghi chú thêm (tùy chọn)',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.4,
                            )
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      'Lưu ý: Dữ liệu hóa đơn và chứng từ kế toán được lưu giữ tối thiểu 5 năm theo Luật Kế toán 2015. Ban Quản Lý sẽ xác minh và đóng băng danh tính PII trong vòng 72 giờ làm việc.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(96, 48),
                  backgroundColor: AppTheme.textWarning,
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
                          backgroundColor: AppTheme.textError,
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
  notesController.dispose();
}

void showEditProfileDialog(
  BuildContext context,
  WidgetRef ref,
  UserModel user,
) {
  final nameController = TextEditingController(text: user.fullName);
  final phoneController = TextEditingController(text: user.phone ?? '');
  final formKey = GlobalKey<FormState>();

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Chỉnh sửa thông tin cá nhân'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: nameController,
              labelText: 'Họ và tên *',
              prefixIcon: const Icon(Icons.person_outline),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập họ tên'
                  : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              labelText: 'Số điện thoại',
              prefixIcon: const Icon(Icons.phone_outlined),
              validator: validatePhoneOptional,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 48)),
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
                      backgroundColor: AppTheme.textSuccess,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(formatErrorMessage(e)),
                      backgroundColor: AppTheme.textError,
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

String residentThemeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Sáng';
    case ThemeMode.dark:
      return 'Tối';
    case ThemeMode.system:
      return 'Theo hệ thống';
  }
}

void showResidentThemeModeSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Consumer(
        builder: (sheetContext, ref, _) {
          final theme = Theme.of(sheetContext);
          final colorScheme = theme.colorScheme;
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
            (
              ThemeMode.dark,
              'Tối',
              Icons.dark_mode,
              'Luôn dùng giao diện tối',
            ),
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
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chọn giao diện',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                RadioGroup<ThemeMode>(
                  groupValue: currentMode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(mode);
                      Navigator.pop(ctx);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: entries
                        .map(
                          (entry) => RadioListTile<ThemeMode>(
                            value: entry.$1,
                            title: Row(
                              children: [
                                Icon(entry.$3, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(entry.$2)),
                              ],
                            ),
                            subtitle: Text(entry.$4),
                            activeColor: colorScheme.primary,
                          ),
                        )
                        .toList(),
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
