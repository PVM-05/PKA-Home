import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/visitor_pass_model.dart';
import '../../../data/providers/front_desk_provider.dart';

class CreateVisitorPassSheet extends ConsumerStatefulWidget {
  final String apartmentId;
  final String hostUserId;
  final ValueChanged<VisitorPassModel>? onPassCreated;

  const CreateVisitorPassSheet({
    super.key,
    required this.apartmentId,
    required this.hostUserId,
    this.onPassCreated,
  });

  @override
  ConsumerState<CreateVisitorPassSheet> createState() => _CreateVisitorPassSheetState();
}

class _CreateVisitorPassSheetState extends ConsumerState<CreateVisitorPassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  final _noteController = TextEditingController();

  String _vehicleType = 'none';
  int _visitorCount = 1;
  String _purpose = 'visit';
  DateTime _expectedArrival = DateTime.now().add(const Duration(minutes: 30));
  DateTime _expectedDeparture = DateTime.now().add(const Duration(hours: 4));
  bool _isLoading = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isArrival}) async {
    final initialDate = isArrival ? _expectedArrival : _expectedDeparture;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: isArrival ? 'Chọn ngày khách đến' : 'Chọn ngày dự kiến rời đi',
      cancelText: 'Hủy',
      confirmText: 'Chọn giờ',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: isArrival ? 'Chọn giờ khách đến' : 'Chọn giờ dự kiến rời đi',
      cancelText: 'Hủy',
      confirmText: 'Xác nhận',
    );
    if (pickedTime == null || !mounted) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isArrival) {
        _expectedArrival = newDateTime;
        if (_expectedDeparture.isBefore(_expectedArrival)) {
          _expectedDeparture = _expectedArrival.add(const Duration(hours: 4));
        }
      } else {
        _expectedDeparture = newDateTime;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(frontDeskRepositoryProvider);
      final newPass = await repo.createVisitorPass(
        apartmentId: widget.apartmentId,
        hostUserId: widget.hostUserId,
        visitorName: _nameController.text.trim(),
        visitorPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        licensePlate: _plateController.text.trim().isEmpty ? null : _plateController.text.trim(),
        vehicleType: _vehicleType,
        visitorCount: _visitorCount,
        expectedArrival: _expectedArrival,
        expectedDeparture: _expectedDeparture,
        purpose: _purpose,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      // Invalidate provider để cập nhật danh sách
      ref.invalidate(residentVisitorPassesProvider(widget.apartmentId));
      ref.invalidate(frontDeskStatsProvider);

      if (mounted) {
        Navigator.pop(context);
        widget.onPassCreated?.call(newPass);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tạo vé khách: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thanh kéo tiêu đề
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Đón Khách Viếng Thăm Mới',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Họ tên khách
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên khách *',
                  hintText: 'Ví dụ: Nguyễn Văn A',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập họ tên khách viếng thăm';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Số điện thoại & Phương tiện
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: '09xx xxx xxx',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _vehicleType,
                      decoration: const InputDecoration(
                        labelText: 'Phương tiện',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('Đi bộ')),
                        DropdownMenuItem(value: 'motorcycle', child: Text('Xe máy')),
                        DropdownMenuItem(value: 'car', child: Text('Ô tô')),
                      ],
                      onChanged: (val) => setState(() => _vehicleType = val ?? 'none'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Biển số xe & Số lượng người
              Row(
                children: [
                  if (_vehicleType != 'none') ...[
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Biển số xe',
                          hintText: 'Ví dụ: 30A-999.88',
                          prefixIcon: Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _visitorCount,
                      decoration: const InputDecoration(
                        labelText: 'Số khách',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        10,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1} người'),
                        ),
                      ),
                      onChanged: (val) => setState(() => _visitorCount = val ?? 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mục đích viếng thăm
              DropdownButtonFormField<String>(
                initialValue: _purpose,
                decoration: const InputDecoration(
                  labelText: 'Mục đích viếng thăm',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'visit', child: Text('Thăm người thân, bạn bè')),
                  DropdownMenuItem(value: 'delivery', child: Text('Giao hàng tận cửa')),
                  DropdownMenuItem(value: 'repair', child: Text('Thợ sửa chữa, thi công nội thất')),
                  DropdownMenuItem(value: 'other', child: Text('Mục đích khác')),
                ],
                onChanged: (val) => setState(() => _purpose = val ?? 'visit'),
              ),
              const SizedBox(height: 12),

              // Thời gian dự kiến đến
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: const Icon(Icons.event_available_outlined, color: AppTheme.primary),
                title: const Text('Dự kiến đến', style: TextStyle(fontSize: 13, color: Colors.grey)),
                subtitle: Text(
                  _dateFormat.format(_expectedArrival),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickDateTime(isArrival: true),
              ),
              const SizedBox(height: 12),

              // Ghi chú
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú cho bảo vệ (nếu có)',
                  hintText: 'Nhắn nhủ hướng dẫn lối vào hoặc đăng ký thang máy...',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Nút Tạo vé
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_rounded),
                label: Text(
                  _isLoading ? 'Đang tạo vé...' : 'Tạo Mã Vé & QR Đón Khách',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

