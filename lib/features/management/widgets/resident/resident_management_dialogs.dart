import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/action_runner.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../data/models/apartment_model.dart';
import '../../../../data/models/resident_model.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/management_provider.dart';

Color getResidentRoleColor(BuildContext context, String role) {
  final colorScheme = Theme.of(context).colorScheme;
  switch (role) {
    case 'admin':
    case 'management':
      return colorScheme.primary;
    case 'accountant':
      return AppTheme.getSemanticSecondary(context);
    case 'technician':
      return AppTheme.getSemanticWarning(context);
    case 'resident':
      return AppTheme.getSemanticSuccess(context);
    default:
      return colorScheme.onSurfaceVariant;
  }
}

void showCreateResidentUserDialog(
  BuildContext context,
  List<ApartmentModel> apartments,
) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreateUserDialog(apartments: apartments),
  );
}

void showChangeResidentRoleDialog(
  BuildContext context,
  WidgetRef ref,
  ResidentModel resident,
) {
  final currentUserId = ref.read(authProvider).value?.id;
  final isSelf = resident.id == currentUserId;

  String selectedRole =
      resident.role == 'management' ? 'admin' : resident.role;
  const roles = [
    {
      'value': 'admin',
      'label': 'Quản trị viên',
      'desc': 'Toàn quyền quản trị và phân quyền hệ thống',
    },
    {
      'value': 'accountant',
      'label': 'Kế toán',
      'desc': 'Quản lý tài chính, lập hóa đơn & cư dân',
    },
    {
      'value': 'technician',
      'label': 'Kỹ thuật viên',
      'desc': 'Tiếp nhận & xử lý phản ánh sự cố',
    },
    {
      'value': 'resident',
      'label': 'Cư dân',
      'desc': 'Cư dân sinh hoạt tại căn hộ chung cư',
    },
  ];

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) {
        final theme = Theme.of(dialogCtx);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final highPriorityColor = AppStatusColors.getPriorityHigh(dialogCtx);
        final errorColor = AppTheme.getSemanticError(dialogCtx);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Text(
            'Phân quyền cho ${resident.fullName}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelf)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: highPriorityColor.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      ),
                      borderRadius: AppRadius.r8,
                      border: Border.all(
                        color: highPriorityColor.withValues(
                          alpha: isDark ? 0.45 : 0.30,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: highPriorityColor,
                          size: 20,
                        ),
                        AppSpacing.w8,
                        Expanded(
                          child: Text(
                            'Đây là tài khoản của bạn. Không thể tự hạ quyền Quản trị viên để tránh mất quyền quản trị.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: highPriorityColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...roles.map((r) {
                  final isSelected = selectedRole == r['value'];
                  final roleColor = getResidentRoleColor(
                    dialogCtx,
                    r['value']!,
                  );
                  final isDisabled = isSelf && r['value'] != 'admin';

                  return Opacity(
                    opacity: isDisabled ? 0.45 : 1.0,
                    child: InkWell(
                      onTap: isDisabled
                          ? () {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Không thể tự hạ quyền Quản trị viên của chính mình.',
                                  ),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: AppTheme.textError,
                                ),
                              );
                            }
                          : () => setDialogState(
                              () => selectedRole = r['value']!,
                            ),
                      borderRadius: AppRadius.r12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? roleColor.withValues(
                                  alpha: isDark ? 0.18 : 0.10,
                                )
                              : Colors.transparent,
                          borderRadius: AppRadius.r12,
                          border: Border.all(
                            color: isSelected
                                ? roleColor
                                : colorScheme.outlineVariant,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? roleColor
                                  : colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            AppSpacing.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        r['label']!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? roleColor
                                                  : colorScheme.onSurface,
                                            ),
                                      ),
                                      if (isDisabled) ...[
                                        AppSpacing.w6,
                                        Text(
                                          '(Bị khóa)',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: errorColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  AppSpacing.h4,
                                  Text(
                                    r['desc']!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () async {
                if (isSelf && selectedRole != 'admin') {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Không thể tự hạ quyền Quản trị viên của chính mình.',
                      ),
                      backgroundColor: AppTheme.textError,
                    ),
                  );
                  return;
                }

                if (selectedRole != resident.role) {
                  final oldRoleLabel = roles.firstWhere(
                    (r) => r['value'] == resident.role,
                    orElse: () => {'label': resident.role},
                  )['label'];
                  final newRoleLabel = roles.firstWhere(
                    (r) => r['value'] == selectedRole,
                    orElse: () => {'label': selectedRole},
                  )['label'];
                  final confirm = await showDialog<bool>(
                    context: dialogCtx,
                    builder: (confirmCtx) {
                      final cs = Theme.of(confirmCtx).colorScheme;
                      final warn = AppTheme.getSemanticWarning(confirmCtx);
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.r16,
                        ),
                        title: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: warn),
                            AppSpacing.w8,
                            Expanded(
                              child: Text(
                                'Xác nhận đổi vai trò',
                                style: Theme.of(confirmCtx).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          'Bạn có chắc chắn muốn thay đổi vai trò của "${resident.fullName}" từ "$oldRoleLabel" sang "$newRoleLabel"? Thao tác này sẽ cập nhật ngay quyền truy cập và chức năng của tài khoản.',
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => Navigator.pop(confirmCtx, false),
                            child: const Text('Hủy'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: cs.onPrimary,
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => Navigator.pop(confirmCtx, true),
                            child: const Text('Xác nhận'),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm != true) return;
                }

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                try {
                  await ref
                      .read(managementRepositoryProvider)
                      .updateUserRole(resident.id, selectedRole);
                  ref.invalidate(residentsProvider);
                  if (resident.id == ref.read(authProvider).value?.id) {
                    ref.invalidate(authProvider);
                  }
                  if (context.mounted) {
                    final selectedLabel = roles.firstWhere(
                      (r) => r['value'] == selectedRole,
                    )['label'];
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã cập nhật vai trò của ${resident.fullName} thành $selectedLabel!',
                        ),
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
              },
              child: const Text('Lưu thay đổi'),
            ),
          ],
        );
      },
    ),
  );
}

void showAssignResidentApartmentDialog(
  BuildContext context,
  WidgetRef ref,
  ResidentModel resident,
  List<ApartmentModel> apartments,
) {
  showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final colorScheme = Theme.of(dialogCtx).colorScheme;
      final successColor = AppTheme.getSemanticSuccess(dialogCtx);
      final errorColor = AppTheme.getSemanticError(dialogCtx);

      return AlertDialog(
        title: Text(
          'Gán căn hộ cho ${resident.fullName}',
          style: Theme.of(dialogCtx).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: apartments.length,
            itemBuilder: (ctx, index) {
              final apt = apartments[index];
              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.domain,
                    color: apt.isEmpty
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Căn hộ ${apt.code}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    apt.isEmpty ? 'Đang trống' : 'Đã có người ở',
                    style: TextStyle(
                      color: apt.isEmpty ? successColor : errorColor,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(dialogCtx).pop();
                    try {
                      await ref
                          .read(managementRepositoryProvider)
                          .assignResidentToApartment(resident.id, apt.id);
                      ref.invalidate(residentsProvider);
                      ref.invalidate(apartmentsProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gán căn hộ thành công!'),
                          backgroundColor: AppTheme.textSuccess,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(formatErrorMessage(e)),
                          backgroundColor: AppTheme.textError,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Hủy'),
          ),
        ],
      );
    },
  );
}

class ResidentFilterSelection {
  final String role;
  final String status;
  final String apartment;

  const ResidentFilterSelection({
    required this.role,
    required this.status,
    required this.apartment,
  });
}

Future<ResidentFilterSelection?> showResidentFilterBottomSheet(
  BuildContext context, {
  required String currentRole,
  required String currentStatus,
  required String currentApartment,
}) {
  String draftRole = currentRole;
  String draftStatus = currentStatus;
  String draftApartment = currentApartment;

  return showModalBottomSheet<ResidentFilterSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        Widget buildChip(String label, bool isSelected, VoidCallback onTap) {
          return ChoiceChip(
            materialTapTargetSize: MaterialTapTargetSize.padded,
            label: Text(label),
            selected: isSelected,
            labelStyle: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
            selectedColor: AppTheme.primary,
            backgroundColor: colorScheme.surfaceContainerLow,
            side: BorderSide(
              color: isSelected ? AppTheme.primary : colorScheme.outlineVariant,
            ),
            onSelected: (_) => onTap(),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Bộ lọc người dùng',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                const Divider(height: 1),
                AppSpacing.h12,
                Text(
                  'Vai trò',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.h8,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    buildChip(
                      'Tất cả',
                      draftRole == 'all',
                      () => setSheetState(() => draftRole = 'all'),
                    ),
                    buildChip(
                      'Cư dân',
                      draftRole == 'resident',
                      () => setSheetState(() => draftRole = 'resident'),
                    ),
                    buildChip(
                      'Quản trị viên',
                      draftRole == 'admin',
                      () => setSheetState(() => draftRole = 'admin'),
                    ),
                    buildChip(
                      'Kế toán',
                      draftRole == 'accountant',
                      () => setSheetState(() => draftRole = 'accountant'),
                    ),
                    buildChip(
                      'Kỹ thuật viên',
                      draftRole == 'technician',
                      () => setSheetState(() => draftRole = 'technician'),
                    ),
                  ],
                ),
                AppSpacing.h16,
                Text(
                  'Trạng thái',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.h8,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    buildChip(
                      'Tất cả',
                      draftStatus == 'all',
                      () => setSheetState(() => draftStatus = 'all'),
                    ),
                    buildChip(
                      'Đang hoạt động',
                      draftStatus == 'active',
                      () => setSheetState(() => draftStatus = 'active'),
                    ),
                    buildChip(
                      'Đã khóa',
                      draftStatus == 'locked',
                      () => setSheetState(() => draftStatus = 'locked'),
                    ),
                    buildChip(
                      'Đã vô hiệu hóa',
                      draftStatus == 'deactivated',
                      () => setSheetState(() => draftStatus = 'deactivated'),
                    ),
                  ],
                ),
                AppSpacing.h16,
                Text(
                  'Căn hộ',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.h8,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    buildChip(
                      'Tất cả',
                      draftApartment == 'all',
                      () => setSheetState(() => draftApartment = 'all'),
                    ),
                    buildChip(
                      'Đã gán căn hộ',
                      draftApartment == 'assigned',
                      () => setSheetState(() => draftApartment = 'assigned'),
                    ),
                    buildChip(
                      'Chưa gán căn hộ',
                      draftApartment == 'unassigned',
                      () => setSheetState(() => draftApartment = 'unassigned'),
                    ),
                  ],
                ),
                AppSpacing.h24,
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () {
                          setSheetState(() {
                            draftRole = 'all';
                            draftStatus = 'all';
                            draftApartment = 'all';
                          });
                        },
                        child: const Text('Đặt lại'),
                      ),
                    ),
                    AppSpacing.w12,
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.r12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(sheetCtx).pop(
                            ResidentFilterSelection(
                              role: draftRole,
                              status: draftStatus,
                              apartment: draftApartment,
                            ),
                          );
                        },
                        child: const Text(
                          'Áp dụng',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  final List<ApartmentModel> apartments;

  const _CreateUserDialog({required this.apartments});

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _role = 'resident';
  String? _apartmentId;
  String _relationRole = 'owner';
  bool _obscurePass = true;
  bool _obscureAdminPass = true;

  @override
  void initState() {
    super.initState();
    _passCtrl.text = _generateSecurePassword();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _adminPassCtrl.dispose();
    super.dispose();
  }

  String _generateSecurePassword() {
    final rand = Random.secure();
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghjkmnpqrstuvwxyz';
    const digits = '23456789';
    const specials = '@#%&*!';
    final p1 = List.generate(
      3,
      (_) => upper[rand.nextInt(upper.length)],
    ).join();
    final p2 = List.generate(
      4,
      (_) => lower[rand.nextInt(lower.length)],
    ).join();
    final p3 = List.generate(
      2,
      (_) => digits[rand.nextInt(digits.length)],
    ).join();
    final p4 = specials[rand.nextInt(specials.length)];
    final list = (p1 + p2 + p3 + p4).split('')..shuffle(rand);
    return list.join();
  }

  bool get _isPrivilegedRole =>
      _role == 'admin' || _role == 'accountant' || _role == 'technician';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = AppTheme.getSemanticWarning(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
      title: Row(
        children: [
          Icon(Icons.person_add_alt_1, color: colorScheme.primary),
          AppSpacing.w8,
          Expanded(
            child: Text(
              'Tạo tài khoản mới',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập họ tên'
                    : null,
              ),
              AppSpacing.h12,
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email đăng nhập *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập email';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              AppSpacing.h12,
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              AppSpacing.h12,
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu khởi tạo *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  helperText:
                      'Mật khẩu tạm thời. Cư dân có thể đổi sau khi đăng nhập.',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Tạo mật khẩu ngẫu nhiên mới',
                        onPressed: () => setState(
                          () => _passCtrl.text = _generateSecurePassword(),
                        ),
                      ),
                    ],
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Mật khẩu ít nhất 6 ký tự'
                    : null,
              ),
              AppSpacing.h12,
              DropdownButtonFormField<String>(
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Vai trò tài khoản',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'resident', child: Text('Cư dân')),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Quản trị viên'),
                  ),
                  DropdownMenuItem(value: 'accountant', child: Text('Kế toán')),
                  DropdownMenuItem(
                    value: 'technician',
                    child: Text('Kỹ thuật viên'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _role = val;
                      if (_role != 'resident') _apartmentId = null;
                    });
                  }
                },
              ),
              if (_role == 'resident') ...[
                AppSpacing.h12,
                DropdownButtonFormField<String?>(
                  initialValue: _apartmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Căn hộ ban đầu (tùy chọn)',
                    prefixIcon: Icon(Icons.domain),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Không gán căn hộ ngay'),
                    ),
                    ...widget.apartments.map(
                      (apt) => DropdownMenuItem<String?>(
                        value: apt.id,
                        child: Text(
                          'Căn hộ ${apt.code} (${apt.isEmpty ? 'Trống' : 'Đang ở'})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _apartmentId = val),
                ),
                if (_apartmentId != null) ...[
                  AppSpacing.h12,
                  DropdownButtonFormField<String>(
                    initialValue: _relationRole,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Quan hệ với căn hộ',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'owner', child: Text('Chủ hộ')),
                      DropdownMenuItem(
                        value: 'member',
                        child: Text('Thành viên'),
                      ),
                      DropdownMenuItem(
                        value: 'tenant',
                        child: Text('Người thuê'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _relationRole = val);
                    },
                  ),
                ],
              ],
              if (_isPrivilegedRole) ...[
                AppSpacing.h16,
                Container(
                  padding: AppSpacing.p12,
                  decoration: BoxDecoration(
                    color: warningColor.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: AppRadius.r12,
                    border: Border.all(
                      color: warningColor.withValues(
                        alpha: isDark ? 0.45 : 0.30,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: warningColor, size: 18),
                          AppSpacing.w8,
                          Expanded(
                            child: Text(
                              'Xác thực quyền quản trị',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: warningColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h6,
                      Text(
                        'Tài khoản này có đặc quyền quản trị hệ thống. Vui lòng nhập mật khẩu xác nhận của Quản trị viên hiện tại.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      AppSpacing.h12,
                      TextFormField(
                        controller: _adminPassCtrl,
                        obscureText: _obscureAdminPass,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu quản trị viên xác thực *',
                          prefixIcon: const Icon(Icons.admin_panel_settings),
                          suffixIcon: IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              _obscureAdminPass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () => setState(
                              () => _obscureAdminPass = !_obscureAdminPass,
                            ),
                          ),
                          isDense: true,
                        ),
                        validator: (v) {
                          if (_isPrivilegedRole &&
                              (v == null || v.trim().isEmpty)) {
                            return 'Bắt buộc xác thực mật khẩu quản trị';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.upload_file),
          tooltip: 'Nhập Excel',
          onPressed: () => context.push(AppRoutes.managementBatchImport),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size(0, 48),
          ),
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final fullName = _nameCtrl.text.trim();
            final email = _emailCtrl.text.trim();
            final password = _passCtrl.text;
            final phone = _phoneCtrl.text.trim().isNotEmpty
                ? _phoneCtrl.text.trim()
                : null;
            final role = _role;
            final apartmentId = _apartmentId;
            final relationRole = _relationRole;

            Navigator.pop(context);

            await runAction(
              context,
              () async {
                await ref
                    .read(managementRepositoryProvider)
                    .createUser(
                      email: email,
                      password: password,
                      fullName: fullName,
                      phone: phone,
                      role: role,
                      apartmentId: apartmentId,
                      relationRole: relationRole,
                    );
                ref.invalidate(residentsProvider);
                ref.invalidate(apartmentsProvider);
                return 'Đã tạo tài khoản cho $fullName thành công!';
              },
              actionName: 'Tạo tài khoản người dùng',
            );
          },
          child: const Text('Tạo tài khoản'),
        ),
      ],
    );
  }
}
