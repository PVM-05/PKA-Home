import '../../../core/router/route_names.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/apartment_model.dart';
import '../../../core/supabase_config.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/batch_import_model.dart';
import '../../../data/providers/batch_import_provider.dart';
import '../widgets/apartment_contract_sheet.dart';
import '../widgets/create_apartment_invitation_sheet.dart';

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
  String? _selectedBuilding; // null = tất cả tòa
  int? _selectedFloor; // null = tất cả tầng
  String _statusFilter = 'all'; // 'all', 'empty', 'occupied'
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'excel',
                  child: Row(
                    children: [
                      Icon(Icons.table_view_outlined, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Tải file mẫu Excel (.xlsx)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, color: AppTheme.secondary, size: 20),
                      SizedBox(width: 8),
                      Text('Tải file mẫu CSV (.csv)'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Nhập Excel/CSV',
              onPressed: () => context.push(AppRoutes.managementBatchImport),
            ),
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              ),
              tooltip: _isGridView
                  ? 'Chuyển sang danh sách'
                  : 'Chuyển sang dạng lưới',
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
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
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.apartment_outlined,
                                  size: 64,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Chưa có dữ liệu căn hộ trong hệ thống',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Hạ tầng tòa nhà đang trống. Bạn có thể tải file mẫu Excel hoặc CSV để nhập nhanh danh sách căn hộ theo lô.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.download),
                                    label: const Text('Tải mẫu Excel/CSV'),
                                    onPressed: () =>
                                        _showDownloadTemplateSheet(context),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Nhập từ Excel/CSV'),
                                    onPressed: () => context.push(
                                      AppRoutes.managementBatchImport,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // 1. Danh sách các Tòa nhà duy nhất
                    final buildings = allApartments
                        .map((a) => a.buildingCode.toUpperCase())
                        .where((b) => b.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();

                    // 2. Danh sách các Tầng theo Tòa nhà đang chọn
                    final floors = allApartments
                        .where(
                          (a) =>
                              _selectedBuilding == null ||
                              a.buildingCode.toUpperCase() == _selectedBuilding,
                        )
                        .map((a) => a.floorNumber)
                        .toSet()
                        .toList()
                      ..sort();

                    // 3. Lọc danh sách căn hộ theo các tiêu chí
                    final filteredApartments = allApartments.where((apt) {
                      if (_searchQuery.isNotEmpty) {
                        if (!apt.code.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            )) {
                          return false;
                        }
                      }

                      if (_selectedBuilding != null &&
                          apt.buildingCode.toUpperCase() != _selectedBuilding) {
                        return false;
                      }

                      if (_selectedFloor != null &&
                          apt.floorNumber != _selectedFloor) {
                        return false;
                      }

                      if (_statusFilter == 'empty' && !apt.isEmpty) return false;
                      if (_statusFilter == 'occupied' && apt.isEmpty) return false;

                      return true;
                    }).toList()
                      ..sort((a, b) => a.code.compareTo(b.code));

                    final emptyCount =
                        allApartments.where((a) => a.isEmpty).length;
                    final occupiedCount =
                        allApartments.where((a) => !a.isEmpty).length;

                    if (isDesktop) {
                      return _buildDesktopApartmentWorkstation(
                        context,
                        allApartments,
                        filteredApartments,
                        buildings,
                        floors,
                        emptyCount,
                        occupiedCount,
                      );
                    }

                    return Column(
                      children: [
                        // Khu vực bộ lọc phân cấp Mobile
                        Container(
                          color: Theme.of(context).cardColor,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Tìm theo mã căn hộ (VD: A0110, B0502)...',
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
                                onChanged: (val) {
                                  setState(() => _searchQuery = val.trim());
                                },
                              ),
                              const SizedBox(height: 8),

                              // Cấp 1: Chọn Tòa nhà
                              Row(
                                children: [
                                  const Text(
                                    'Tòa nhà:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(right: 6.0),
                                            child: ChoiceChip(
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
                                            final isSelected =
                                                _selectedBuilding == b;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 6.0,
                                              ),
                                              child: ChoiceChip(
                                                label: Text('Tòa $b'),
                                                selected: isSelected,
                                                selectedColor: AppTheme.primary,
                                                labelStyle: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppTheme.textPrimary,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                                onSelected: (selected) {
                                                  setState(() {
                                                    _selectedBuilding =
                                                        selected ? b : null;
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
                              ),
                              const SizedBox(height: 6),

                              // Cấp 2: Chọn Số Tầng
                              if (floors.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Text(
                                      'Số tầng: ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 6.0,
                                              ),
                                              child: ChoiceChip(
                                                label: const Text('Tất cả tầng'),
                                                selected: _selectedFloor == null,
                                                onSelected: (selected) {
                                                  if (selected) {
                                                    setState(
                                                      () => _selectedFloor = null,
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                            ...floors.map((floor) {
                                              final isSelected =
                                                  _selectedFloor == floor;
                                              final floorLabel =
                                                  'Tầng ${floor.toString().padLeft(2, '0')}';
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 6.0,
                                                ),
                                                child: ChoiceChip(
                                                  label: Text(floorLabel),
                                                  selected: isSelected,
                                                  selectedColor:
                                                      AppTheme.secondary,
                                                  labelStyle: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : AppTheme.textPrimary,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                  onSelected: (selected) {
                                                    setState(() {
                                                      _selectedFloor =
                                                          selected ? floor : null;
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
                                ),
                                const SizedBox(height: 6),
                              ],

                              // Cấp 3: Lọc trạng thái
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildStatusChip(
                                      'all',
                                      'Tất cả (${allApartments.length})',
                                      null,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusChip(
                                      'empty',
                                      'Còn trống ($emptyCount)',
                                      AppStatusColors.paid,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusChip(
                                      'occupied',
                                      'Đã có chủ ($occupiedCount)',
                                      AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // Danh sách / Lưới hiển thị các căn hộ
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(apartmentsProvider);
                            },
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      formatErrorMessage(e),
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'apartment_management_fab',
          onPressed: () => _showApartmentDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Thêm căn hộ'),
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredView(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Không tìm thấy căn hộ phù hợp bộ lọc',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _selectedBuilding = null;
                      _selectedFloor = null;
                      _statusFilter = 'all';
                    });
                  },
                  child: const Text('Đặt lại bộ lọc'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopApartmentWorkstation(
    BuildContext context,
    List<ApartmentModel> allApartments,
    List<ApartmentModel> filteredApartments,
    List<String> buildings,
    List<int> floors,
    int emptyCount,
    int occupiedCount,
  ) {
    final occupancyRate = allApartments.isNotEmpty
        ? (occupiedCount / allApartments.length) * 100
        : 0.0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(apartmentsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Quick Stats Row
          Row(
            children: [
              Expanded(
                child: _buildKpiBox(
                  'Tổng số căn hộ',
                  '${allApartments.length} căn',
                  AppTheme.primary,
                  Icons.apartment,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiBox(
                  'Đã có cư dân',
                  '$occupiedCount căn',
                  AppTheme.primary,
                  Icons.home,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiBox(
                  'Căn hộ trống',
                  '$emptyCount căn',
                  AppStatusColors.paid,
                  Icons.meeting_room_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiBox(
                  'Tỷ lệ lấp đầy',
                  '${occupancyRate.toStringAsFixed(1)}%',
                  occupancyRate >= 80 ? Colors.green : Colors.orange,
                  Icons.pie_chart_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Desktop Filter Bar Card
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm theo mã căn hộ (VD: A0110)...',
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
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusChip(
                              'all',
                              'Tất cả (${allApartments.length})',
                              null,
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(
                              'empty',
                              'Còn trống ($emptyCount)',
                              AppStatusColors.paid,
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(
                              'occupied',
                              'Đã có chủ ($occupiedCount)',
                              AppTheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Tòa nhà: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
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
                                  label: Text('Tòa $b'),
                                  selected: isSelected,
                                  selectedColor: AppTheme.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textPrimary,
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Desktop Table View
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
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF8FAFC),
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
                    final statusColor =
                        apt.isEmpty ? AppStatusColors.paid : AppTheme.primary;
                    final statusText =
                        apt.isEmpty ? 'Còn trống' : 'Đã có chủ';

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            apt.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(Text('Tòa ${apt.buildingCode}')),
                        DataCell(
                          Text(
                            'Tầng ${apt.floorNumber.toString().padLeft(2, '0')}',
                          ),
                        ),
                        DataCell(Text('${apt.area ?? 0} m²')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
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
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: AppTheme.primary,
                                ),
                                tooltip: 'Chi tiết căn hộ',
                                onPressed: () =>
                                    _showApartmentDetailsModal(context, ref, apt),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppTheme.secondary,
                                ),
                                tooltip: 'Chỉnh sửa',
                                onPressed: () => _showApartmentDialog(
                                  context,
                                  ref,
                                  apartment: apt,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppTheme.error,
                                ),
                                tooltip: 'Xóa',
                                onPressed: () =>
                                    _deleteApartment(context, ref, apt),
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

  Widget _buildKpiBox(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
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
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String label, Color? activeColor) {
    final isSelected = _statusFilter == status;
    final color = activeColor ?? AppTheme.primary;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? color : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = status);
        }
      },
    );
  }

  Widget _buildGridView(List<ApartmentModel> apartments) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 0.95,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: apartments.length,
      itemBuilder: (context, index) {
        final apt = apartments[index];
        final statusColor =
            apt.isEmpty ? AppStatusColors.paid : AppTheme.primary;
        final statusText = apt.isEmpty ? 'Còn trống' : 'Đã có chủ';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: apt.isEmpty
                  ? Colors.grey.shade200
                  : AppTheme.primary.withValues(alpha: 0.25),
              width: apt.isEmpty ? 1 : 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showApartmentDetailsModal(context, ref, apt),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          apt.code,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.square_foot,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${apt.area ?? 0} m²',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.layers_outlined,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Tòa ${apt.buildingCode} - Tầng ${apt.floorNumber.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () =>
                            _showApartmentDialog(context, ref, apartment: apt),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(3.0),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 17,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _deleteApartment(context, ref, apt),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(3.0),
                          child: Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(List<ApartmentModel> apartments) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: apartments.length,
      itemBuilder: (context, index) {
        final apt = apartments[index];
        final statusColor =
            apt.isEmpty ? AppStatusColors.paid : AppTheme.primary;
        final statusText = apt.isEmpty ? 'Còn trống' : 'Đã có chủ';

        return AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => _showApartmentDetailsModal(context, ref, apt),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(
                  apt.isEmpty ? Icons.apartment_outlined : Icons.home,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Căn ${apt.code}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tòa ${apt.buildingCode} • Tầng ${apt.floorNumber.toString().padLeft(2, '0')} • ${apt.area ?? 0} m²',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    iconSize: 18,
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primary,
                    ),
                    onPressed: () =>
                        _showApartmentDialog(context, ref, apartment: apt),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    iconSize: 18,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.error,
                    ),
                    onPressed: () => _deleteApartment(context, ref, apt),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showApartmentDetailsModal(
    BuildContext context,
    WidgetRef ref,
    ApartmentModel apt,
  ) async {
    showModalBottomSheet(
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
          builder: (context, snapshot) {
            final residents = snapshot.data ?? [];
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.domain,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Chi tiết Căn hộ ${apt.code}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: apt.isEmpty
                              ? AppStatusColors.paid.withValues(alpha: 0.15)
                              : AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          apt.isEmpty ? 'Còn trống' : 'Đã có chủ',
                          style: TextStyle(
                            color: apt.isEmpty
                                ? AppStatusColors.paid
                                : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailTile(
                          'Tòa nhà',
                          'Tòa ${apt.buildingCode}',
                          Icons.apartment,
                        ),
                      ),
                      Expanded(
                        child: _buildDetailTile(
                          'Số tầng',
                          'Tầng ${apt.floorNumber}',
                          Icons.layers,
                        ),
                      ),
                      Expanded(
                        child: _buildDetailTile(
                          'Diện tích',
                          '${apt.area ?? 0} m²',
                          Icons.square_foot,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Cư dân đang sinh sống:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (residents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Chưa có cư dân nào liên kết với căn hộ này.',
                        style: TextStyle(color: AppTheme.textSecondary),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.qr_code_2_rounded,
                            color: AppTheme.primary,
                          ),
                          label: const Text(
                            'Mã mời',
                            style: TextStyle(color: AppTheme.primary),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showModalBottomSheet(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.assignment_outlined,
                            color: AppTheme.primary,
                          ),
                          label: const Text(
                            'Hợp đồng & Lưu trú',
                            style: TextStyle(color: AppTheme.primary),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showModalBottomSheet(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Sửa căn hộ'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showApartmentDialog(context, ref, apartment: apt);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Xóa căn hộ'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteApartment(context, ref, apt);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailTile(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  void _showApartmentDialog(
    BuildContext context,
    WidgetRef ref, {
    ApartmentModel? apartment,
  }) {
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: buildingController,
                              decoration: const InputDecoration(
                                labelText: 'Tòa nhà (Block)',
                                prefixIcon: Icon(Icons.business_outlined),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Bắt buộc'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 12),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
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
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(formatErrorMessage(e)),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteApartment(
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
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Expanded(child: Text('Xác nhận xóa')),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa căn hộ ${apt.code}? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await ref
                    .read(managementRepositoryProvider)
                    .deleteApartment(apt.id);
                ref.invalidate(apartmentsProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(formatErrorMessage(e)),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa căn hộ'),
          ),
        ],
      ),
    );
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
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDownloadTemplateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chọn định dạng file mẫu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'File mẫu bao gồm các cột chuẩn hóa: Mã Căn Hộ (*), Diện Tích (m2) (*), Trạng Thái Trống.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.table_view, color: AppTheme.success),
              ),
              title: const Text(
                'File mẫu Excel (.xlsx)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Phù hợp cho Microsoft Excel hoặc WPS'),
              onTap: () {
                Navigator.pop(ctx);
                _downloadApartmentTemplate(context, isCsv: false);
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.description, color: AppTheme.primary),
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
                _downloadApartmentTemplate(context, isCsv: true);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
