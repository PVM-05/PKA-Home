import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/resident_lifecycle_provider.dart';

class AcceptInvitationDialog extends ConsumerStatefulWidget {
  const AcceptInvitationDialog({super.key});

  @override
  ConsumerState<AcceptInvitationDialog> createState() => _AcceptInvitationDialogState();
}

class _AcceptInvitationDialogState extends ConsumerState<AcceptInvitationDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mã mời');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final repo = ref.read(residentLifecycleRepositoryProvider);
    final res = await repo.acceptInvitation(code);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _successMessage = res['message'] ?? 'Kích hoạt gia nhập căn hộ thành công!';
        } else {
          _errorMessage = res['message'] ?? 'Mã mời không hợp lệ.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.key_rounded, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gia Nhập Căn Hộ Qua Mã Mời',
              style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhập mã mời được Ban Quản Lý hoặc Chủ hộ cung cấp để tự động liên kết vào căn hộ của bạn.',
              style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Mã kích hoạt',
                hintText: 'Ví dụ: VIV12345',
                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: context.bodySmall?.copyWith(color: AppTheme.getSemanticError(context)),
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.getSemanticSuccess(context), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: context.bodySmall?.copyWith(
                        color: AppTheme.getSemanticSuccess(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleAccept,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size(0, 48),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kích hoạt vào căn hộ'),
        ),
      ],
    );
  }
}
