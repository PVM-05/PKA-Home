import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/dashboard_providers.dart'
    show pendingLinkRequestsCountProvider;
import '../../../data/providers/management_provider.dart';
import '../widgets/resident/management_resident_list_card.dart';
import '../widgets/resident/resident_management_dialogs.dart';
import '../widgets/resident_360_detail_sheet.dart';
import '../widgets/resident_activation_management_sheet.dart';
import 'link_request_management_screen.dart';

class ResidentManagementScreen extends ConsumerStatefulWidget {
  const ResidentManagementScreen({super.key});

  @override
  ConsumerState<ResidentManagementScreen> createState() =>
      _ResidentManagementScreenState();
}

class _ResidentManagementScreenState
    extends ConsumerState<ResidentManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';
  String _selectedApartmentFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedRoleFilter != 'all') count++;
    if (_selectedStatusFilter != 'all') count++;
    if (_selectedApartmentFilter != 'all') count++;
    return count;
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'resident':
        return 'Cư dân';
      case 'admin':
        return 'Quản trị viên';
      case 'accountant':
        return 'Kế toán';
      case 'technician':
        return 'Kỹ thuật viên';
      default:
        return 'Tất cả';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Đang hoạt động';
      case 'locked':
        return 'Đã khóa';
      case 'deactivated':
        return 'Đã vô hiệu hóa';
      default:
        return 'Tất cả';
    }
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showResidentFilterBottomSheet(
      context,
      currentRole: _selectedRoleFilter,
      currentStatus: _selectedStatusFilter,
      currentApartment: _selectedApartmentFilter,
    );
    if (result != null && mounted) {
      setState(() {
        _selectedRoleFilter = result.role;
        _selectedStatusFilter = result.status;
        _selectedApartmentFilter = result.apartment;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final residentsAsync = ref.watch(residentsProvider);
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final isCurrentUserAdmin = ref.watch(authProvider).value?.isAdmin ?? false;
    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final linkCount = pendingLinkReqAsync.value ?? 0;

    final allResidents = residentsAsync.value ?? [];
    final filteredResidents = allResidents.where((r) {
      if (_selectedRoleFilter != 'all') {
        if (_selectedRoleFilter == 'admin') {
          if (!r.isAdmin) return false;
        } else if (r.role != _selectedRoleFilter) {
          return false;
        }
      }

      if (_selectedStatusFilter != 'all') {
        if (_selectedStatusFilter == 'active') {
          if (!r.isActive || r.isLocked) return false;
        } else if (_selectedStatusFilter == 'locked') {
          if (!r.isLocked) return false;
        } else if (_selectedStatusFilter == 'deactivated') {
          if (r.isActive) return false;
        }
      }

      if (_selectedApartmentFilter != 'all') {
        final hasApartment = r.apartments.isNotEmpty || r.apartment != null;
        if (_selectedApartmentFilter == 'assigned' && !hasApartment) {
          return false;
        }
        if (_selectedApartmentFilter == 'unassigned' && hasApartment) {
          return false;
        }
      }

      if (_searchQuery.isEmpty) return true;
      final nameMatch = r.fullName.toLowerCase().contains(_searchQuery);
      final emailMatch = (r.email ?? '').toLowerCase().contains(_searchQuery);
      final phoneMatch = (r.phone ?? '').toLowerCase().contains(_searchQuery);
      final aptCodesMatch = r.apartments.any(
        (a) => a.apartmentCode.toLowerCase().contains(_searchQuery),
      );
      final legacyAptMatch =
          r.apartment?.code.toLowerCase().contains(_searchQuery) ?? false;
      return nameMatch ||
          emailMatch ||
          phoneMatch ||
          aptCodesMatch ||
          legacyAptMatch;
    }).toList();

    return RoleGuard(
      permission: AppPermissions.residentManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Cư dân'),
          actions: [
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.key_rounded),
              tooltip: 'Mã kích hoạt & Thư mời cư dân',
              onPressed: () => ResidentActivationManagementSheet.show(context),
            ),
            if (isCurrentUserAdmin)
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: linkCount > 0
                    ? Badge(
                        label: Text('$linkCount'),
                        child: const Icon(Icons.person_add_outlined),
                      )
                    : const Icon(Icons.person_add_outlined),
                tooltip: 'Duyệt yêu cầu liên kết',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LinkRequestManagementScreen(),
                    ),
                  );
                  ref.invalidate(residentsProvider);
                  ref.invalidate(pendingLinkRequestsCountProvider);
                },
              ),
          ],
        ),
        floatingActionButton: isCurrentUserAdmin
            ? FloatingActionButton.extended(
                backgroundColor: AppTheme.primary,
                foregroundColor: colorScheme.onPrimary,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text(
                  'Thêm người dùng',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final apartments = apartmentsAsync.value ?? [];
                  showCreateResidentUserDialog(context, apartments);
                },
              )
            : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Column(
                  children: [
                    _buildResidentToolbar(
                      context,
                      isDesktop: isDesktop,
                      filteredCount: filteredResidents.length,
                      totalCount: allResidents.length,
                      hasData: residentsAsync.hasValue,
                    ),
                    if (_activeFilterCount > 0) _buildActiveFilterChips(),
                    AppSpacing.h4,
                    Expanded(
                      child: AppStateView<List<ResidentModel>>(
                        asyncValue: residentsAsync,
                        skeletonBuilder: (_) => ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          children: const [
                            ListItemSkeleton(),
                            ListItemSkeleton(),
                            ListItemSkeleton(),
                          ],
                        ),
                        emptyMessage: 'Không có người dùng nào',
                        emptyIcon: Icons.group_outlined,
                        onRetry: () {
                          ref.invalidate(residentsProvider);
                          ref.invalidate(apartmentsProvider);
                        },
                        dataBuilder: (_) {
                          if (filteredResidents.isEmpty) {
                            return _buildEmptyResidentsView(context);
                          }

                          if (isDesktop) {
                            return _buildDesktopResidentWorkstation(
                              context,
                              filteredResidents,
                              apartmentsAsync.value ?? [],
                              isCurrentUserAdmin,
                            );
                          }

                          return _buildMobileResidentList(
                            context,
                            filteredResidents,
                            apartmentsAsync.value ?? [],
                            isCurrentUserAdmin,
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

  Widget _buildResidentToolbar(
    BuildContext context, {
    required bool isDesktop,
    required int filteredCount,
    required int totalCount,
    required bool hasData,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final filterButton = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r8),
      ),
      onPressed: () => _openFilterSheet(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.filter_list, size: 18),
          if (_activeFilterCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      label: Text(
        _activeFilterCount > 0 ? 'Bộ lọc ($_activeFilterCount)' : 'Bộ lọc',
      ),
    );

    final countText = Text(
      hasData
          ? 'Hiển thị $filteredCount/$totalCount người dùng'
          : 'Đang tải người dùng...',
      style: textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      overflow: TextOverflow.ellipsis,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 400,
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: 'Tìm theo tên, email, SĐT hoặc mã căn hộ...',
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase().trim()),
                    onClear: () => setState(() => _searchQuery = ''),
                  ),
                ),
                AppSpacing.w16,
                Expanded(child: countText),
                AppSpacing.w12,
                filterButton,
              ],
            )
          : Column(
              children: [
                AppSearchField(
                  controller: _searchController,
                  hintText: 'Tìm theo tên, email, SĐT hoặc mã căn hộ...',
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase().trim()),
                  onClear: () => setState(() => _searchQuery = ''),
                ),
                AppSpacing.h6,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: countText),
                    AppSpacing.w8,
                    filterButton,
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildActiveFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          if (_selectedRoleFilter != 'all')
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  'Vai trò: ${_getRoleLabel(_selectedRoleFilter)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                onDeleted: () => setState(() => _selectedRoleFilter = 'all'),
                deleteIcon: const Icon(Icons.cancel, size: 16),
              ),
            ),
          if (_selectedStatusFilter != 'all')
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  'Trạng thái: ${_getStatusLabel(_selectedStatusFilter)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                onDeleted: () => setState(() => _selectedStatusFilter = 'all'),
                deleteIcon: const Icon(Icons.cancel, size: 16),
              ),
            ),
          if (_selectedApartmentFilter != 'all')
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  'Căn hộ: ${_selectedApartmentFilter == 'assigned' ? 'Đã gán' : 'Chưa gán'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                onDeleted: () =>
                    setState(() => _selectedApartmentFilter = 'all'),
                deleteIcon: const Icon(Icons.cancel, size: 16),
              ),
            ),
          if (_activeFilterCount > 1)
            ActionChip(
              label: Text(
                'Xóa tất cả',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              avatar: const Icon(Icons.close, size: 14),
              onPressed: () {
                setState(() {
                  _selectedRoleFilter = 'all';
                  _selectedStatusFilter = 'all';
                  _selectedApartmentFilter = 'all';
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyResidentsView(BuildContext context) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(residentsProvider);
        ref.invalidate(apartmentsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          const AppEmptyState(
            icon: Icons.person_search,
            title: 'Không tìm thấy người dùng nào phù hợp',
            description:
                'Vui lòng thử lại với từ khóa khác hoặc đặt lại bộ lọc đang áp dụng.',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopResidentWorkstation(
    BuildContext context,
    List<ResidentModel> residents,
    List<ApartmentModel> apartments,
    bool isCurrentUserAdmin,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(residentsProvider);
        ref.invalidate(apartmentsProvider);
      },
      child: ListView(
        padding: AppSpacing.p16,
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 950),
                child: DataTable(
                  columnSpacing: 16,
                  horizontalMargin: 16,
                  headingRowColor: WidgetStateProperty.all(
                    colorScheme.surfaceContainerLow,
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Người dùng',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Vai trò',
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
                        'Căn hộ liên kết',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Liên hệ',
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
                  rows: residents.map((resident) {
                    final roleColor = getResidentRoleColor(
                      context,
                      resident.role,
                    );
                    final hasApt =
                        resident.apartments.isNotEmpty ||
                        resident.apartment != null;

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: roleColor.withValues(
                                  alpha: 0.15,
                                ),
                                child: Text(
                                  resident.fullName.isNotEmpty
                                      ? resident.fullName[0].toUpperCase()
                                      : '?',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: roleColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              AppSpacing.w10,
                              Text(
                                resident.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(_buildRoleChip(context, resident)),
                        DataCell(_buildStatusChip(context, resident)),
                        DataCell(
                          Text(
                            resident.apartmentSummary,
                            style: TextStyle(
                              color: hasApt
                                  ? successColor
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (resident.email != null &&
                                  resident.email!.isNotEmpty)
                                Text(
                                  resident.email!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (resident.phone != null &&
                                  resident.phone!.isNotEmpty)
                                Text(
                                  resident.phone!,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrentUserAdmin)
                                IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  icon: Icon(
                                    Icons.manage_accounts_outlined,
                                    size: 18,
                                    color: secondaryColor,
                                  ),
                                  tooltip: 'Phân quyền vai trò',
                                  onPressed: () => showChangeResidentRoleDialog(
                                    context,
                                    ref,
                                    resident,
                                  ),
                                ),
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: Icon(
                                  Icons.add_home_work_outlined,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                tooltip: 'Gán căn hộ',
                                onPressed: () =>
                                    showAssignResidentApartmentDialog(
                                      context,
                                      ref,
                                      resident,
                                      apartments,
                                    ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                tooltip: 'Xem chi tiết 360',
                                onPressed: () async {
                                  await showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => Resident360DetailSheet(
                                      resident: resident,
                                    ),
                                  );
                                  ref.invalidate(residentsProvider);
                                  ref.invalidate(apartmentsProvider);
                                },
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

  Widget _buildMobileResidentList(
    BuildContext context,
    List<ResidentModel> residents,
    List<ApartmentModel> apartments,
    bool isCurrentUserAdmin,
  ) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(residentsProvider);
        ref.invalidate(apartmentsProvider);
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
        itemCount: residents.length,
        itemBuilder: (context, index) {
          final resident = residents[index];
          return ManagementResidentListCard(
            resident: resident,
            apartments: apartments,
            isCurrentUserAdmin: isCurrentUserAdmin,
            onTap: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => Resident360DetailSheet(resident: resident),
              );
              ref.invalidate(residentsProvider);
              ref.invalidate(apartmentsProvider);
            },
            onChangeRole: () =>
                showChangeResidentRoleDialog(context, ref, resident),
            onAssignApartment: () => showAssignResidentApartmentDialog(
              context,
              ref,
              resident,
              apartments,
            ),
            roleColor: getResidentRoleColor(context, resident.role),
            roleChip: _buildRoleChip(context, resident),
            statusChip: _buildStatusChip(context, resident),
          );
        },
      ),
    );
  }

  Widget _buildRoleChip(BuildContext context, ResidentModel resident) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = getResidentRoleColor(context, resident.role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: AppRadius.r8,
        border: Border.all(
          color: roleColor.withValues(alpha: isDark ? 0.45 : 0.35),
        ),
      ),
      child: Text(
        resident.roleDisplayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: roleColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, ResidentModel resident) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color;
    final String text;
    if (!resident.isActive) {
      color = colorScheme.onSurfaceVariant;
      text = 'Đã vô hiệu hóa';
    } else if (resident.isLocked) {
      color = AppTheme.getSemanticError(context);
      text = 'Đã khóa';
    } else {
      color = AppStatusColors.getPaid(context);
      text = 'Hoạt động';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: AppRadius.r8,
        border: Border.all(color: color.withValues(alpha: isDark ? 0.45 : 0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
