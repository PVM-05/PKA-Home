import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/poll_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/community_provider.dart';

class CreatePollSheet extends ConsumerStatefulWidget {
  final ValueChanged<PollModel>? onPollCreated;

  const CreatePollSheet({super.key, this.onPollCreated});

  @override
  ConsumerState<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<CreatePollSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(text: 'Tán thành'),
    TextEditingController(text: 'Không tán thành'),
  ];

  String _category = 'general';
  String _voteWeightType = 'per_apartment';
  String _choiceType = 'single_choice';
  final double _minParticipationRate = 50.0;
  final double _requiredApprovalRate = 50.0;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuộc biểu quyết cần ít nhất 2 phương án')),
      );
      return;
    }
    setState(() {
      final c = _optionControllers.removeAt(index);
      c.dispose();
    });
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initialDate = isStart ? _startTime : _endTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: isStart ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Chọn giờ',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: isStart ? 'Chọn giờ bắt đầu' : 'Chọn giờ kết thúc',
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
      if (isStart) {
        _startTime = newDateTime;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(days: 7));
        }
      } else {
        _endTime = newDateTime;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final validOptions = _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập ít nhất 2 phương án hợp lệ')),
      );
      return;
    }

    final authUser = ref.read(authProvider).valueOrNull;
    final staffId = authUser?.id ?? 'usr-admin';

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final newPoll = await repo.createPoll(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        category: _category,
        voteWeightType: _voteWeightType,
        choiceType: _choiceType,
        minParticipationRate: _minParticipationRate,
        requiredApprovalRate: _requiredApprovalRate,
        startTime: _startTime,
        endTime: _endTime,
        options: validOptions,
        createdBy: staffId,
      );

      ref.invalidate(pollsProvider((status: null, apartmentId: null)));
      ref.invalidate(communityStatsProvider);

      if (mounted) {
        Navigator.pop(context);
        widget.onPollCreated?.call(newPoll);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo thành công cuộc biểu quyết: ${newPoll.pollCode}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tạo biểu quyết: $e'), backgroundColor: AppTheme.error),
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
                    child: const Icon(Icons.how_to_vote_rounded, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tạo Cuộc Biểu Quyết / Khảo Sát Mới',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tiêu đề
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề biểu quyết *',
                  hintText: 'Ví dụ: Lựa chọn đơn vị quản lý vận hành chung cư năm 2027',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề biểu quyết';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Chuyên mục & Trọng số
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Chuyên mục',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('Lấy ý kiến chung')),
                        DropdownMenuItem(value: 'agm', child: Text('Hội nghị chung cư')),
                        DropdownMenuItem(value: 'finance', child: Text('Tài chính & Phí')),
                        DropdownMenuItem(value: 'maintenance', child: Text('Bảo trì & Đầu tư')),
                        DropdownMenuItem(value: 'rule', child: Text('Nội quy tòa nhà')),
                      ],
                      onChanged: (val) => setState(() => _category = val ?? 'general'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _voteWeightType,
                      decoration: const InputDecoration(
                        labelText: 'Cơ chế tính quyền',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'per_apartment', child: Text('1 Căn hộ = 1 Phiếu')),
                        DropdownMenuItem(value: 'by_area', child: Text('Theo diện tích m² (Luật Nhà ở)')),
                      ],
                      onChanged: (val) => setState(() => _voteWeightType = val ?? 'per_apartment'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hình thức lựa chọn
              DropdownButtonFormField<String>(
                initialValue: _choiceType,
                decoration: const InputDecoration(
                  labelText: 'Hình thức lựa chọn',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'single_choice', child: Text('Chọn 1 phương án duy nhất')),
                  DropdownMenuItem(value: 'multiple_choice', child: Text('Chọn nhiều phương án')),
                  DropdownMenuItem(value: 'yes_no_abstain', child: Text('Tán thành / Không / Ý kiến khác')),
                ],
                onChanged: (val) => setState(() => _choiceType = val ?? 'single_choice'),
              ),
              const SizedBox(height: 12),

              // Thời gian bắt đầu và kết thúc
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      title: const Text('Bắt đầu', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(_dateFormat.format(_startTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                      onTap: () => _pickDateTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      title: const Text('Kết thúc', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(_dateFormat.format(_endTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      trailing: const Icon(Icons.event_available_outlined, size: 18),
                      onTap: () => _pickDateTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Danh sách phương án
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Danh Sách Phương Án Lựa Chọn *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm'),
                  ),
                ],
              ),
              ..._optionControllers.asMap().entries.map((entry) {
                final idx = entry.key;
                final ctrl = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: ctrl,
                          decoration: InputDecoration(
                            hintText: 'Phương án ${idx + 1}',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nhập nội dung phương án';
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeOption(idx),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Mô tả chi tiết
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả chi tiết / Căn cứ pháp lý',
                  hintText: 'Nhập thông tin bối cảnh, căn cứ biểu quyết cho cư dân nắm rõ...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Nút Tạo biểu quyết
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.publish_rounded),
                label: Text(
                  _isLoading ? 'Đang tạo cuộc biểu quyết...' : 'Phát Hành Cuộc Biểu Quyết',
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

