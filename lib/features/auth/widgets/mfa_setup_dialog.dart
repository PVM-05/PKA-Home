import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/mfa_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_snack_bar.dart';

/// Hiển thị hộp thoại quản lý hoặc đăng ký mới xác thực 2 yếu tố (TOTP 2FA)
Future<void> showMfaManagementDialog(BuildContext context, WidgetRef ref) async {
  final mfaService = ref.read(mfaServiceProvider);
  final isEnrolled = await mfaService.isMfaEnrolled();
  if (!context.mounted) return;

  if (isEnrolled) {
    final factorId = await mfaService.getVerifiedFactorId();
    if (!context.mounted) return;
    final disable = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.verified_user_rounded, color: AppTheme.getSemanticSuccess(ctx)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Đã bật xác thực 2 yếu tố')),
            ],
          ),
          content: const Text(
            'Tài khoản của bạn đang được bảo vệ bởi mã xác thực 6 chữ số từ ứng dụng xác thực. Bạn có muốn tắt tính năng này không?',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Giữ nguyên'),
            ),
            if (factorId != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.textError,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Hủy kích hoạt'),
              ),
          ],
        );
      },
    );

    if (disable == true && factorId != null && context.mounted) {
      try {
        await mfaService.unenroll(factorId: factorId);
        if (context.mounted) {
          AppSnackBar.showSuccess(context, 'Đã tắt xác thực hai yếu tố cho tài khoản.');
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBar.showError(context, formatErrorMessage(e));
        }
      }
    }
    return;
  }

  try {
    final enrollData = await mfaService.enrollTotp();
    if (!context.mounted) return;
    final activated = await MfaSetupDialog.show(
      context,
      secretKey: enrollData.secret,
      onActivate: (code) => mfaService.verifyTotp(
        factorId: enrollData.factorId,
        code: code,
      ),
    );
    if (activated == true && context.mounted) {
      AppSnackBar.showSuccess(context, 'Đã kích hoạt bảo mật xác thực 2 yếu tố thành công!');
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, formatErrorMessage(e));
    }
  }
}

/// Hộp thoại thiết lập và kích hoạt xác thực hai yếu tố (MFA / TOTP)
class MfaSetupDialog extends StatefulWidget {
  final String secretKey;
  final Future<bool> Function(String code) onActivate;

  const MfaSetupDialog({
    super.key,
    required this.secretKey,
    required this.onActivate,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String secretKey,
    required Future<bool> Function(String code) onActivate,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MfaSetupDialog(
        secretKey: secretKey,
        onActivate: onActivate,
      ),
    );
  }

  @override
  State<MfaSetupDialog> createState() => _MfaSetupDialogState();
}

class _MfaSetupDialogState extends State<MfaSetupDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _copied = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _copySecret() {
    Clipboard.setData(ClipboardData(text: widget.secretKey));
    setState(() {
      _copied = true;
    });
    AppSnackBar.showSuccess(context, 'Đã sao chép khóa bí mật vào bộ nhớ tạm.');
  }

  Future<void> _handleActivate() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đủ 6 chữ số từ ứng dụng xác thực.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onActivate(code);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Mã xác thực không hợp lệ. Vui lòng kiểm tra lại giờ hệ thống và nhập lại.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = formatErrorMessage(e, fallback: 'Không thể kích hoạt xác thực 2 yếu tố.');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.enhanced_encryption, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kích hoạt xác thực 2 yếu tố',
              style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              'Bước 1: Mở ứng dụng Google Authenticator hoặc Microsoft Authenticator, chọn "Thêm khóa thủ công" và nhập khóa bí mật sau:',
              style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.secretKey,
                      style: context.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 20, color: colorScheme.primary),
                    tooltip: 'Sao chép khóa',
                    onPressed: _copySecret,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bước 2: Nhập mã 6 chữ số hiển thị trên ứng dụng xác thực để kiểm tra và hoàn tất:',
              style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: context.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: colorScheme.onSurface,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              onSubmitted: (_) => _handleActivate(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: context.labelSmall?.copyWith(color: errorColor),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleActivate,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Hoàn tất kích hoạt'),
        ),
      ],
    );
  }
}
