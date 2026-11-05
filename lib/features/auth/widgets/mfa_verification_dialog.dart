import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// Hộp thoại xác thực 2 yếu tố khi đăng nhập tài khoản quản trị
class MfaVerificationDialog extends StatefulWidget {
  final Future<bool> Function(String code) onVerify;

  const MfaVerificationDialog({
    super.key,
    required this.onVerify,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Future<bool> Function(String code) onVerify,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MfaVerificationDialog(onVerify: onVerify),
    );
  }

  @override
  State<MfaVerificationDialog> createState() => _MfaVerificationDialogState();
}

class _MfaVerificationDialogState extends State<MfaVerificationDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ 6 chữ số xác thực.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onVerify(code);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Mã xác thực không chính xác hoặc đã hết hạn. Vui lòng thử lại.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Đã có lỗi xảy ra khi xác thực: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.security, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Xác thực hai yếu tố',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài khoản quản trị của bạn được bảo vệ bằng lớp bảo mật hai yếu tố (TOTP). '
              'Vui lòng mở ứng dụng Google Authenticator hoặc Microsoft Authenticator để lấy mã 6 chữ số.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
              onSubmitted: (_) => _handleConfirm(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
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
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy bỏ'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
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
              : const Text('Xác nhận'),
        ),
      ],
    );
  }
}
