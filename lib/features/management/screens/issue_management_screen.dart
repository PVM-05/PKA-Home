import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/repositories/issue_repository.dart';
import '../widgets/issue/management_issue_desktop_table.dart';
import '../widgets/issue/management_issue_mobile_card.dart';
import '../widgets/issue/management_issue_sla_header.dart';
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
  String _selectedStatus = 'all';
  bool _onlyAssignedToMe = false;
  bool _isExporting = false;

  Future<void> _exportExcel(List<IssueModel> issues) async {
    setState(() => _isExporting = true);
    final path = await ExcelExportHelper.exportIssues(issues);
    setState(() => _isExporting = false);

    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    if (path != null) {
      ExcelExportHelper.shareFile(path, subject: 'Báo cáo sự cố Vivona');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã xuất báo cáo sự cố thành công!'),
          backgroundColor: AppTheme.textSuccess,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Chia sẻ lại',
            textColor: colorScheme.onPrimary,
            onPressed: () => ExcelExportHelper.shareFile(
              path,
              subject: 'Báo cáo sự cố Vivona',
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi khi xuất file Excel báo cáo sự cố.'),
          backgroundColor: AppTheme.textError,
        ),
      );
    }
  }

  List<IssueModel> _filterIssues(
    List<IssueModel> issues, {
    String? currentUserId,
  }) {
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

  Future<void> _updateStatus(
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật trạng thái thành công'),
          backgroundColor: AppTheme.textSuccess,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formatErrorMessage(e)),
          backgroundColor: AppTheme.textError,
        ),
      );
    }
  }

  Future<void> _autoAssignWithAi(IssueModel issue) async {
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
            backgroundColor: AppTheme.textSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? 'Không thể tự động gán lúc này',
            ),
            backgroundColor: AppTheme.textWarning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formatErrorMessage(e)),
          backgroundColor: AppTheme.textError,
        ),
      );
    }
  }

  Future<void> _showAssignStaffDialog(IssueModel issue) async {
    try {
      final staffList = await ref
          .read(managementRepositoryProvider)
          .fetchAssignableStaff();

      final validStaffIds = staffList.map((s) => s['id']).toSet();
      String? selectedStaffId = validStaffIds.contains(issue.assignedStaffId)
          ? issue.assignedStaffId
          : (staffList.isNotEmpty ? staffList.first['id'] : null);

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final cs = Theme.of(dialogCtx).colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
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
                    AppSpacing.h16,
                    const Text(
                      'Chọn nhân viên xử lý:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    AppSpacing.h8,
                    if (staffList.isEmpty)
                      Text(
                        'Chưa có nhân viên nào trong hệ thống',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedStaffId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: staffList.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(
                              s['name']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedStaffId = val);
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Xác nhận tiếp nhận'),
                ),
              ],
            );
          },
        ),
      );

      if (confirmed == true) {
        await _updateStatus(
          issue,
          'in_progress',
          assignedStaffId: selectedStaffId,
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _updateStatus(issue, 'in_progress');
    }
  }

  void _showResolveModal(BuildContext context, IssueModel issue) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResolveIssueMaterialsSheet(
        issue: issue,
        onResolved: () => ref.invalidate(allIssuesProvider),
      ),
    );
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
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
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
              error: (_, _) => const SizedBox.shrink(),
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
                    ManagementIssueSlaHeader(isDesktop: isDesktop),
                    _buildToolbar(context, isDesktop),
                    Expanded(
                      child: AppStateView<List<IssueModel>>(
                        asyncValue: issuesAsync,
                        skeletonBuilder: (_) => ListView(
                          padding: AppSpacing.p16,
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
                            return RefreshIndicator(
                              color: Theme.of(context).colorScheme.primary,
                              onRefresh: () async {
                                HapticFeedback.lightImpact();
                                ref.invalidate(allIssuesProvider);
                              },
                              child: ListView(
                                padding: AppSpacing.p16,
                                children: [
                                  ManagementIssueDesktopTable(
                                    issues: filtered,
                                    onAutoAssignAi: _autoAssignWithAi,
                                    onAssignStaff: _showAssignStaffDialog,
                                    onResolve: (issue) =>
                                        _showResolveModal(context, issue),
                                    onOpenDetail: (issue) => context.push(
                                      AppRoutes.managementIssueDetail,
                                      extra: issue,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return RefreshIndicator(
                            color: Theme.of(context).colorScheme.primary,
                            onRefresh: () async {
                              HapticFeedback.lightImpact();
                              ref.invalidate(allIssuesProvider);
                            },
                            child: ListView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final issue = filtered[index];
                                return ManagementIssueMobileCard(
                                  issue: issue,
                                  onOpenDetail: () => context.push(
                                    AppRoutes.managementIssueDetail,
                                    extra: issue,
                                  ),
                                  onAutoAssignAi: () =>
                                      _autoAssignWithAi(issue),
                                  onAssignStaff: () =>
                                      _showAssignStaffDialog(issue),
                                  onResolve: () =>
                                      _showResolveModal(context, issue),
                                );
                              },
                            ),
                          );
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

  Widget _buildToolbar(BuildContext context, bool isDesktop) {
    final chips = _buildFilterChipsList(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 380,
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: 'Tìm theo căn hộ hoặc mô tả sự cố...',
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    onClear: () => setState(() => _searchQuery = ''),
                  ),
                ),
                AppSpacing.w16,
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: chips),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                AppSearchField(
                  controller: _searchController,
                  hintText: 'Tìm theo căn hộ hoặc mô tả sự cố...',
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  onClear: () => setState(() => _searchQuery = ''),
                ),
                AppSpacing.h6,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: chips),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildFilterChipsList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      _buildFilterChip(context, 'all', 'Tất cả', colorScheme.primary),
      AppSpacing.w8,
      _buildFilterChip(
        context,
        'pending',
        'Chờ xử lý',
        AppStatusColors.getPending(context),
      ),
      AppSpacing.w8,
      _buildFilterChip(
        context,
        'in_progress',
        'Đang xử lý',
        colorScheme.primary,
      ),
      AppSpacing.w8,
      _buildFilterChip(
        context,
        'resolved',
        'Đã hoàn thành',
        AppStatusColors.getPaid(context),
      ),
      AppSpacing.w8,
      FilterChip(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        avatar: Icon(
          Icons.person_pin_outlined,
          size: 16,
          color: _onlyAssignedToMe
              ? colorScheme.onPrimary
              : colorScheme.primary,
        ),
        label: Text(
          'Giao cho tôi',
          style: TextStyle(
            color: _onlyAssignedToMe
                ? colorScheme.onPrimary
                : colorScheme.onSurface,
            fontWeight: _onlyAssignedToMe ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: _onlyAssignedToMe,
        selectedColor: AppTheme.primary,
        backgroundColor: colorScheme.surface,
        side: BorderSide(
          color: _onlyAssignedToMe
              ? AppTheme.primary
              : colorScheme.outlineVariant,
        ),
        onSelected: (selected) {
          setState(() => _onlyAssignedToMe = selected);
        },
      ),
    ];
  }

  Widget _buildEmptyListState(BuildContext context) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
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

  Widget _buildFilterChip(
    BuildContext context,
    String status,
    String label,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedStatus == status;

    return ChoiceChip(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = status);
        }
      },
      selectedColor: color.withValues(alpha: isDark ? 0.25 : 0.18),
      labelStyle: TextStyle(
        color: isSelected ? color : colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: isSelected ? color : colorScheme.outlineVariant,
      ),
    );
  }
}
