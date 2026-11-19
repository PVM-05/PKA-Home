import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/maintenance_material_model.dart';
import '../../../data/providers/material_provider.dart';

class MaintenanceMaterialsScreen extends ConsumerStatefulWidget {
  const MaintenanceMaterialsScreen({super.key});

  @override
  ConsumerState<MaintenanceMaterialsScreen> createState() =>
      _MaintenanceMaterialsScreenState();
}

class _MaintenanceMaterialsScreenState
    extends ConsumerState<MaintenanceMaterialsScreen> {
  String _selectedCategory = 'all';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAdjustStockDialog(MaintenanceMaterialModel material) {
    int adjustQuantity = 10;
    bool isImport = true;
    final reasonCtrl =
        TextEditingController(text: 'Nhập bổ sung kho từ nhà cung cấp');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final delta = isImport ? adjustQuantity : -adjustQuantity;
            final resultingStock = material.stockQuantity + delta;
            final isValid = resultingStock >= 0 && adjustQuantity > 0;

            return AlertDialog(
              title: Text('Điều chỉnh kho: ${material.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hiện tồn: ${material.stockQuantity} ${material.unit}'),
                    const SizedBox(height: 12),
                    Text(
                      'Loại biến động kho:',
                      style: dialogCtx.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Nhập thêm'),
                          selected: isImport,
                          onSelected: (_) => setDialogState(() {
                            isImport = true;
                            if (reasonCtrl.text.isEmpty ||
                                reasonCtrl.text.startsWith('Hao hụt') ||
                                reasonCtrl.text.startsWith('Xuất')) {
                              reasonCtrl.text =
                                  'Nhập bổ sung kho từ nhà cung cấp';
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Xuất giảm / Hao hụt'),
                          selected: !isImport,
                          onSelected: (_) => setDialogState(() {
                            isImport = false;
                            if (reasonCtrl.text.isEmpty ||
                                reasonCtrl.text.startsWith('Nhập')) {
                              reasonCtrl.text =
                                  'Hao hụt / kiểm kê phát hiện sai lệch';
                            }
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isImport ? 'Số lượng nhập thêm:' : 'Số lượng xuất giảm:',
                      style: dialogCtx.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: adjustQuantity > 1
                              ? () => setDialogState(() => adjustQuantity--)
                              : null,
                        ),
                        Text(
                          '$adjustQuantity ${material.unit}',
                          style: dialogCtx.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setDialogState(() => adjustQuantity++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Lý do điều chỉnh (Kiểm toán) *',
                        hintText: 'Nhập căn cứ/chứng từ/lý do điều chỉnh...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isValid
                            ? (isImport
                                ? AppTheme.success.withValues(alpha: 0.1)
                                : AppTheme.warning.withValues(alpha: 0.1))
                            : AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isValid
                            ? 'Tồn kho sau khi điều chỉnh: $resultingStock ${material.unit}'
                            : 'Lỗi: Tồn kho sau điều chỉnh không thể âm ($resultingStock < 0)',
                        style: dialogCtx.labelMedium?.copyWith(
                          color: isValid
                              ? (isImport ? AppTheme.success : AppTheme.warning)
                              : AppTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: !isValid || reasonCtrl.text.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final reason = reasonCtrl.text.trim();
                          await runAction(
                            context,
                            () async {
                              final repo = ref.read(materialRepositoryProvider);
                              final res = await repo.adjustMaterialStockDelta(
                                materialId: material.id,
                                delta: delta,
                                reason: reason,
                              );
                              ref.invalidate(maintenanceMaterialsProvider);
                              return res['message']?.toString() ??
                                  'Đã điều chỉnh $delta ${material.unit} cho ${material.name}';
                            },
                            actionName: 'Điều chỉnh tồn kho vật tư',
                          );
                        },
                  child: const Text('Xác nhận điều chỉnh'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateMaterialDialog() {
    final codeCtrl = TextEditingController(
      text: 'MAT-${DateTime.now().millisecondsSinceEpoch % 10000}',
    );
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'cái');
    final priceCtrl = TextEditingController(text: '50000');
    final stockCtrl = TextEditingController(text: '20');
    final minStockCtrl = TextEditingController(text: '5');
    String category = 'electrical';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm Vật Tư Mới Vào Kho'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mã vật tư *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên vật tư *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Chuyên môn / Phân loại',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'electrical',
                          child: Text('Điện'),
                        ),
                        DropdownMenuItem(
                          value: 'plumbing',
                          child: Text('Nước'),
                        ),
                        DropdownMenuItem(
                          value: 'construction',
                          child: Text('Xây dựng / Nội thất'),
                        ),
                        DropdownMenuItem(
                          value: 'elevator',
                          child: Text('Thang máy'),
                        ),
                        DropdownMenuItem(
                          value: 'fire_safety',
                          child: Text('PCCC & An toàn'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Khác')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Đơn vị tính',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Đơn giá (đ)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tồn ban đầu',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: minStockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Mức cảnh báo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    final repo = ref.read(materialRepositoryProvider);
                    await repo.createMaterial(
                      MaintenanceMaterialModel(
                        id: 'mat-${DateTime.now().millisecondsSinceEpoch}',
                        code: codeCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        category: category,
                        unit: unitCtrl.text.trim().isNotEmpty
                            ? unitCtrl.text.trim()
                            : 'cái',
                        unitPrice: double.tryParse(priceCtrl.text) ?? 0.0,
                        stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                        minStockAlert: int.tryParse(minStockCtrl.text) ?? 5,
                        createdAt: DateTime.now(),
                      ),
                    );
                    ref.invalidate(maintenanceMaterialsProvider);
                  },
                  child: const Text('Lưu vật tư'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(maintenanceMaterialsProvider(null));

    return RoleGuard(
      permission: AppPermissions.materialsManagement,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Kho Vật Tư Kỹ Thuật'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Thêm vật tư mới',
            onPressed: _showCreateMaterialDialog,
          ),
        ],
      ),
      body: materialsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi tải kho: $err')),
        data: (allMaterials) {
          final lowStockCount = allMaterials.where((m) => m.isLowStock).length;

          var filtered = allMaterials;
          if (_selectedCategory != 'all') {
            filtered = filtered
                .where((m) => m.category == _selectedCategory)
                .toList();
          }
          if (_searchQuery.isNotEmpty) {
            filtered = filtered
                .where(
                  (m) =>
                      m.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      m.code.toLowerCase().contains(_searchQuery.toLowerCase()),
                )
                .toList();
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  // Thanh KPI Kho vật tư
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tổng loại vật tư',
                                  style: context.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${allMaterials.length} mã hàng',
                                    style: context.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: lowStockCount > 0
                                  ? AppTheme.warning.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: lowStockCount > 0
                                    ? AppTheme.warning.withValues(alpha: 0.3)
                                    : Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cảnh báo sắp hết',
                                  style: context.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '$lowStockCount mã cần nhập',
                                    style: context.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: lowStockCount > 0
                                          ? Colors.orange.shade800
                                          : Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Thanh tìm kiếm & lọc category
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm vật tư theo tên hoặc mã...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                }),
                              )
                            : null,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildCategoryFilterChip('all', 'Tất cả'),
                        _buildCategoryFilterChip('electrical', 'Điện'),
                        _buildCategoryFilterChip('plumbing', 'Nước'),
                        _buildCategoryFilterChip('construction', 'Nội thất/XD'),
                        _buildCategoryFilterChip('elevator', 'Thang máy'),
                        _buildCategoryFilterChip('fire_safety', 'PCCC'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Danh sách vật tư
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Không tìm thấy vật tư phù hợp trong kho'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final mat = filtered[index];
                              return AppCard(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Dòng 1: Mã vật tư + Chuyên mục
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            mat.code,
                                            style: context.labelSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            mat.categoryDisplayName,
                                            style: context.labelSmall?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (mat.isLowStock) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            size: 16,
                                            color: AppTheme.warning,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Dòng 2: Tên vật tư
                                    Text(
                                      mat.name,
                                      style: context.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),

                                    // Dòng 3: Đơn giá
                                    Text(
                                      'Đơn giá: ${mat.priceFormatted}/${mat.unit}',
                                      style: context.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),

                                    // Dòng 4: Tồn kho & Nút Nhập kho
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      runSpacing: 8,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: mat.isLowStock
                                                ? AppTheme.error.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.green.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Tồn: ${mat.stockQuantity} ${mat.unit}',
                                            style: context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: mat.isLowStock ? AppTheme.error : Colors.green.shade700),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              _showAdjustStockDialog(mat),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppTheme.primary.withValues(
                                                  alpha: 0.25,
                                                ),
                                              ),
                                            ),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 13,
                                                  color: AppTheme.primary,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Nhập kho',
                                                  style: context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildCategoryFilterChip(String key, String label) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedCategory = key),
        selectedColor: AppTheme.primary.withValues(alpha: 0.15),
        checkmarkColor: AppTheme.primary,
        labelStyle: context.labelMedium?.copyWith(
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
