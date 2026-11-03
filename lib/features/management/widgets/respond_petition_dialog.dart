import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/petition_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/community_provider.dart';

class RespondPetitionDialog extends ConsumerStatefulWidget {
  final PetitionModel petition;

  const RespondPetitionDialog({super.key, required this.petition});

  @override
  ConsumerState<RespondPetitionDialog> createState() => _RespondPetitionDialogState();
}

class _RespondPetitionDialogState extends ConsumerState<RespondPetitionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _status;
  late TextEditingController _responseController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _status = widget.petition.status == 'pending' ? 'in_progress' : widget.petition.status;
    _responseController = TextEditingController(text: widget.petition.officialResponse ?? '');
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authUser = ref.read(authProvider).valueOrNull;
    final staffId = authUser?.id ?? 'usr-admin';

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final res = await repo.updatePetitionResponse(
        petitionId: widget.petition.id,
        status: _status,
        officialResponse: _responseController.text.trim(),
        staffId: staffId,
      );

      if (res['success'] == true) {
        ref.invalidate(petitionsProvider((status: null, category: null, apartmentId: null)));
        ref.invalidate(communityStatsProvider);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật phản hồi chính thức của Ban Quản Lý'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Thao tác thất bại'), backgroundColor: AppTheme.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.rate_review_outlined, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.petition.petitionCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.primary,
                            ),
                          ),
                          const Text(
                            'Phản Hồi & Xử Lý Kiến Nghị',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                const Divider(height: 20),

                // Tiêu đề kiến nghị
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.petition.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),

                // Trạng thái mới
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Cập nhật trạng thái xử lý',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'in_progress', child: Text('Đang xử lý')),
                    DropdownMenuItem(value: 'resolved', child: Text('Đã giải quyết')),
                    DropdownMenuItem(value: 'rejected', child: Text('Từ chối / Không phù hợp')),
                    DropdownMenuItem(value: 'acknowledged', child: Text('Đã ghi nhận tiếp nhận')),
                  ],
                  onChanged: (val) => setState(() => _status = val ?? _status),
                ),
                const SizedBox(height: 14),

                // Nội dung phản hồi chính thức
                TextFormField(
                  controller: _responseController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Phản hồi chính thức của Ban Quản Lý *',
                    hintText: 'Nhập nội dung giải trình hoặc phương án khắc phục gửi cư dân...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập nội dung phản hồi cho cư dân';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Nút lưu
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_isLoading ? 'Đang lưu...' : 'Lưu Phản Hồi'),
                      ),
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

