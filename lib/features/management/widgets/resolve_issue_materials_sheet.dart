import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/maintenance_material_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/material_provider.dart';

class ResolveIssueMaterialsSheet extends ConsumerStatefulWidget {
  final IssueModel issue;
  final VoidCallback? onResolved;

  const ResolveIssueMaterialsSheet({
    super.key,
    required this.issue,
    this.onResolved,
  });

  @override
  ConsumerState<ResolveIssueMaterialsSheet> createState() => _ResolveIssueMaterialsSheetState();
}

class _SelectedMaterialEntry {
  MaintenanceMaterialModel material;
  int quantity;
  bool isChargeable;
  String? note;

  _SelectedMaterialEntry({
    required this.material,
    this.quantity = 1,
    this.isChargeable = false,
    this.note,
  });

  double get totalAmount => material.unitPrice * quantity;
}

class _ResolveIssueMaterialsSheetState extends ConsumerState<ResolveIssueMaterialsSheet> {
  final List<File> _proofFiles = [];
  final List<_SelectedMaterialEntry> _selectedMaterials = [];
  final ImagePicker _picker = ImagePicker();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _pickProofImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 75);
      if (picked.isNotEmpty) {
        setState(() {
          _proofFiles.addAll(picked.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Không thể chọn ảnh: $e');
    }
  }

  void _addMaterialDialog(List<MaintenanceMaterialModel> availableMaterials) {
    if (availableMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kho vật tư hiện chưa có dữ liệu')),
      );
      return;
    }

    MaintenanceMaterialModel selected = availableMaterials.first;
    int qty = 1;
    bool isChargeable = true; // Mặc định trong căn hộ cư dân là tính phí
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm vật tư xuất kho'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chọn vật tư:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<MaintenanceMaterialModel>(
                      initialValue: selected,
                      isExpanded: true,
                      items: availableMaterials.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            '${m.name} (Còn ${m.stockQuantity} ${m.unit})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selected = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Đơn giá: ${selected.priceFormatted}/${selected.unit}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Số lượng: ', style: TextStyle(fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: qty > 1 ? () => setDialogState(() => qty--) : null,
                        ),
                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: qty < selected.stockQuantity ? () => setDialogState(() => qty++) : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tính phí vào hóa đơn cư dân', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Bật nếu là thiết bị sở hữu riêng của căn hộ', style: TextStyle(fontSize: 11)),
                      value: isChargeable,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppTheme.primary,
                      onChanged: (val) => setDialogState(() => isChargeable = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú sử dụng (tùy chọn)',
                        hintText: 'VD: Thay bóng đèn hành lang căn hộ',
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
                  onPressed: () {
                    setState(() {
                      _selectedMaterials.add(
                        _SelectedMaterialEntry(
                          material: selected,
                          quantity: qty,
                          isChargeable: isChargeable,
                          note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Thêm vào danh sách'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitResolution() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final staffId = widget.issue.assignedStaffId ?? 'staff-admin';

      // 1. Ghi nhận vật tư xuất kho nếu có
      if (_selectedMaterials.isNotEmpty) {
        final materialsPayload = _selectedMaterials.map((entry) {
          return {
            'material_id': entry.material.id,
            'quantity': entry.quantity,
            'is_chargeable': entry.isChargeable,
            'note': entry.note,
          };
        }).toList();

        await ref.read(materialRepositoryProvider).recordMaterialsUsage(
          issueId: widget.issue.id,
          materials: materialsPayload,
          staffId: staffId,
        );
      }

      // 2. Nghiệm thu sự cố có ảnh hoặc không ảnh
      if (_proofFiles.isNotEmpty) {
        await ref.read(managementRepositoryProvider).resolveIssueWithProof(
          issueId: widget.issue.id,
          staffId: staffId,
          proofFiles: _proofFiles,
        );
      } else {
        await ref.read(managementRepositoryProvider).updateIssueStatus(
          widget.issue.id,
          'resolved',
          assignedStaffId: staffId,
        );
      }

      ref.invalidate(issueMaterialsProvider(widget.issue.id));
      ref.invalidate(maintenanceMaterialsProvider);
      ref.invalidate(issueSlaStatsProvider);

      if (mounted) {
        Navigator.pop(context);
        widget.onResolved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hoàn tất nghiệm thu và xuất kho vật tư thành công!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(maintenanceMaterialsProvider(null));

    double totalChargeableAmount = 0;
    for (final m in _selectedMaterials) {
      if (m.isChargeable) totalChargeableAmount += m.totalAmount;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nghiệm Thu & Xuất Kho Vật Tư',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Căn hộ: ${widget.issue.apartment?.code ?? "Chung"} • Sự cố #${widget.issue.id.substring(0, 6)}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Ảnh minh chứng nghiệm thu
              const Text(
                '1. Ảnh minh chứng sau sửa chữa (Ảnh Nghiệm thu)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (_proofFiles.isEmpty)
                OutlinedButton.icon(
                  onPressed: _pickProofImages,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Chọn ảnh nghiệm thu từ máy'),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._proofFiles.map((f) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(f, width: 80, height: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () => setState(() => _proofFiles.remove(f)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        )),
                    InkWell(
                      onTap: _pickProofImages,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // 2. Vật tư tiêu hao đã sử dụng
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '2. Vật tư tiêu hao sửa chữa',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  materialsAsync.when(
                    data: (mats) => TextButton.icon(
                      onPressed: () => _addMaterialDialog(mats),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Xuất vật tư'),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_selectedMaterials.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'Chưa có vật tư nào được xuất kho cho sự cố này.\nBấm "Xuất vật tư" nếu có thay thế linh kiện.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedMaterials.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = _selectedMaterials[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: entry.isChargeable
                            ? AppTheme.primary.withValues(alpha: 0.05)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: entry.isChargeable
                              ? AppTheme.primary.withValues(alpha: 0.3)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.material.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Số lượng: ${entry.quantity} ${entry.material.unit} • Đơn giá: ${entry.material.priceFormatted}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.isChargeable ? '• Tính phí căn hộ: ${_currencyFormat.format(entry.totalAmount)}' : '• Chi phí vận hành tòa nhà',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: entry.isChargeable ? AppTheme.primary : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                            onPressed: () => setState(() => _selectedMaterials.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (totalChargeableAmount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng tiền kết chuyển hóa đơn:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _currencyFormat.format(totalChargeableAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitResolution,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSubmitting ? 'Đang xử lý...' : 'Xác nhận Nghiệm thu & Hoàn tất'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
