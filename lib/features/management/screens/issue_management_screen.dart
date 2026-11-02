import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/supabase_config.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/issue_model.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../core/widgets/app_storage_image.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../data/providers/material_provider.dart';
import '../widgets/resolve_issue_materials_sheet.dart';
import 'maintenance_materials_screen.dart';

class IssueManagementScreen extends ConsumerStatefulWidget {
  const IssueManagementScreen({super.key});

  @override
  ConsumerState<IssueManagementScreen> createState() => _IssueManagementScreenState();
}

class _IssueManagementScreenState extends ConsumerState<IssueManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all'; // all, pending, in_progress, resolved
  bool _isExporting = false;

  Future<void> _exportExcel(List<IssueModel> issues) async {
    setState(() => _isExporting = true);
    final path = await ExcelExportHelper.exportIssues(issues);
    setState(() => _isExporting = false);

    if (mounted) {
      if (path != null) {
        ExcelExportHelper.shareFile(path, subject: 'Báo cáo sự cố PKA-Home');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xuất báo cáo sự cố thành công!'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Chia sẻ lại',
              textColor: Colors.white,
              onPressed: () => ExcelExportHelper.shareFile(path, subject: 'Báo cáo sự cố PKA-Home'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi xuất file Excel báo cáo sự cố.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  List<IssueModel> _filterIssues(List<IssueModel> issues) {
    return issues.where((issue) {
      if (_selectedStatus != 'all' && issue.status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final code = (issue.apartment?.code ?? '').toLowerCase();
        final desc = issue.description.toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!code.contains(q) && !desc.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateStatus(IssueModel issue, String newStatus, {String? assignedStaffId}) async {
    try {
      await ref.read(managementRepositoryProvider).updateIssueStatus(
        issue.id, 
        newStatus,
        assignedStaffId: assignedStaffId,
      );
      // Dữ liệu sẽ tự động nhảy nhờ Stream Realtime Provider
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật trạng thái thành công'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showAssignStaffDialog(IssueModel issue) async {
    try {
      final usersResponse = await SupabaseConfig.client
          .from('users')
          .select('id, full_name, role')
          .inFilter('role', ['technician', 'admin', 'management']);
      
      final staffList = (usersResponse as List).map((u) {
        final role = u['role'] as String?;
        final roleLabel = role == 'technician'
            ? 'Kỹ thuật viên'
            : (role == 'admin' ? 'Quản trị viên' : 'Ban Quản lý');
        final name = (u['full_name'] as String?) ?? 'Nhân viên';
        return {
          'id': u['id'] as String,
          'name': '$name ($roleLabel)',
        };
      }).toList();

      String? selectedStaffId = issue.assignedStaffId ?? (staffList.isNotEmpty ? staffList.first['id'] : null);

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Tiếp nhận & Phân công'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sự cố: ${issue.description}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 16),
                      const Text('Chọn nhân viên xử lý:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (staffList.isEmpty)
                        const Text('Chưa có nhân viên nào trong hệ thống', style: TextStyle(color: AppTheme.textSecondary))
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedStaffId,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: staffList.map((s) {
                            return DropdownMenuItem<String>(
                              value: s['id'],
                              child: Text(s['name']!),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedStaffId = val;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Xác nhận tiếp nhận'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed == true) {
        _updateStatus(issue, 'in_progress', assignedStaffId: selectedStaffId);
      }
    } catch (e) {
      if (!mounted) return;
      _updateStatus(issue, 'in_progress');
    }
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(allIssuesProvider);

    return RoleGuard(
      permission: AppPermissions.issueManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Xử lý Phản ánh'),
          actions: [
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: 'Kho vật tư kỹ thuật',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MaintenanceMaterialsScreen()),
              ),
            ),
            issuesAsync.when(
              data: (issues) {
                if (issues.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  tooltip: 'Xuất Excel',
                  onPressed: _isExporting ? null : () => _exportExcel(_filterIssues(issues)),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (err, st) => const SizedBox.shrink(),
            ),
          ],
        ),

      body: Column(
        children: [
          // Dải Thẻ KPI SLA Thời Gian Thực
          Consumer(
            builder: (context, ref, _) {
              final slaStatsAsync = ref.watch(issueSlaStatsProvider);
              return slaStatsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stats) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Đúng hạn', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${stats.onTimeCount} sự cố', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sắp trễ (<2h)', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${stats.warningCount} sự cố', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Trễ SLA', style: TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${stats.breachedCount} sự cố', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.error)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo căn hộ hoặc mô tả sự cố...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),

          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả', AppTheme.primary),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Chờ xử lý', AppStatusColors.pending),
                const SizedBox(width: 8),
                _buildFilterChip('in_progress', 'Đang xử lý', AppTheme.primary),
                const SizedBox(width: 8),
                _buildFilterChip('resolved', 'Đã hoàn thành', AppStatusColors.paid),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: AppStateView<List<IssueModel>>(
              asyncValue: issuesAsync,
              skeletonBuilder: (_) => ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  IssueCardSkeleton(),
                  IssueCardSkeleton(),
                  IssueCardSkeleton(),
                ],
              ),
              emptyMessage: 'Không có phản ánh nào.',
              emptyIcon: Icons.report_problem_outlined,
              onRetry: () => ref.invalidate(allIssuesProvider),
              dataBuilder: (issues) {
                final filtered = _filterIssues(issues);

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      ref.invalidate(allIssuesProvider);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.border.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.report_problem_outlined,
                                  size: 48,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Không có phản ánh nào ở trạng thái này.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    ref.invalidate(allIssuesProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final issue = filtered[index];
                      final isHighPriority = issue.priority == 'high';
                      final isMediumPriority = issue.priority == 'medium';
                      final priorityColor = isHighPriority 
                          ? AppStatusColors.priorityHigh 
                          : (isMediumPriority ? AppStatusColors.priorityMedium : AppStatusColors.priorityLow);
                          
                      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                      final isNew = DateTime.now().difference(issue.createdAt).inMinutes < 15;
                      
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16.0),
                        borderRadius: 16,
                        borderColor: isHighPriority ? AppStatusColors.priorityHigh.withValues(alpha: 0.6) : null,
                        onTap: () => context.push(AppRoutes.managementIssueDetail, extra: issue),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          isHighPriority ? Icons.warning : Icons.info_outline, 
                                          color: priorityColor, 
                                          size: 20
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Căn hộ ${issue.apartment?.code ?? 'N/A'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 16,
                                              color: isHighPriority ? AppStatusColors.priorityHigh : AppTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isNew) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppStatusColors.paid,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('MỚI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          )
                                        ]
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateFormat.format(issue.createdAt),
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.handyman_outlined, size: 12, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          issue.categoryDisplayName,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (issue.slaDeadline != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: issue.isSlaBreached
                                            ? AppTheme.error.withValues(alpha: 0.1)
                                            : (issue.isSlaWarning ? Colors.orange.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.08)),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: issue.isSlaBreached
                                              ? AppTheme.error.withValues(alpha: 0.3)
                                              : (issue.isSlaWarning ? Colors.orange.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.2)),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            issue.isSlaBreached
                                                ? Icons.timer_off_outlined
                                                : (issue.isSlaWarning ? Icons.warning_amber_rounded : Icons.access_time),
                                            size: 12,
                                            color: issue.isSlaBreached
                                                ? AppTheme.error
                                                : (issue.isSlaWarning ? Colors.orange.shade800 : Colors.blue.shade800),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            issue.slaRemainingFormatted,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: issue.isSlaBreached
                                                  ? AppTheme.error
                                                  : (issue.isSlaWarning ? Colors.orange.shade800 : Colors.blue.shade800),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(issue.description, style: Theme.of(context).textTheme.bodyMedium),
                              
                              if (issue.reportImages.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Ảnh báo cáo sự cố (Trước khi sửa):',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PhotoViewerScreen(
                                            imageUrls: issue.reportImages,
                                            initialIndex: 0,
                                          ),
                                        ),
                                      );
                                    },
                                    child: AppStorageImage(
                                      imageUrl: issue.reportImages.first,
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],

                              if (issue.resolutionProofImages.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppStatusColors.paid.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppStatusColors.paid.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.verified, size: 16, color: AppStatusColors.paid),
                                          SizedBox(width: 6),
                                          Text(
                                            'Ảnh nghiệm thu hoàn thành (Sau khi sửa):',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppStatusColors.paid),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 80,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: issue.resolutionProofImages.length,
                                          itemBuilder: (ctx, i) {
                                            return Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) => PhotoViewerScreen(
                                                          imageUrls: issue.resolutionProofImages,
                                                          initialIndex: i,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: AppStorageImage(
                                                    imageUrl: issue.resolutionProofImages[i],
                                                    width: 100,
                                                    height: 80,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              if (issue.reporter != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Người gửi: ${issue.reporter!.fullName}', 
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                              
                              if (issue.assignedStaff != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.engineering_outlined, size: 16, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Phụ trách: ${issue.assignedStaff!.fullName}', 
                                        style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              
                              const SizedBox(height: 16),
                              
                              if (issue.status == 'pending')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showAssignStaffDialog(issue),
                                    icon: const Icon(Icons.person_add_outlined, size: 18),
                                    label: const Text('Tiếp nhận & Phân công'),
                                  ),
                                )
                              else if (issue.status == 'in_progress')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => ResolveIssueMaterialsSheet(
                                          issue: issue,
                                          onResolved: () => ref.invalidate(allIssuesProvider),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.success,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('Nghiệm thu & Kê khai vật tư'),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => context.push(AppRoutes.managementIssueDetail, extra: issue),
                                    icon: const Icon(Icons.forum_outlined, size: 16),
                                    label: const Text('Chi tiết & Trao đổi', style: TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }


  Widget _buildFilterChip(String status, String label, Color color) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = status);
        }
      },
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppTheme.surface,
      side: BorderSide(
        color: isSelected ? color : AppTheme.border,
      ),
    );
  }
}
