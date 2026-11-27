import 'package:flutter/material.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/role_guard.dart';

class PermissionMatrixScreen extends StatelessWidget {
  const PermissionMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);

    // Nhóm các quyền theo danh mục
    final Map<String, List<PermissionItem>> grouped = {};
    for (final item in AppPermissions.all) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return RoleGuard(
      permission: AppPermissions.permissionMatrix,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bảng Ma Trận Phân Quyền'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: AppSpacing.p16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner giải thích kiến trúc
                  Container(
                    padding: AppSpacing.p16,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.r12,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        AppSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kiến Trúc Bảo Mật Phòng Thủ 2 Lớp',
                                style: context.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              AppSpacing.h4,
                              Text(
                                'Hệ thống áp dụng nghiêm ngặt nguyên tắc Đặc quyền tối thiểu. Quyền hạn được bảo vệ 2 lớp tại Tầng Cơ sở dữ liệu và Tầng Giao diện.',
                                style: context.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h20,

                  // Bảng ma trận
                  ...grouped.entries.map((entry) {
                    final categoryName = entry.key;
                    final items = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryName,
                            style: context.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          AppSpacing.h8,
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: AppRadius.r12,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    colorScheme.surfaceContainerHighest,
                                  ),
                                  columnSpacing: 20,
                                  dataRowMinHeight: 48,
                                  dataRowMaxHeight: 80,
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Chức năng',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Kế toán',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Kỹ thuật',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Cư dân',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: items.map((perm) {
                                    final hasAdmin = perm.allows('admin');
                                    final hasAccountant = perm.allows(
                                      'accountant',
                                    );
                                    final hasTechnician = perm.allows(
                                      'technician',
                                    );
                                    final hasResident = perm.allows('resident');

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 160,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  perm.name,
                                                  style: context.bodySmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  perm.description,
                                                  style: context.labelSmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          _buildStatusIcon(context, hasAdmin),
                                        ),
                                        DataCell(
                                          _buildStatusIcon(
                                            context,
                                            hasAccountant,
                                          ),
                                        ),
                                        DataCell(
                                          _buildStatusIcon(
                                            context,
                                            hasTechnician,
                                          ),
                                        ),
                                        DataCell(
                                          _buildStatusIcon(
                                            context,
                                            hasResident,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Ghi chú nghiệp vụ cố định
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: warningColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r12,
                      border: Border.all(
                        color: warningColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: warningColor,
                          size: 20,
                        ),
                        AppSpacing.w10,
                        Expanded(
                          child: Text(
                            'Bảng trên thể hiện quyền hạn mặc định theo vai trò. Quyền hạn có thể được mở rộng tạm thời theo thời gian thực thông qua cơ chế Ủy quyền vai trò (xem mục Quản lý Ủy quyền).',
                            style: context.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h24,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, bool allowed) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    if (allowed) {
      return Icon(
        Icons.check_circle_rounded,
        color: successColor,
        size: 20,
      );
    }
    return Icon(
      Icons.remove_circle_outline,
      color: colorScheme.outlineVariant,
      size: 18,
    );
  }
}
