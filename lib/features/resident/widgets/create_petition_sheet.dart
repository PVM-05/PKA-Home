import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/models/petition_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/community_provider.dart';

class CreatePetitionSheet extends ConsumerStatefulWidget {
  final String apartmentId;
  final ValueChanged<PetitionModel>? onPetitionCreated;

  const CreatePetitionSheet({
    super.key,
    required this.apartmentId,
    this.onPetitionCreated,
  });

  @override
  ConsumerState<CreatePetitionSheet> createState() =>
      _CreatePetitionSheetState();
}

class _CreatePetitionSheetState extends ConsumerState<CreatePetitionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = 'general';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authUser = ref.read(authProvider).valueOrNull;
    if (authUser == null) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Vui lòng đăng nhập để gửi kiến nghị',
        );
      }
      return;
    }
    final authorUserId = authUser.id;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final newPet = await repo.createPetition(
        apartmentId: widget.apartmentId,
        authorUserId: authorUserId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _category,
      );

      ref.invalidate(
        petitionsProvider((
          status: null,
          category: null,
          apartmentId: widget.apartmentId,
        )),
      );
      ref.invalidate(communityStatsProvider);

      if (mounted) {
        Navigator.pop(context);
        widget.onPetitionCreated?.call(newPet);
        AppSnackBar.showSuccess(
          context,
          'Kiến nghị của bạn đã được gửi tới Ban Quản Lý thành công',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: colorScheme.outlineVariant,
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
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.rate_review_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gửi Ý Kiến & Kiến Nghị Mới',
                      style: context.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tiêu đề
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề kiến nghị *',
                  hintText: 'Ví dụ: Đề xuất mở phòng Gym lúc 5h30 sáng...',
                  prefixIcon: Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề kiến nghị';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Chuyên mục
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Phân loại chuyên mục',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'general',
                    child: Text('Góp ý chung'),
                  ),
                  DropdownMenuItem(
                    value: 'security',
                    child: Text('An ninh & Trật tự'),
                  ),
                  DropdownMenuItem(
                    value: 'hygiene',
                    child: Text('Vệ sinh & Môi trường'),
                  ),
                  DropdownMenuItem(
                    value: 'amenity',
                    child: Text('Tiện ích & Cảnh quan'),
                  ),
                  DropdownMenuItem(
                    value: 'noise',
                    child: Text('Tiếng ồn sinh hoạt'),
                  ),
                ],
                onChanged: (val) =>
                    setState(() => _category = val ?? 'general'),
              ),
              const SizedBox(height: 12),

              // Nội dung chi tiết
              TextFormField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nội dung kiến nghị / Đề xuất giải pháp *',
                  hintText:
                      'Mô tả chi tiết vấn đề và nguyện vọng để Ban Quản Lý và các cư dân khác cùng nắm bắt...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập nội dung kiến nghị';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kiến nghị sẽ được hiển thị công khai trên ứng dụng để các cư dân cùng bấm Đồng thuận ủng hộ.',
                        style: context.bodySmall?.copyWith(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Nút Gửi kiến nghị
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isLoading ? 'Đang gửi...' : 'Gửi Kiến Nghị Tới Ban Quản Lý',
                  style: context.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
