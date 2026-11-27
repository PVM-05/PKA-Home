import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../widgets/auth_security_card_layout.dart';

/// Màn hình Yêu cầu cấp lại mật khẩu qua Email OTP
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập địa chỉ thư điện tử';
      });
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Định dạng thư điện tử không hợp lệ';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authRepositoryProvider).sendPasswordResetOtp(email);

      if (!mounted) return;

      // Anti-account enumeration: Thông báo trung tính
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nếu địa chỉ thư điện tử này tồn tại trên hệ thống, mã xác thực OTP đã được gửi.',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );

      context.push(AppRoutes.verifyOtp, extra: email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = formatErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
      ),
      body: AuthSecurityCardLayout(
        icon: Icons.lock_reset_rounded,
        title: 'Khôi phục mật khẩu',
        subtitle:
            'Nhập địa chỉ thư điện tử tài khoản của bạn để nhận mã OTP gồm 6 chữ số.',
        cardChild: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                labelText: 'Thư điện tử',
                hintText: 'vidu@vivona.vn',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                AuthInlineErrorBanner(message: _errorMessage!),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Gửi mã xác thực'),
                      ),
              ),
            ],
          ),
        ),
        footer: Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _navigateBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Quay lại đăng nhập'),
            ),
          ),
        ),
      ),
    );
  }
}
