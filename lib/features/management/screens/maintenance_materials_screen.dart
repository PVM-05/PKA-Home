import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/maintenance_material_model.dart';
import '../../../data/providers/material_provider.dart';

class MaintenanceMaterialsScreen extends ConsumerStatefulWidget {
  const MaintenanceMaterialsScreen({super.key});

  @override
  ConsumerState<MaintenanceMaterialsScreen> createState() => _MaintenanceMaterialsScreenState();
}

class _MaintenanceMaterialsScreenState extends ConsumerState<MaintenanceMaterialsScreen> {
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
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text('Nhập kho: ${material.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hiện có: ${material.stockQuantity} ${material.unit}'),
                  const SizedBox(height: 12),
                  const Text('Số lượng nhập thêm:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: adjustQuantity > 1 ? () => setDialogState(() => adjustQuantity--) : null,
                      ),
                      Text('$adjustQuantity ${material.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setDialogState(() => adjustQuantity++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tồn kho sau khi nhập: ${material.stockQuantity + adjustQuantity} ${material.unit}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final repo = ref.read(materialRepositoryProvider);
                    await repo.updateMaterialStock(
                      materialId: material.id,
                      newStock: material.stockQuantity + adjustQuantity,
                    );
                    ref.invalidate(maintenanceMaterialsProvider);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã nhập thêm $adjustQuantity ${material.unit} cho ${material.name}'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                  child: const Text('Xác nhận nhập kho'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateMaterialDialog() {
    final codeCtrl = TextEditingController(text: 'MAT-${DateTime.now().millisecondsSinceEpoch % 10000}');
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
                    TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Mã vật tư *')),
                    const SizedBox(height: 8),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên vật tư *')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Chuyên môn / Phân loại'),
                      items: const [
                        DropdownMenuItem(value: 'electrical', child: Text('Điện')),
                        DropdownMenuItem(value: 'plumbing', child: Text('Nước')),
                        DropdownMenuItem(value: 'construction', child: Text('Xây dựng / Nội thất')),
                        DropdownMenuItem(value: 'elevator', child: Text('Thang máy')),
                        DropdownMenuItem(value: 'fire_safety', child: Text('PCCC & An toàn')),
                        DropdownMenuItem(value: 'other', child: Text('Khác')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Đơn vị tính'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Đơn giá (đ)'))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tồn ban đầu'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: minStockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mức cảnh báo'))),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
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
                        unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'cái',
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

    return Scaffold(
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
            filtered = filtered.where((m) => m.category == _selectedCategory).toList();
          }
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((m) =>
                m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                m.code.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          }

          return Column(
            children: [
              // Thanh KPI Kho vật tư
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tổng loại vật tư', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text('${allMaterials.length} mã hàng', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lowStockCount > 0 ? AppTheme.warning.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: lowStockCount > 0 ? AppTheme.warning.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cảnh báo sắp hết', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text('$lowStockCount mã cần nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: lowStockCount > 0 ? Colors.orange.shade800 : Colors.green)),
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
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }))
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    ? const Center(child: Text('Không tìm thấy vật tư phù hợp trong kho'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final mat = filtered[index];
                          return AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: mat.isLowStock
                                        ? AppTheme.warning.withValues(alpha: 0.15)
                                        : AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    mat.isLowStock ? Icons.warning_amber_rounded : Icons.build_outlined,
                                    color: mat.isLowStock ? Colors.orange.shade800 : AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(mat.code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(mat.categoryDisplayName, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(mat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Đơn giá: ${mat.priceFormatted}/${mat.unit}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: mat.isLowStock
                                            ? AppTheme.error.withValues(alpha: 0.1)
                                            : Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Tồn: ${mat.stockQuantity} ${mat.unit}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: mat.isLowStock ? AppTheme.error : Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _showAdjustStockDialog(mat),
                                      child: const Text(
                                        '+ Nhập kho',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
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
          );
        },
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
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}
