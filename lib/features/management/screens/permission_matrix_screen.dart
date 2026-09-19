import 'package:flutter/material.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_theme.dart';

class PermissionMatrixScreen extends StatelessWidget {
  const PermissionMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Nhóm các quyền theo danh mục
    final Map<String, List<PermissionItem>> grouped = {};
    for (var item in AppPermissions.all) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Ma Trận Phân Quyền'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner giải thích kiến trúc
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.primary, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kiến Trúc Bảo Mật 2 Lớp (Defense-in-Depth)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Hệ thống áp dụng nghiêm ngặt nguyên tắc Đặc quyền tối thiểu (Least Privilege). Quyền hạn được bảo vệ 2 lớp: Tầng CSDL (Supabase RLS) và Tầng Giao diện (Flutter RoleGuard).',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('Chức năng', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Kế toán', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Kỹ thuật', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Cư dân', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: items.map((perm) {
                              final hasAdmin = perm.allows('admin');
                              final hasAccountant = perm.allows('accountant');
                              final hasTechnician = perm.allows('technician');
                              final hasResident = perm.allows('resident');

                              return DataRow(
                                cells: [
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 160),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            perm.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            perm.description,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(_buildStatusIcon(hasAdmin)),
                                  DataCell(_buildStatusIcon(hasAccountant)),
                                  DataCell(_buildStatusIcon(hasTechnician)),
                                  DataCell(_buildStatusIcon(hasResident)),
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
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bảng trên thể hiện quyền hạn mặc định theo vai trò. Quyền hạn có thể được mở rộng tạm thời theo thời gian thực thông qua cơ chế Ủy quyền vai trò (xem mục Quản lý Ủy quyền).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool allowed) {
    if (allowed) {
      return const Icon(
        Icons.check_circle_rounded,
        color: AppTheme.success,
        size: 20,
      );
    }
    return Icon(
      Icons.remove_circle_outline,
      color: Colors.grey.shade400,
      size: 18,
    );
  }
}
