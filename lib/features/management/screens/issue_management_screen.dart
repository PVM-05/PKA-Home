import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/repositories/issue_repository.dart';
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
  ConsumerState<IssueManagementScreen> createState() =>
      _IssueManagementScreenState();
}

class _IssueManagementScreenState extends ConsumerState<IssueManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all'; // all, pending, in_progress, resolved
  bool _onlyAssignedToMe = false;
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
              onPressed: () => ExcelExportHelper.shareFile(
                path,
                subject: 'Báo cáo sự cố PKA-Home',
              ),
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

  List<IssueModel> _filterIssues(List<IssueModel> issues, {String? currentUserId}) {
    return issues.where((issue) {
      if (_selectedStatus != 'all' && issue.status != _selectedStatus) {
        return false;
      }
      if (_onlyAssignedToMe) {
        if (currentUserId == null || issue.assignedStaffId != currentUserId) {
          return false;
        }
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

  void _updateStatus(
    IssueModel issue,
    String newStatus, {
    String? assignedStaffId,
  }) async {
    try {
      await ref
          .read(managementRepositoryProvider)
          .updateIssueStatus(
            issue.id,
            newStatus,
            assignedStaffId: assignedStaffId,
          );
      // Dữ liệu sẽ tự động nhảy nhờ Stream Realtime Provider
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật trạng thái thành công'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formatErrorMessage(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _autoAssignWithAi(IssueModel issue) async {
    try {
      final res = await ref
          .read(issueRepositoryProvider)
          .autoAssignIssue(issue.id, autoAssign: true);
      if (!mounted) return;
      if (res['success'] == true) {
        ref.invalidate(allIssuesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã gán kỹ thuật viên theo phân loại AI và cân bằng tải!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? 'Không thể tự động gán lúc này',
            ),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formatErrorMessage(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showAssignStaffDialog(IssueModel issue) async {
    try {
      final staffList = await ref
          .read(managementRepositoryProvider)
          .fetchAssignableStaff();

      String? selectedStaffId =
          issue.assignedStaffId ??
          (staffList.isNotEmpty ? staffList.first['id'] as String? : null);

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
                      Text(
                        'Sự cố: ${issue.description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chọn nhân viên xử lý:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (staffList.isEmpty)
                        const Text(
                          'Chưa có nhân viên nào trong hệ thống',
                          style: TextStyle(color: AppTheme.textSecondary),
                        )
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
    final currentUser = ref.watch(authProvider).valueOrNull;
    final currentUserId = currentUser?.id;

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
                MaterialPageRoute(
                  builder: (_) => const MaintenanceMaterialsScreen(),
                ),
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
                  onPressed: _isExporting
                      ? null
                      : () => _exportExcel(
                          _filterIssues(issues, currentUserId: currentUserId),
                        ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (err, st) => const SizedBox.shrink(),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Column(
                  children: [
                    // SLA KPI Bar
                    _buildSlaHeader(isDesktop),

                    // Search & Filter Toolbar
                    _buildToolbar(isDesktop),

                    // Main Content
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
                          final filtered = _filterIssues(
                            issues,
                            currentUserId: currentUserId,
                          );

                          if (filtered.isEmpty) {
                            return _buildEmptyListState(context);
                          }

                          if (isDesktop) {
                            return _buildDesktopWorkstation(context, filtered);
                          } else {
                            return _buildMobileCardList(context, filtered);
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlaHeader(bool isDesktop) {
    return Consumer(
      builder: (context, ref, _) {
        final slaStatsAsync = ref.watch(issueSlaStatsProvider);
        return slaStatsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (stats) {
            final cards = [
              _buildSlaKpiBox(
                'Đúng hạn',
                '${stats.onTimeCount} sự cố',
                Colors.green,
                Icons.check_circle_outline,
              ),
              _buildSlaKpiBox(
                'Sắp trễ (<2h)',
                '${stats.warningCount} sự cố',
                Colors.orange,
                Icons.warning_amber_rounded,
              ),
              _buildSlaKpiBox(
                'Trễ SLA',
                '${stats.breachedCount} sự cố',
                AppTheme.error,
                Icons.timer_off_outlined,
              ),
              if (isDesktop)
                _buildSlaKpiBox(
                  'Tỷ lệ tuân thủ',
                  '${stats.complianceRate.toStringAsFixed(1)}%',
                  stats.complianceRate >= 80 ? Colors.green : Colors.orange,
                  Icons.trending_up,
                ),
            ];

            if (isDesktop) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: cards
                      .map(
                        (c) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: c,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: cards
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(width: 124, child: c),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSlaKpiBox(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: context.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              count,
              style: context.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 380,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo căn hộ hoặc mô tả sự cố...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _buildFilterChipsList()),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo căn hộ hoặc mô tả sự cố...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _buildFilterChipsList()),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildFilterChipsList() {
    return [
      _buildFilterChip('all', 'Tất cả', AppTheme.primary),
      const SizedBox(width: 8),
      _buildFilterChip('pending', 'Chờ xử lý', AppStatusColors.pending),
      const SizedBox(width: 8),
      _buildFilterChip('in_progress', 'Đang xử lý', AppTheme.primary),
      const SizedBox(width: 8),
      _buildFilterChip('resolved', 'Đã hoàn thành', AppStatusColors.paid),
      const SizedBox(width: 8),
      FilterChip(
        avatar: Icon(
          Icons.person_pin_outlined,
          size: 16,
          color: _onlyAssignedToMe ? Colors.white : AppTheme.primary,
        ),
        label: Text(
          'Giao cho tôi',
          style: TextStyle(
            color: _onlyAssignedToMe ? Colors.white : AppTheme.textPrimary,
            fontWeight: _onlyAssignedToMe ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: _onlyAssignedToMe,
        selectedColor: AppTheme.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: _onlyAssignedToMe ? AppTheme.primary : AppTheme.border,
        ),
        onSelected: (selected) {
          setState(() {
            _onlyAssignedToMe = selected;
          });
        },
      ),
    ];
  }

  Widget _buildEmptyListState(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(allIssuesProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          const Center(
            child: AppEmptyState(
              icon: Icons.search_off_outlined,
              title: 'Không tìm thấy phản ánh nào',
              description:
                  'Không có phản ánh sự cố nào phù hợp với bộ lọc hoặc từ khóa tìm kiếm hiện tại.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWorkstation(BuildContext context, List<IssueModel> issues) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(allIssuesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1000),
                child: DataTable(
                  columnSpacing: 16,
                  horizontalMargin: 16,
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppTheme.background,
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Căn hộ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Phân loại & Mức độ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Mô tả sự cố',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Cam kết SLA',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Người gửi & Phụ trách',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Trạng thái',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Thao tác',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: issues.map((issue) {
                    final isHighPriority = issue.priority == 'high';
                    final isMediumPriority = issue.priority == 'medium';
                    final priorityColor = isHighPriority
                        ? AppStatusColors.priorityHigh
                        : (isMediumPriority
                            ? AppStatusColors.priorityMedium
                            : AppStatusColors.priorityLow);
                    final isNew =
                        DateTime.now().difference(issue.createdAt).inMinutes < 15;

                    return DataRow(
                      cells: [
                        // Căn hộ
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                issue.apartment?.code ?? 'N/A',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (isNew) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppStatusColors.paid,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'MỚI',
                                    style: context.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              if (issue.isHazardous) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'NGUY HIỂM',
                                    style: context.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Phân loại & Mức độ
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  issue.categoryDisplayName,
                                  style: context.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Semantics(
                                label: 'Mức độ ưu tiên: ${issue.priorityDisplayName}',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    issue.priorityDisplayName,
                                    style: context.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: priorityColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Mô tả sự cố
                        DataCell(
                          SizedBox(
                            width: 240,
                            child: Text(
                              issue.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.bodySmall,
                            ),
                          ),
                        ),

                        // Cam kết SLA
                        DataCell(
                          issue.slaDeadline != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: issue.isSlaBreached
                                        ? AppTheme.error.withValues(alpha: 0.1)
                                        : (issue.isSlaWarning
                                            ? Colors.orange.withValues(alpha: 0.1)
                                            : Colors.blue.withValues(alpha: 0.08)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        issue.isSlaBreached
                                            ? Icons.timer_off_outlined
                                            : (issue.isSlaWarning
                                                ? Icons.warning_amber_rounded
                                                : Icons.access_time),
                                        size: 14,
                                        color: issue.isSlaBreached
                                            ? AppTheme.error
                                            : (issue.isSlaWarning
                                                ? Colors.orange
                                                : Colors.blue),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        issue.slaRemainingFormatted,
                                        style: context.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: issue.isSlaBreached
                                              ? AppTheme.error
                                              : (issue.isSlaWarning
                                                  ? Colors.orange.shade800
                                                  : Colors.blue.shade800),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const Text(
                                  '-',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                        ),

                        // Người gửi & Phụ trách
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue.reporter?.fullName ?? 'Cư dân',
                                style: context.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                issue.assignedStaff != null
                                    ? 'KT: ${issue.assignedStaff!.fullName}'
                                    : 'Chưa phân công',
                                style: context.labelSmall?.copyWith(
                                  color: issue.assignedStaff != null
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Trạng thái
                        DataCell(_buildStatusBadge(issue.status)),

                        // Thao tác
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (issue.status == 'pending') ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                    color: Colors.purple,
                                  ),
                                  tooltip: 'Gán theo AI',
                                  onPressed: () => _autoAssignWithAi(issue),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.person_add_outlined,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  tooltip: 'Phân công',
                                  onPressed: () => _showAssignStaffDialog(issue),
                                ),
                              ] else if (issue.status == 'in_progress') ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: AppTheme.success,
                                  ),
                                  tooltip: 'Nghiệm thu & Vật tư',
                                  onPressed: () => _showResolveModal(context, issue),
                                ),
                              ],
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                tooltip: 'Chi tiết',
                                onPressed: () => context.push(
                                  AppRoutes.managementIssueDetail,
                                  extra: issue,
                                ),
                              ),
                            ],
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
  }

  Widget _buildMobileCardList(BuildContext context, List<IssueModel> issues) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(allIssuesProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: issues.length,
        itemBuilder: (context, index) {
          return _buildMobileIssueCard(context, issues[index]);
        },
      ),
    );
  }

  Widget _buildMobileIssueCard(BuildContext context, IssueModel issue) {
    final isHighPriority = issue.priority == 'high';
    final isMediumPriority = issue.priority == 'medium';
    final priorityColor = isHighPriority
        ? AppStatusColors.priorityHigh
        : (isMediumPriority
            ? AppStatusColors.priorityMedium
            : AppStatusColors.priorityLow);

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isNew = DateTime.now().difference(issue.createdAt).inMinutes < 15;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      borderRadius: 16,
      borderColor: isHighPriority
          ? AppStatusColors.priorityHigh.withValues(alpha: 0.6)
          : null,
      onTap: () => context.push(
        AppRoutes.managementIssueDetail,
        extra: issue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Semantics(
                      label: 'Mức độ ưu tiên: ${issue.priorityDisplayName}',
                      child: Icon(
                        isHighPriority ? Icons.warning : Icons.info_outline,
                        color: priorityColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Căn hộ ${issue.apartment?.code ?? 'N/A'}',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHighPriority
                              ? AppStatusColors.priorityHigh
                              : AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppStatusColors.paid,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MỚI',
                          style: context.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    if (issue.isHazardous) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NGUY HIỂM',
                          style: context.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dateFormat.format(issue.createdAt),
                  style: context.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.handyman_outlined,
                      size: 12,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      issue.categoryDisplayName,
                      style: context.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (issue.hasAiTriage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI: ${issue.aiSuggestedCategoryDisplayName} (${(issue.aiCategoryConfidence * 100).toInt()}%)',
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
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
                        : (issue.isSlaWarning
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: issue.isSlaBreached
                          ? AppTheme.error.withValues(alpha: 0.3)
                          : (issue.isSlaWarning
                              ? Colors.orange.withValues(alpha: 0.3)
                              : Colors.blue.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        issue.isSlaBreached
                            ? Icons.timer_off_outlined
                            : (issue.isSlaWarning
                                ? Icons.warning_amber_rounded
                                : Icons.access_time),
                        size: 12,
                        color: issue.isSlaBreached
                            ? AppTheme.error
                            : (issue.isSlaWarning
                                ? Colors.orange.shade800
                                : Colors.blue.shade800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        issue.slaRemainingFormatted,
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: issue.isSlaBreached
                              ? AppTheme.error
                              : (issue.isSlaWarning
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            issue.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          if (issue.reportImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ảnh báo cáo sự cố (Trước khi sửa):',
              style: context.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
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
                border: Border.all(
                  color: AppStatusColors.paid.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: AppStatusColors.paid,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ảnh nghiệm thu hoàn thành (Sau khi sửa):',
                          style: context.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppStatusColors.paid,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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
              style: context.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],

          if (issue.assignedStaff != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.engineering_outlined,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Phụ trách: ${issue.assignedStaff!.fullName}',
                    style: context.labelSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          if (issue.status == 'pending')
            LayoutBuilder(
              builder: (context, cardConstraints) {
                if (cardConstraints.maxWidth < 340) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _autoAssignWithAi(issue),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple.shade700,
                            side: BorderSide(
                              color: Colors.purple.shade300,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(
                            Icons.auto_awesome,
                            size: 16,
                          ),
                          label: Text(
                            'Gán theo AI',
                            style: context.labelSmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAssignStaffDialog(issue),
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(
                            Icons.person_add_outlined,
                            size: 16,
                          ),
                          label: Text(
                            'Phân công',
                            style: context.labelSmall,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _autoAssignWithAi(issue),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple.shade700,
                          side: BorderSide(
                            color: Colors.purple.shade300,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 16,
                        ),
                        label: Text(
                          'Gán theo AI',
                          style: context.labelSmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAssignStaffDialog(issue),
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          Icons.person_add_outlined,
                          size: 16,
                        ),
                        label: Text(
                          'Phân công',
                          style: context.labelSmall,
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          else if (issue.status == 'in_progress')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showResolveModal(context, issue),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(
                  'Nghiệm thu & Kê khai vật tư',
                  style: context.labelSmall,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push(
                AppRoutes.managementIssueDetail,
                extra: issue,
              ),
              icon: const Icon(
                Icons.forum_outlined,
                size: 16,
              ),
              label: Text(
                'Chi tiết & Trao đổi',
                style: context.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResolveModal(BuildContext context, IssueModel issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResolveIssueMaterialsSheet(
        issue: issue,
        onResolved: () => ref.invalidate(allIssuesProvider),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'resolved':
        color = AppStatusColors.paid;
        text = 'Đã xử lý';
        break;
      case 'in_progress':
        color = AppTheme.primary;
        text = 'Đang xử lý';
        break;
      default:
        color = AppStatusColors.pending;
        text = 'Chờ xử lý';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: context.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
      side: BorderSide(color: isSelected ? color : AppTheme.border),
    );
  }
}
