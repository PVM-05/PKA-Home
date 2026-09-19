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

class ApartmentManagementScreen extends ConsumerStatefulWidget {
  const ApartmentManagementScreen({super.key});

  @override
  ConsumerState<ApartmentManagementScreen> createState() => _ApartmentManagementScreenState();
}

class _ApartmentManagementScreenState extends ConsumerState<ApartmentManagementScreen> {
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
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Chuyển sang danh sách' : 'Chuyển sang dạng lưới',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: apartmentsAsync.when(
        data: (allApartments) {
          if (allApartments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apartment_outlined,
                    size: 64,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có dữ liệu căn hộ trong hệ thống',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
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
              .where((a) => _selectedBuilding == null || a.buildingCode.toUpperCase() == _selectedBuilding)
              .map((a) => a.floorNumber)
              .toSet()
              .toList()
            ..sort();

          // 3. Lọc danh sách căn hộ theo các tiêu chí
          final filteredApartments = allApartments.where((apt) {
            // Lọc theo tìm kiếm mã căn hộ
            if (_searchQuery.isNotEmpty) {
              if (!apt.code.toLowerCase().contains(_searchQuery.toLowerCase())) {
                return false;
              }
            }

            // Lọc theo Tòa nhà
            if (_selectedBuilding != null && apt.buildingCode.toUpperCase() != _selectedBuilding) {
              return false;
            }

            // Lọc theo Tầng
            if (_selectedFloor != null && apt.floorNumber != _selectedFloor) {
              return false;
            }

            // Lọc theo Trạng thái
            if (_statusFilter == 'empty' && !apt.isEmpty) return false;
            if (_statusFilter == 'occupied' && apt.isEmpty) return false;

            return true;
          }).toList()
            ..sort((a, b) => a.code.compareTo(b.code));

          final emptyCount = allApartments.where((a) => a.isEmpty).length;
          final occupiedCount = allApartments.where((a) => !a.isEmpty).length;

          return Column(
            children: [
              // Khu vực bộ lọc phân cấp (Header Control Panel)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh tìm kiếm
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo mã căn hộ (VD: A0110, B0502)...',
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                    const SizedBox(height: 12),

                    // Cấp 1: Chọn Tòa nhà (Block)
                    Row(
                      children: [
                        const Text(
                          'Tòa nhà:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
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
                                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedBuilding = selected ? b : null;
                                          _selectedFloor = null; // reset tầng khi đổi tòa
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
                    const SizedBox(height: 8),

                    // Cấp 2: Chọn Số Tầng (Floors)
                    if (floors.isNotEmpty) ...[
                      Row(
                        children: [
                          const Text(
                            'Số tầng: ',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: ChoiceChip(
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
                                        label: Text(floorLabel),
                                        selected: isSelected,
                                        selectedColor: AppTheme.secondary,
                                        labelStyle: TextStyle(
                                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedFloor = selected ? floor : null;
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
                      const SizedBox(height: 8),
                    ],

                    // Cấp 3: Lọc trạng thái (Tất cả / Trống / Đã có chủ)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip('all', 'Tất cả (${allApartments.length})', null),
                          const SizedBox(width: 8),
                          _buildStatusChip('empty', 'Còn trống ($emptyCount)', AppStatusColors.paid),
                          const SizedBox(width: 8),
                          _buildStatusChip('occupied', 'Đã có chủ ($occupiedCount)', AppTheme.primary),
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
                      ? ListView(
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
                                    Text(
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
                        )
                      : _isGridView
                          ? _buildGridView(filteredApartments)
                          : _buildListView(filteredApartments),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(formatErrorMessage(e), style: const TextStyle(color: AppTheme.error)),
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
      side: BorderSide(
        color: isSelected ? color : Colors.grey.shade300,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = status);
        }
      },
    );
  }

  Widget _buildGridView(List<ApartmentModel> apartments) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 1.12,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: apartments.length,
      itemBuilder: (context, index) {
        final apt = apartments[index];
        final statusColor = apt.isEmpty ? AppStatusColors.paid : AppTheme.primary;
        final statusText = apt.isEmpty ? 'Còn trống' : 'Đã có chủ';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: apt.isEmpty ? Colors.grey.shade200 : AppTheme.primary.withValues(alpha: 0.25),
              width: apt.isEmpty ? 1 : 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showApartmentDetailsModal(context, ref, apt),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          apt.code,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: statusColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.square_foot, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${apt.area ?? 0} m²',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.layers_outlined, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Tòa ${apt.buildingCode} - Tầng ${apt.floorNumber.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => _showApartmentDialog(context, ref, apartment: apt),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _deleteApartment(context, ref, apt),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
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
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: apartments.length,
      itemBuilder: (context, index) {
        final apt = apartments[index];
        final statusColor = apt.isEmpty ? AppStatusColors.paid : AppTheme.primary;
        final statusText = apt.isEmpty ? 'Còn trống' : 'Đã có chủ';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            onTap: () => _showApartmentDetailsModal(context, ref, apt),
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(
                apt.isEmpty ? Icons.apartment_outlined : Icons.home,
                color: statusColor,
              ),
            ),
            title: Row(
              children: [
                Text(
                  'Căn hộ ${apt.code}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Tòa ${apt.buildingCode} • Tầng ${apt.floorNumber.toString().padLeft(2, '0')} • Diện tích: ${apt.area ?? 0} m²',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                  tooltip: 'Sửa thông tin',
                  onPressed: () => _showApartmentDialog(context, ref, apartment: apt),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  tooltip: 'Xóa căn hộ',
                  onPressed: () => _deleteApartment(context, ref, apt),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showApartmentDetailsModal(BuildContext context, WidgetRef ref, ApartmentModel apt) async {
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
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

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
                          const Icon(Icons.domain, color: AppTheme.primary, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            'Chi tiết Căn hộ ${apt.code}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: apt.isEmpty
                              ? AppStatusColors.paid.withValues(alpha: 0.15)
                              : AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          apt.isEmpty ? 'Còn trống' : 'Đã có chủ',
                          style: TextStyle(
                            color: apt.isEmpty ? AppStatusColors.paid : AppTheme.primary,
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
                        child: _buildDetailTile('Tòa nhà', 'Tòa ${apt.buildingCode}', Icons.apartment),
                      ),
                      Expanded(
                        child: _buildDetailTile('Số tầng', 'Tầng ${apt.floorNumber}', Icons.layers),
                      ),
                      Expanded(
                        child: _buildDetailTile('Diện tích', '${apt.area ?? 0} m²', Icons.square_foot),
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
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (residents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Chưa có cư dân nào liên kết với căn hộ này.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else
                    ...residents.map((r) {
                      final user = r['users'] as Map<String, dynamic>? ?? {};
                      final role = r['relation_role'] == 'owner' ? 'Chủ hộ' : 'Người thuê / Ở cùng';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.person, size: 18),
                        ),
                        title: Text(user['full_name'] ?? 'Không tên', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('SĐT: ${user['phone'] ?? 'Chưa cập nhật'} • $role'),
                      );
                    }),
                  const SizedBox(height: 16),
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
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  void _showApartmentDialog(BuildContext context, WidgetRef ref, {ApartmentModel? apartment}) {
    final isEditing = apartment != null;
    final codeController = TextEditingController(text: apartment?.code ?? '');
    final areaController = TextEditingController(text: apartment?.area?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEditing ? 'Cập nhật Căn hộ' : 'Thêm Căn hộ mới'),
              content: Form(
                key: formKey,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;

                          setDialogState(() => isSaving = true);
                          final code = codeController.text.trim();
                          final area = double.parse(areaController.text.trim());

                          final repo = ref.read(managementRepositoryProvider);
                          try {
                            if (isEditing) {
                              await repo.updateApartment(apartment.id, code, area);
                            } else {
                              await repo.createApartment(code, area);
                            }
                            ref.invalidate(apartmentsProvider);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

  void _deleteApartment(BuildContext context, WidgetRef ref, ApartmentModel apt) {
    if (!apt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa căn hộ đã có cư dân sinh sống! Vui lòng hủy liên kết cư dân trước.'),
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
            Text('Xác nhận xóa'),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn xóa căn hộ ${apt.code}? Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await ref.read(managementRepositoryProvider).deleteApartment(apt.id);
                ref.invalidate(apartmentsProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
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
}
