import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/building_equipment_model.dart';
import '../../../data/providers/equipment_provider.dart';

/// Hộp thoại Thêm mới hoặc Cập nhật Hồ sơ thiết bị kỹ thuật
class EquipmentFormDialog extends ConsumerStatefulWidget {
  final BuildingEquipmentModel? equipment;

  const EquipmentFormDialog({super.key, this.equipment});

  @override
  ConsumerState<EquipmentFormDialog> createState() => _EquipmentFormDialogState();
}

class _EquipmentFormDialogState extends ConsumerState<EquipmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _intervalController;
  late final TextEditingController _specController;

  String _selectedCategory = 'elevator';
  String _selectedBuilding = 'Tòa A';
  String _selectedStatus = 'operational';
  bool _isLoading = false;

  final _categories = const [
    {'value': 'elevator', 'label': 'Thang máy'},
    {'value': 'fire_safety', 'label': 'Hệ thống PCCC'},
    {'value': 'water_pump', 'label': 'Máy bơm nước'},
    {'value': 'generator', 'label': 'Máy phát điện'},
    {'value': 'electrical', 'label': 'Hệ thống điện'},
    {'value': 'hvac', 'label': 'Hệ thống thông gió / HVAC'},
    {'value': 'other', 'label': 'Thiết bị khác'},
  ];

  final _buildings = const ['Tòa A', 'Tòa B', 'Tòa C', 'Toàn khu'];

  final _statuses = const [
    {'value': 'operational', 'label': 'Hoạt động tốt'},
    {'value': 'under_maintenance', 'label': 'Đang bảo dưỡng'},
    {'value': 'degraded', 'label': 'Cảnh báo hư hỏng'},
    {'value': 'inactive', 'label': 'Ngừng hoạt động'},
  ];

  @override
  void initState() {
    super.initState();
    final eq = widget.equipment;
    _codeController = TextEditingController(text: eq?.code ?? '');
    _nameController = TextEditingController(text: eq?.name ?? '');
    _locationController = TextEditingController(text: eq?.location ?? '');
    _intervalController =
        TextEditingController(text: (eq?.maintenanceIntervalDays ?? 30).toString());
    _specController = TextEditingController(text: eq?.specifications ?? '');

    if (eq != null) {
      _selectedCategory = eq.category;
      _selectedBuilding = eq.building;
      _selectedStatus = eq.status;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _intervalController.dispose();
    _specController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final interval = int.tryParse(_intervalController.text.trim()) ?? 30;
    final payload = <String, dynamic>{
      'code': _codeController.text.trim(),
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'building': _selectedBuilding,
      'location': _locationController.text.trim(),
      'maintenance_interval_days': interval,
      'status': _selectedStatus,
      'specifications': _specController.text.trim().isEmpty ? null : _specController.text.trim(),
    };

    try {
      final repo = ref.read(equipmentRepositoryProvider);
      if (widget.equipment == null) {
        // Thiết bị mới: gán ngày bảo dưỡng đầu tiên là sau chu kỳ
        payload['next_maintenance_date'] =
            DateTime.now().add(Duration(days: interval)).toIso8601String();
        await repo.createEquipment(payload);
      } else {
        await repo.updateEquipment(widget.equipment!.id, payload);
      }

      ref.invalidate(equipmentListProvider);
      ref.invalidate(upcomingMaintenanceEquipmentsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.equipment == null
                  ? 'Đã thêm thiết bị mới thành công!'
                  : 'Đã cập nhật thông tin thiết bị!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.equipment != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      isEdit ? Icons.edit_note : Icons.add_circle_outline,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEdit ? 'Chỉnh sửa thiết bị' : 'Thêm thiết bị mới',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _codeController,
                                decoration: const InputDecoration(
                                  labelText: 'Mã thiết bị *',
                                  hintText: 'VD: TM-A01',
                                ),
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty) ? 'Bắt buộc' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Phân loại',
                                ),
                                items: _categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c['value'],
                                        child: Text(c['label']!),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCategory = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên thiết bị *',
                            hintText: 'VD: Thang máy chở khách A1',
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedBuilding,
                                decoration: const InputDecoration(labelText: 'Tòa nhà'),
                                items: _buildings
                                    .map(
                                      (b) => DropdownMenuItem(value: b, child: Text(b)),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedBuilding = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _intervalController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Chu kỳ bảo trì (ngày) *',
                                  suffixText: 'ngày',
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Bắt buộc';
                                  final n = int.tryParse(val.trim());
                                  if (n == null || n <= 0) return 'Số ngày > 0';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Vị trí lắp đặt *',
                            hintText: 'VD: Trục A, Tầng hầm B2...',
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty) ? 'Vui lòng nhập vị trí' : null,
                        ),
                        const SizedBox(height: 16),
                        if (isEdit) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: const InputDecoration(labelText: 'Trạng thái hoạt động'),
                            items: _statuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s['value'],
                                    child: Text(s['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _specController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Thông số kỹ thuật / Hãng sản xuất',
                            hintText: 'VD: Hãng Mitsubishi, Tải trọng 1000kg, Công suất 15kW...',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEdit ? 'Lưu thay đổi' : 'Thêm thiết bị'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
