import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/maintenance_material_model.dart';
import '../../../data/providers/building_provider.dart';
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
    final reasonCtrl = TextEditingController(
      text: 'Nhập bổ sung kho từ nhà cung cấp',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final successColor = AppTheme.getSemanticSuccess(dialogCtx);
            final warningColor = AppTheme.getSemanticWarning(dialogCtx);
            final errorColor = AppTheme.getSemanticError(dialogCtx);

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
                    Text(
                      'Hiện tồn: ${material.stockQuantity} ${material.unit}',
                      style: dialogCtx.bodyMedium?.tabularFigures(),
                    ),
                    AppSpacing.h12,
                    Text(
                      'Loại biến động kho:',
                      style: dialogCtx.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.h6,
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                    AppSpacing.h12,
                    Text(
                      isImport ? 'Số lượng nhập thêm:' : 'Số lượng xuất giảm:',
                      style: dialogCtx.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.h8,
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
                          style: dialogCtx.titleMedium
                              ?.tabularFigures()
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () =>
                              setDialogState(() => adjustQuantity++),
                        ),
                      ],
                    ),
                    AppSpacing.h12,
                    TextField(
                      controller: reasonCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Lý do điều chỉnh (Kiểm toán) *',
                        hintText: 'Nhập căn cứ/chứng từ/lý do điều chỉnh...',
                      ),
                    ),
                    AppSpacing.h12,
                    Container(
                      padding: AppSpacing.p8,
                      decoration: BoxDecoration(
                        color: isValid
                            ? (isImport
                                  ? successColor.withValues(alpha: 0.1)
                                  : warningColor.withValues(alpha: 0.1))
                            : errorColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.r6,
                      ),
                      child: Text(
                        isValid
                            ? 'Tồn kho sau khi điều chỉnh: $resultingStock ${material.unit}'
                            : 'Lỗi: Tồn kho sau điều chỉnh không thể âm ($resultingStock < 0)',
                        style: dialogCtx.labelMedium?.tabularFigures().copyWith(
                          color: isValid
                              ? (isImport ? successColor : warningColor)
                              : errorColor,
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
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
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
                    AppSpacing.h8,
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên vật tư *',
                      ),
                    ),
                    AppSpacing.h8,
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
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
                    AppSpacing.h8,
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
                        AppSpacing.w8,
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
                    AppSpacing.h8,
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
                        AppSpacing.w8,
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
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final bldId = ref.read(activeBuildingIdProvider);
                    Navigator.pop(ctx);
                    try {
                      final repo = ref.read(materialRepositoryProvider);
                      await repo.createMaterial(
                        MaintenanceMaterialModel(
                          id: '',
                          buildingId: bldId.isNotEmpty ? bldId : null,
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
                      if (mounted) {
                        AppSnackBar.showSuccess(
                          context,
                          'Đã thêm vật tư mới vào kho!',
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        AppSnackBar.showError(context, formatErrorMessage(e));
                      }
                    }
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
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
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
          loading: () => ListView(
            padding: AppSpacing.p16,
            children: [
              AppSkeletonShimmer.cardList(count: 3, itemHeight: 112),
            ],
          ),
          error: (err, _) => ListView(
            padding: AppSpacing.p16,
            children: [
              AppErrorCard(
                error: err,
                onRetry: () =>
                    ref.invalidate(maintenanceMaterialsProvider(null)),
              ),
            ],
          ),
          data: (allMaterials) {
            final lowStockCount = allMaterials
                .where((m) => m.isLowStock)
                .length;

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
                        m.code.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
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
                      padding: AppSpacing.p16,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: AppRadius.r12,
                                border: Border.all(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tổng loại vật tư',
                                    style: context.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  AppSpacing.h4,
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${allMaterials.length} mã hàng',
                                      style: context.titleMedium
                                          ?.tabularFigures()
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AppSpacing.w12,
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: lowStockCount > 0
                                    ? warningColor.withValues(alpha: 0.1)
                                    : successColor.withValues(alpha: 0.1),
                                borderRadius: AppRadius.r12,
                                border: Border.all(
                                  color: lowStockCount > 0
                                      ? warningColor.withValues(alpha: 0.3)
                                      : successColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cảnh báo sắp hết',
                                    style: context.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  AppSpacing.h4,
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '$lowStockCount mã cần nhập',
                                      style: context.titleMedium
                                          ?.tabularFigures()
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: lowStockCount > 0
                                                ? warningColor
                                                : successColor,
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
                                  tooltip: 'Xóa tìm kiếm',
                                  onPressed: () => setState(() {
                                    _searchCtrl.clear();
                                    _searchQuery = '';
                                  }),
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.r12,
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                    AppSpacing.h12,

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildCategoryFilterChip('all', 'Tất cả'),
                          _buildCategoryFilterChip('electrical', 'Điện'),
                          _buildCategoryFilterChip('plumbing', 'Nước'),
                          _buildCategoryFilterChip(
                            'construction',
                            'Nội thất/XD',
                          ),
                          _buildCategoryFilterChip('elevator', 'Thang máy'),
                          _buildCategoryFilterChip('fire_safety', 'PCCC'),
                        ],
                      ),
                    ),
                    AppSpacing.h12,

                    // Danh sách vật tư
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => ref.refresh(
                          maintenanceMaterialsProvider(null).future,
                        ),
                        child: filtered.isEmpty
                            ? ListView(
                                padding: AppSpacing.p16,
                                children: const [
                                  AppEmptyState(
                                    icon: Icons.inventory_2_outlined,
                                    title: 'Không có vật tư phù hợp',
                                    description:
                                        'Không tìm thấy vật tư phù hợp trong kho.',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: AppSpacing.p16,
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => AppSpacing.h12,
                                itemBuilder: (context, index) {
                                  final mat = filtered[index];
                                  return AppCard(
                                    padding: AppSpacing.p12,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Dòng 1: Mã vật tư + Chuyên mục
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius: AppRadius.r4,
                                              ),
                                              child: Text(
                                                mat.code,
                                                style: context.labelSmall
                                                    ?.tabularFigures()
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                            AppSpacing.w8,
                                            Expanded(
                                              child: Text(
                                                mat.categoryDisplayName,
                                                style: context.labelSmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (mat.isLowStock) ...[
                                              AppSpacing.w6,
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                size: 16,
                                                color: warningColor,
                                              ),
                                            ],
                                          ],
                                        ),
                                        AppSpacing.h8,

                                        // Dòng 2: Tên vật tư
                                        Text(
                                          mat.name,
                                          style: context.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        AppSpacing.h6,

                                        // Dòng 3: Đơn giá
                                        Text(
                                          'Đơn giá: ${mat.priceFormatted}/${mat.unit}',
                                          style: context.bodySmall
                                              ?.tabularFigures()
                                              .copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        AppSpacing.h12,

                                        // Dòng 4: Tồn kho & Nút Nhập kho
                                        Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: mat.isLowStock
                                                    ? errorColor.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : successColor.withValues(
                                                        alpha: 0.1,
                                                      ),
                                                borderRadius: AppRadius.r6,
                                              ),
                                              child: Text(
                                                'Tồn: ${mat.stockQuantity} ${mat.unit}',
                                                style: context.labelSmall
                                                    ?.tabularFigures()
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: mat.isLowStock
                                                          ? errorColor
                                                          : successColor,
                                                    ),
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                minimumSize: const Size(0, 40),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                side: BorderSide(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.35),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _showAdjustStockDialog(mat),
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                                size: 16,
                                              ),
                                              label: const Text('Nhập kho'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = key),
        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
        checkmarkColor: colorScheme.primary,
        labelStyle: context.labelMedium?.copyWith(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
