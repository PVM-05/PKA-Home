import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase_config.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/apartment_model.dart';
import '../../../../data/providers/management_provider.dart';
import '../apartment_contract_sheet.dart';
import '../create_apartment_invitation_sheet.dart';

void showApartmentDetailsSheet(
  BuildContext context,
  WidgetRef ref,
  ApartmentModel apt, {
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseConfig.client
            .from('residents_apartments')
            .select('relation_role, users(id, full_name, phone)')
            .eq('apartment_id', apt.id),
        builder: (sheetCtx, snapshot) {
          final theme = Theme.of(sheetCtx);
          final colorScheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;
          final paidColor = AppStatusColors.getPaid(sheetCtx);
          final statusColor = apt.isEmpty ? paidColor : colorScheme.primary;
          final residents = snapshot.data ?? [];
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return Padding(
            padding: AppSpacing.p20,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.domain,
                              color: colorScheme.primary,
                              size: 28,
                            ),
                            AppSpacing.w10,
                            Expanded(
                              child: Text(
                                'Chi tiết Căn hộ ${apt.code}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.w8,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                            alpha: isDark ? 0.2 : 0.14,
                          ),
                          borderRadius: AppRadius.r12,
                        ),
                        child: Text(
                          apt.isEmpty ? 'Còn trống' : 'Đã có chủ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h16,
                  Row(
                    children: [
                      Expanded(
                        child: _DetailInfoTile(
                          label: 'Tòa nhà',
                          value: 'Tòa ${apt.buildingCode}',
                          icon: Icons.apartment,
                        ),
                      ),
                      Expanded(
                        child: _DetailInfoTile(
                          label: 'Số tầng',
                          value: 'Tầng ${apt.floorNumber}',
                          icon: Icons.layers,
                        ),
                      ),
                      Expanded(
                        child: _DetailInfoTile(
                          label: 'Diện tích',
                          value: '${apt.area ?? 0} m²',
                          icon: Icons.square_foot,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    'Cư dân đang sinh sống:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.h8,
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: AppSpacing.p12,
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (residents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Chưa có cư dân nào liên kết với căn hộ này.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ...residents.map((r) {
                      final user = r['users'] as Map<String, dynamic>? ?? {};
                      final role = r['relation_role'] == 'owner'
                          ? 'Chủ hộ'
                          : 'Người thuê / Ở cùng';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.person, size: 18),
                        ),
                        title: Text(
                          user['full_name'] ?? 'Không tên',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'SĐT: ${user['phone'] ?? 'Chưa cập nhật'} • $role',
                        ),
                      );
                    }),
                  AppSpacing.h16,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Mã mời'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (_) => CreateApartmentInvitationSheet(
                                apartmentId: apt.id,
                                apartmentCode: apt.code,
                              ),
                            );
                          },
                        ),
                      ),
                      AppSpacing.w12,
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.assignment_outlined),
                          label: const Text('Hợp đồng & Lưu trú'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (_) => ApartmentContractSheet(
                                apartmentId: apt.id,
                                apartmentCode: apt.code,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h12,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Sửa căn hộ'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            onEdit();
                          },
                        ),
                      ),
                      AppSpacing.w12,
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.textError,
                            foregroundColor: colorScheme.onError,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Xóa căn hộ'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            onDelete();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _DetailInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailInfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            AppSpacing.w4,
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        AppSpacing.h4,
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

Future<void> showApartmentFormDialog(
  BuildContext context,
  WidgetRef ref, {
  ApartmentModel? apartment,
}) async {
  final isEditing = apartment != null;
  final codeController = TextEditingController(text: apartment?.code ?? '');
  final areaController = TextEditingController(
    text: apartment?.area?.toString() ?? '',
  );
  final buildingController = TextEditingController(
    text:
        apartment?.buildingCode ??
        (apartment != null && apartment.code.isNotEmpty
            ? apartment.code[0].toUpperCase()
            : 'A'),
  );
  final floorController = TextEditingController(
    text:
        apartment?.floorNumber.toString() ??
        (apartment != null && apartment.code.length >= 3
            ? (int.tryParse(apartment.code.substring(1, 3)) ?? 1).toString()
            : '1'),
  );
  final formKey = GlobalKey<FormState>();
  bool isSaving = false;

  try {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final colorScheme = Theme.of(dialogCtx).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: Text(isEditing ? 'Cập nhật Căn hộ' : 'Thêm Căn hộ mới'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: 'Mã căn hộ (VD: A0110)',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: validateApartmentCode,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (val) {
                        final trimmed = val.trim().toUpperCase();
                        if (trimmed.length >= 3 && !isEditing) {
                          final b = trimmed[0];
                          final f = int.tryParse(trimmed.substring(1, 3));
                          if (f != null) {
                            setDialogState(() {
                              buildingController.text = b;
                              floorController.text = f.toString();
                            });
                          }
                        }
                      },
                    ),
                    AppSpacing.h12,
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: buildingController,
                            decoration: const InputDecoration(
                              labelText: 'Tòa nhà',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Bắt buộc'
                                : null,
                          ),
                        ),
                        AppSpacing.w12,
                        Expanded(
                          child: TextFormField(
                            controller: floorController,
                            decoration: const InputDecoration(
                              labelText: 'Tầng',
                              prefixIcon: Icon(Icons.layers_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Bắt buộc';
                              }
                              final n = int.tryParse(v.trim());
                              if (n == null || n <= 0) return 'Số hợp lệ';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h12,
                    TextFormField(
                      controller: areaController,
                      decoration: const InputDecoration(
                        labelText: 'Diện tích (m²)',
                        prefixIcon: Icon(Icons.square_foot),
                      ),
                      keyboardType: TextInputType.number,
                      validator: validateArea,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ],
                ),
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
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        final code = codeController.text.trim().toUpperCase();
                        final area = double.parse(areaController.text.trim());
                        final building = buildingController.text
                            .trim()
                            .toUpperCase();
                        final floor =
                            int.tryParse(floorController.text.trim()) ?? 1;

                        final repo = ref.read(managementRepositoryProvider);
                        try {
                          if (isEditing) {
                            await repo.updateApartment(
                              apartment.id,
                              code,
                              area,
                              buildingCode: building,
                              floorNumber: floor,
                            );
                          } else {
                            await repo.createApartment(
                              code,
                              area,
                              buildingCode: building,
                              floorNumber: floor,
                            );
                          }
                          ref.invalidate(apartmentsProvider);
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        } catch (e) {
                          setDialogState(() => isSaving = false);
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
                child: isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    codeController.dispose();
    areaController.dispose();
    buildingController.dispose();
    floorController.dispose();
  }
}

void showDeleteApartmentDialog(
  BuildContext context,
  WidgetRef ref,
  ApartmentModel apt,
) {
  if (!apt.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Không thể xóa căn hộ đã có cư dân sinh sống! Vui lòng hủy liên kết cư dân trước.',
        ),
        backgroundColor: AppTheme.textWarning,
      ),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final colorScheme = Theme.of(dialogCtx).colorScheme;
      final errorColor = AppTheme.getSemanticError(dialogCtx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: errorColor),
            AppSpacing.w8,
            const Expanded(child: Text('Xác nhận xóa')),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa căn hộ ${apt.code}? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textError,
              foregroundColor: colorScheme.onError,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () async {
              try {
                await ref
                    .read(managementRepositoryProvider)
                    .deleteApartment(apt.id);
                ref.invalidate(apartmentsProvider);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
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
            child: const Text('Xóa căn hộ'),
          ),
        ],
      );
    },
  );
}

void showDownloadApartmentTemplateSheet(
  BuildContext context, {
  required VoidCallback onExcel,
  required VoidCallback onCsv,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final colorScheme = theme.colorScheme;
      final successColor = AppTheme.getSemanticSuccess(ctx);

      return SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.p20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chọn định dạng file mẫu',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.h8,
              Text(
                'File mẫu bao gồm các cột chuẩn hóa: Mã Căn Hộ (*), Diện Tích (m2) (*), Trạng Thái Trống.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.h16,
              ListTile(
                minVerticalPadding: 12,
                leading: CircleAvatar(
                  backgroundColor: successColor.withValues(alpha: 0.14),
                  child: Icon(Icons.table_view, color: successColor),
                ),
                title: const Text(
                  'File mẫu Excel (.xlsx)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Phù hợp cho Microsoft Excel hoặc WPS'),
                onTap: () {
                  Navigator.pop(ctx);
                  onExcel();
                },
              ),
              const Divider(),
              ListTile(
                minVerticalPadding: 12,
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                  child: Icon(Icons.description, color: colorScheme.primary),
                ),
                title: const Text(
                  'File mẫu CSV (.csv)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Định dạng văn bản thuần UTF-8, tương thích Google Sheets và hệ thống khác',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onCsv();
                },
              ),
              AppSpacing.h12,
            ],
          ),
        ),
      );
    },
  );
}
