import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/building_equipment_model.dart';
import '../../../data/providers/equipment_provider.dart';
import '../../../core/utils/error_formatter.dart';

/// Hộp thoại Lập phiếu bảo dưỡng / bảo trì thiết bị tòa nhà
class MaintenanceTaskFormDialog extends ConsumerStatefulWidget {
  final BuildingEquipmentModel? equipment;
  final List<BuildingEquipmentModel>? equipmentList;

  const MaintenanceTaskFormDialog({
    super.key,
    this.equipment,
    this.equipmentList,
  });

  @override
  ConsumerState<MaintenanceTaskFormDialog> createState() => _MaintenanceTaskFormDialogState();
}

class _MaintenanceTaskFormDialogState extends ConsumerState<MaintenanceTaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _vendorNameController;
  late final TextEditingController _vendorContactController;
  late final TextEditingController _costController;
  late final TextEditingController _interruptionNoteController;
  late final TextEditingController _notesController;

  String? _selectedEquipmentId;
  String _taskType = 'scheduled';
  DateTime _scheduledStart = DateTime.now().add(const Duration(hours: 1));
  DateTime _scheduledEnd = DateTime.now().add(const Duration(hours: 4));
  bool _affectsService = false;
  bool _isLoading = false;

  final _taskTypes = const [
    {'value': 'scheduled', 'label': 'Định kỳ'},
    {'value': 'unscheduled', 'label': 'Đột xuất / Sự cố'},
    {'value': 'inspection', 'label': 'Kiểm định an toàn'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId = widget.equipment?.id ??
        (widget.equipmentList != null && widget.equipmentList!.isNotEmpty
            ? widget.equipmentList!.first.id
            : null);

    final defaultTitle = widget.equipment != null
        ? 'Bảo dưỡng ${widget.equipment!.name} - Tháng ${DateTime.now().month}'
        : 'Phiếu bảo trì thiết bị';

    _titleController = TextEditingController(text: defaultTitle);
    _vendorNameController = TextEditingController();
    _vendorContactController = TextEditingController();
    _costController = TextEditingController(text: '0');
    _interruptionNoteController = TextEditingController(
      text: widget.equipment != null
          ? 'Tạm ngưng phục vụ ${widget.equipment!.name} trong thời gian bảo trì.'
          : '',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _vendorNameController.dispose();
    _vendorContactController.dispose();
    _costController.dispose();
    _interruptionNoteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _scheduledStart : _scheduledEnd;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _scheduledStart = picked;
        if (_scheduledEnd.isBefore(_scheduledStart)) {
          _scheduledEnd = _scheduledStart.add(const Duration(hours: 2));
        }
      } else {
        _scheduledEnd = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEquipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thiết bị'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final payload = <String, dynamic>{
      'equipment_id': _selectedEquipmentId,
      'title': _titleController.text.trim(),
      'task_type': _taskType,
      'scheduled_start': _scheduledStart.toIso8601String(),
      'scheduled_end': _scheduledEnd.toIso8601String(),
      'vendor_name': _vendorNameController.text.trim().isEmpty ? null : _vendorNameController.text.trim(),
      'vendor_contact': _vendorContactController.text.trim().isEmpty ? null : _vendorContactController.text.trim(),
      'cost': cost,
      'status': 'pending',
      'affects_service': _affectsService,
      'service_interruption_note':
          _affectsService && _interruptionNoteController.text.trim().isNotEmpty
              ? _interruptionNoteController.text.trim()
              : null,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    try {
      final repo = ref.read(equipmentRepositoryProvider);
      await repo.createMaintenanceTask(payload);

      ref.invalidate(equipmentTasksProvider);
      ref.invalidate(equipmentListProvider);
      ref.invalidate(upcomingMaintenanceEquipmentsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo phiếu bảo trì thành công!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e)),
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
    final dateFormat = DateFormat('HH:mm dd/MM/yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.build_circle_outlined, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lập phiếu bảo trì thiết bị',
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
                        // Thiết bị
                        if (widget.equipment != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.precision_manufacturing, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.equipment!.code} - ${widget.equipment!.name}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Vị trí: ${widget.equipment!.location} (${widget.equipment!.building})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (widget.equipmentList != null && widget.equipmentList!.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: _selectedEquipmentId,
                            decoration: const InputDecoration(labelText: 'Thiết bị cần bảo trì *'),
                            items: widget.equipmentList!
                                .map(
                                  (eq) => DropdownMenuItem(
                                    value: eq.id,
                                    child: Text('${eq.code} - ${eq.name} (${eq.building})'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedEquipmentId = val);
                            },
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Tiêu đề phiếu *',
                            hintText: 'VD: Bảo dưỡng định kỳ Thang máy A1',
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty) ? 'Vui lòng nhập tiêu đề' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _taskType,
                                decoration: const InputDecoration(labelText: 'Loại bảo trì'),
                                items: _taskTypes
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t['value'],
                                        child: Text(t['label']!),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _taskType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _costController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Chi phí (VNĐ)',
                                  suffixText: 'đ',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Thời gian dự kiến
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDateTime(isStart: true),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Bắt đầu dự kiến',
                                    prefixIcon: Icon(Icons.schedule, size: 20),
                                  ),
                                  child: Text(
                                    dateFormat.format(_scheduledStart),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDateTime(isStart: false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Kết thúc dự kiến',
                                    prefixIcon: Icon(Icons.event, size: 20),
                                  ),
                                  child: Text(
                                    dateFormat.format(_scheduledEnd),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _vendorNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Đơn vị / Nhà thầu',
                                  hintText: 'VD: Công ty Schindler',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _vendorContactController,
                                decoration: const InputDecoration(
                                  labelText: 'Hotline / Người liên hệ',
                                  hintText: 'VD: 0901234567',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Tạm dừng thiết bị (Ảnh hưởng cư dân)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Hệ thống sẽ thông báo tới cư dân của tòa nhà khi bắt đầu bảo trì.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          value: _affectsService,
                          onChanged: (val) => setState(() => _affectsService = val),
                        ),
                        if (_affectsService) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _interruptionNoteController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Nội dung thông báo tới cư dân',
                              hintText: 'VD: Tạm ngưng thang máy từ 09:00 - 11:30 để bảo trì cáp.',
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú kỹ thuật nội bộ',
                            hintText: 'Vật tư thay thế, phạm vi bảo dưỡng...',
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
                          : const Text('Lập phiếu'),
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
