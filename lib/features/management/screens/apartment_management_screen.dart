import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/models/batch_import_model.dart';
import '../../../data/providers/batch_import_provider.dart';
import '../../../data/providers/management_provider.dart';
import '../widgets/apartment/apartment_management_dialogs.dart';
import '../widgets/apartment/management_apartment_grid_card.dart';

class ApartmentManagementScreen extends ConsumerStatefulWidget {
  const ApartmentManagementScreen({super.key});

  @override
  ConsumerState<ApartmentManagementScreen> createState() =>
      _ApartmentManagementScreenState();
}

class _ApartmentManagementScreenState
    extends ConsumerState<ApartmentManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedBuilding;
  int? _selectedFloor;
  String _statusFilter = 'all';
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _downloadApartmentTemplate(
    BuildContext context, {
    required bool isCsv,
  }) async {
    final notifier = ref.read(batchImportProvider.notifier);
    final path = isCsv
        ? await notifier.downloadCsvTemplate(BatchImportType.apartments)
        : await notifier.downloadTemplate(BatchImportType.apartments);

    if (path != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tạo file mẫu ${isCsv ? "CSV" : "Excel"} thành công',
          ),
          backgroundColor: AppTheme.textSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsProvider);

    return RoleGuard(
      permission: AppPermissions.apartmentManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Căn hộ'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Tải file mẫu Excel/CSV',
              onSelected: (value) {
                if (value == 'excel') {
                  _downloadApartmentTemplate(context, isCsv: false);
                } else if (value == 'csv') {
                  _downloadApartmentTemplate(context, isCsv: true);
                }
              },
              itemBuilder: (ctx) {
                final cs = Theme.of(ctx).colorScheme;
                final sec = AppTheme.getSemanticSecondary(ctx);
                return [
                  PopupMenuItem(
                    value: 'excel',
                    child: Row(
                      children: [
                        Icon(
                          Icons.table_view_outlined,
                          color: cs.primary,
                          size: 20,
                        ),
                        AppSpacing.w8,
                        const Text('Tải file mẫu Excel (.xlsx)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: sec,
                          size: 20,
                        ),
                        AppSpacing.w8,
                        const Text('Tải file mẫu CSV (.csv)'),
                      ],
                    ),
                  ),
                ];
              },
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.upload_file),
              tooltip: 'Nhập Excel/CSV',
              onPressed: () => context.push(AppRoutes.managementBatchImport),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              ),
              tooltip: _isGridView
                  ? 'Chuyển sang danh sách'
                  : 'Chuyển sang dạng lưới',
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return apartmentsAsync.when(
                  data: (allApartments) {
                    if (allApartments.isEmpty) {
                      return _buildEmptyOnboardingState(context);
                    }

                    final buildings =
                        allApartments
                            .map((a) => a.buildingCode.toUpperCase())
                            .where((b) => b.isNotEmpty)
                            .toSet()
                            .toList()
                          ..sort();

                    final floors =
                        allApartments
                            .where(
                              (a) =>
                                  _selectedBuilding == null ||
                                  a.buildingCode.toUpperCase() ==
                                      _selectedBuilding,
                            )
                            .map((a) => a.floorNumber)
                            .toSet()
                            .toList()
                          ..sort();

                    final filteredApartments =
                        allApartments.where((apt) {
                          if (_searchQuery.isNotEmpty &&
                              !apt.code.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              )) {
                            return false;
                          }
                          if (_selectedBuilding != null &&
                              apt.buildingCode.toUpperCase() !=
                                  _selectedBuilding) {
                            return false;
                          }
                          if (_selectedFloor != null &&
                              apt.floorNumber != _selectedFloor) {
                            return false;
                          }
                          if (_statusFilter == 'empty' && !apt.isEmpty) {
                            return false;
                          }
                          if (_statusFilter == 'occupied' && apt.isEmpty) {
                            return false;
                          }
                          return true;
                        }).toList()..sort((a, b) => a.code.compareTo(b.code));

                    final emptyCount = allApartments
                        .where((a) => a.isEmpty)
                        .length;
                    final occupiedCount = allApartments
                        .where((a) => !a.isEmpty)
                        .length;

                    if (isDesktop) {
                      return _buildDesktopApartmentWorkstation(
                        context,
                        allApartments,
                        filteredApartments,
                        buildings,
                        emptyCount,
                        occupiedCount,
                      );
                    }

                    final colorScheme = Theme.of(context).colorScheme;
                    return Column(
                      children: [
                        Container(
                          color: colorScheme.surface,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSearchField(
                                controller: _searchController,
                                hintText:
                                    'Tìm theo mã căn hộ (VD: A0110, B0502)...',
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val.trim()),
                                onClear: () =>
                                    setState(() => _searchQuery = ''),
                              ),
                              AppSpacing.h8,
                              _buildBuildingFilterRow(context, buildings),
                              AppSpacing.h6,
                              if (floors.isNotEmpty) ...[
                                _buildFloorFilterRow(context, floors),
                                AppSpacing.h6,
                              ],
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildStatusChip(
                                      context,
                                      'all',
                                      'Tất cả (${allApartments.length})',
                                      null,
                                    ),
                                    AppSpacing.w8,
                                    _buildStatusChip(
                                      context,
                                      'empty',
                                      'Còn trống ($emptyCount)',
                                      AppStatusColors.getPaid(context),
                                    ),
                                    AppSpacing.w8,
                                    _buildStatusChip(
                                      context,
                                      'occupied',
                                      'Đã có chủ ($occupiedCount)',
                                      colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async =>
                                ref.invalidate(apartmentsProvider),
                            child: filteredApartments.isEmpty
                                ? _buildEmptyFilteredView(context)
                                : _isGridView
                                ? _buildGridView(filteredApartments)
                                : _buildListView(filteredApartments),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => ListView(
                    padding: AppSpacing.p16,
                    children: [
                      AppSkeletonShimmer.cardList(count: 4, itemHeight: 96),
                    ],
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: AppSpacing.p24,
                      child: AppErrorCard(
                        error: e,
                        onRetry: () => ref.invalidate(apartmentsProvider),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'apartment_management_fab',
          onPressed: () => showApartmentFormDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Thêm căn hộ'),
        ),
      ),
    );
  }

  Widget _buildEmptyOnboardingState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: AppSpacing.p24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: AppSpacing.p20,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.18 : 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.apartment_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            AppSpacing.h20,
            Text(
              'Chưa có dữ liệu căn hộ trong hệ thống',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.h8,
            Text(
              'Hạ tầng tòa nhà đang trống. Bạn có thể tải file mẫu Excel hoặc CSV để nhập nhanh danh sách căn hộ theo lô.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.h24,
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Tải mẫu Excel/CSV'),
                  onPressed: () => showDownloadApartmentTemplateSheet(
                    context,
                    onExcel: () =>
                        _downloadApartmentTemplate(context, isCsv: false),
                    onCsv: () =>
                        _downloadApartmentTemplate(context, isCsv: true),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Nhập từ Excel/CSV'),
                  onPressed: () =>
                      context.push(AppRoutes.managementBatchImport),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingFilterRow(
    BuildContext context,
    List<String> buildings,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          'Tòa nhà:',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.w8,
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: const Text('Tất cả'),
                    selected: _selectedBuilding == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedBuilding = null;
                          _selectedFloor = null;
                        });
                      }
                    },
                  ),
                ),
                ...buildings.map((b) {
                  final isSelected = _selectedBuilding == b;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      label: Text('Tòa $b'),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedBuilding = selected ? b : null;
                          _selectedFloor = null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloorFilterRow(BuildContext context, List<int> floors) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          'Số tầng: ',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.w8,
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: const Text('Tất cả tầng'),
                    selected: _selectedFloor == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFloor = null);
                      }
                    },
                  ),
                ),
                ...floors.map((floor) {
                  final isSelected = _selectedFloor == floor;
                  final floorLabel = 'Tầng ${floor.toString().padLeft(2, '0')}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      label: Text(floorLabel),
                      selected: isSelected,
                      selectedColor: AppTheme.secondary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() => _selectedFloor = selected ? floor : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFilteredView(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy căn hộ phù hợp bộ lọc',
          description:
              'Vui lòng thử từ khóa khác hoặc đặt lại bộ lọc tòa nhà và tầng.',
          actionLabel: 'Đặt lại bộ lọc',
          onAction: () {
            setState(() {
              _searchController.clear();
              _searchQuery = '';
              _selectedBuilding = null;
              _selectedFloor = null;
              _statusFilter = 'all';
            });
          },
        ),
      ],
    );
  }

  Widget _buildDesktopApartmentWorkstation(
    BuildContext context,
    List<ApartmentModel> allApartments,
    List<ApartmentModel> filteredApartments,
    List<String> buildings,
    int emptyCount,
    int occupiedCount,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final paidColor = AppStatusColors.getPaid(context);
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final errorColor = AppTheme.getSemanticError(context);

    final occupancyRate = allApartments.isNotEmpty
        ? (occupiedCount / allApartments.length) * 100
        : 0.0;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(apartmentsProvider),
      child: ListView(
        padding: AppSpacing.p16,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKpiBox(
                  context,
                  'Tổng số căn hộ',
                  '${allApartments.length} căn',
                  colorScheme.primary,
                  Icons.apartment,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: _buildKpiBox(
                  context,
                  'Đã có cư dân',
                  '$occupiedCount căn',
                  colorScheme.primary,
                  Icons.home,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: _buildKpiBox(
                  context,
                  'Căn hộ trống',
                  '$emptyCount căn',
                  paidColor,
                  Icons.meeting_room_outlined,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: _buildKpiBox(
                  context,
                  'Tỷ lệ lấp đầy',
                  '${occupancyRate.toStringAsFixed(1)}%',
                  occupancyRate >= 80 ? successColor : warningColor,
                  Icons.pie_chart_outline,
                ),
              ),
            ],
          ),
          AppSpacing.h16,
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: AppSearchField(
                        controller: _searchController,
                        hintText: 'Tìm theo mã căn hộ (VD: A0110)...',
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                        onClear: () => setState(() => _searchQuery = ''),
                      ),
                    ),
                    AppSpacing.w16,
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusChip(
                              context,
                              'all',
                              'Tất cả (${allApartments.length})',
                              null,
                            ),
                            AppSpacing.w8,
                            _buildStatusChip(
                              context,
                              'empty',
                              'Còn trống ($emptyCount)',
                              paidColor,
                            ),
                            AppSpacing.w8,
                            _buildStatusChip(
                              context,
                              'occupied',
                              'Đã có chủ ($occupiedCount)',
                              colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.h12,
                _buildBuildingFilterRow(context, buildings),
              ],
            ),
          ),
          AppSpacing.h16,
          AppCard(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: DataTable(
                  columnSpacing: 16,
                  horizontalMargin: 16,
                  headingRowColor: WidgetStateProperty.all(
                    colorScheme.surfaceContainerLow,
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Mã căn hộ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tòa nhà',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tầng',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Diện tích',
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
                  rows: filteredApartments.map((apt) {
                    final statusColor = apt.isEmpty
                        ? paidColor
                        : colorScheme.primary;
                    final statusText = apt.isEmpty ? 'Còn trống' : 'Đã có chủ';

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            apt.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        DataCell(Text('Tòa ${apt.buildingCode}')),
                        DataCell(
                          Text(
                            'Tầng ${apt.floorNumber.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${apt.area ?? 0} m²',
                            style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(
                                alpha: isDark ? 0.18 : 0.10,
                              ),
                              borderRadius: AppRadius.r12,
                              border: Border.all(
                                color: statusColor.withValues(
                                  alpha: isDark ? 0.45 : 0.30,
                                ),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                tooltip: 'Chi tiết căn hộ',
                                onPressed: () => _openDetails(apt),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: secondaryColor,
                                ),
                                tooltip: 'Chỉnh sửa',
                                onPressed: () => showApartmentFormDialog(
                                  context,
                                  ref,
                                  apartment: apt,
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: errorColor,
                                ),
                                tooltip: 'Xóa',
                                onPressed: () =>
                                    showDeleteApartmentDialog(context, ref, apt),
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

  void _openDetails(ApartmentModel apt) {
    showApartmentDetailsSheet(
      context,
      ref,
      apt,
      onEdit: () => showApartmentFormDialog(context, ref, apartment: apt),
      onDelete: () => showDeleteApartmentDialog(context, ref, apt),
    );
  }

  Widget _buildKpiBox(
    BuildContext context,
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.42 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              AppSpacing.w4,
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.h4,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String status,
    String label,
    Color? activeColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _statusFilter == status;
    final color = activeColor ?? colorScheme.primary;

    return ChoiceChip(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: isDark ? 0.25 : 0.15),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: isSelected ? color : colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: isSelected ? color : colorScheme.outlineVariant,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _statusFilter = status);
      },
    );
  }

  Widget _buildGridView(List<ApartmentModel> apartments) {
    return GridView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppSpacing.p12,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 0.92,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: apartments.length,
      itemBuilder: (context, index) {
        final apt = apartments[index];
        return ManagementApartmentGridCard(
          apartment: apt,
          onTap: () => _openDetails(apt),
          onEdit: () => showApartmentFormDialog(context, ref, apartment: apt),
          onDelete: () => showDeleteApartmentDialog(context, ref, apt),
        );
      },
    );
  }

  Widget _buildListView(List<ApartmentModel> apartments) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final paidColor = AppStatusColors.getPaid(context);
    final errorColor = AppTheme.getSemanticError(context);

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: apartments.length,
      itemBuilder: (context, index) {
        final apt = apartments[index];
        final statusColor = apt.isEmpty ? paidColor : colorScheme.primary;
        final statusText = apt.isEmpty ? 'Còn trống' : 'Đã có chủ';

        return AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => _openDetails(apt),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: statusColor.withValues(
                  alpha: isDark ? 0.2 : 0.14,
                ),
                child: Icon(
                  apt.isEmpty ? Icons.apartment_outlined : Icons.home,
                  color: statusColor,
                  size: 18,
                ),
              ),
              AppSpacing.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Căn ${apt.code}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        AppSpacing.w6,
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: isDark ? 0.18 : 0.10,
                            ),
                            borderRadius: AppRadius.r8,
                          ),
                          child: Text(
                            statusText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h4,
                    Text(
                      'Tòa ${apt.buildingCode} • Tầng ${apt.floorNumber.toString().padLeft(2, '0')} • ${apt.area ?? 0} m²',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Chỉnh sửa',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    iconSize: 20,
                    icon: Icon(
                      Icons.edit_outlined,
                      color: colorScheme.primary,
                    ),
                    onPressed: () =>
                        showApartmentFormDialog(context, ref, apartment: apt),
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    iconSize: 20,
                    icon: Icon(Icons.delete_outline, color: errorColor),
                    onPressed: () =>
                        showDeleteApartmentDialog(context, ref, apt),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
