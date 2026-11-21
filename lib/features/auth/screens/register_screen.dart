import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../data/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  bool get _hasUnsavedChanges =>
      _fullNameController.text.trim().isNotEmpty ||
      _emailController.text.trim().isNotEmpty ||
      _passwordController.text.isNotEmpty ||
      _confirmPasswordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fullNameController.addListener(_onInputChanged);
    _emailController.addListener(_onInputChanged);
    _passwordController.addListener(_onInputChanged);
    _confirmPasswordController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  void _register() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    String? errorMessage;
    if (fullName.isEmpty) {
      errorMessage = 'Vui lòng nhập họ và tên';
    } else if (email.isEmpty || !emailRegex.hasMatch(email)) {
      errorMessage = 'Định dạng Email không hợp lệ';
    } else if (password.length < 6) {
      errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự';
    } else if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password)) {
      errorMessage = 'Mật khẩu phải bao gồm cả chữ cái và chữ số';
    } else if (password != confirmPassword) {
      errorMessage = 'Xác nhận mật khẩu không khớp';
    }

    if (errorMessage == null) {
      setState(() {
        _isLoading = true;
      });
      try {
        await ref
            .read(authProvider.notifier)
            .register(email, password, fullName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng ký thành công!'),
              backgroundColor: AppTheme.textSuccess,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(formatErrorMessage(e)),
              backgroundColor: AppTheme.textError,
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.textWarning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges && !_isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tạo tài khoản'),
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 24.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Đăng ký Cư dân',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Điền thông tin để tham gia Vivona',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),

                    AppCard(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _fullNameController,
                            labelText: 'Họ và tên',
                            prefixIcon: const Icon(Icons.person_outline),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 18),
                          AppTextField(
                            controller: _emailController,
                            labelText: 'Thư điện tử',
                            prefixIcon: const Icon(Icons.email_outlined),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 18),
                          AppTextField(
                            controller: _passwordController,
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          AppTextField(
                            controller: _confirmPasswordController,
                            labelText: 'Xác nhận mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _register(),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmPassword
                                  ? 'Hiện mật khẩu xác nhận'
                                  : 'Ẩn mật khẩu xác nhận',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 28),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
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
                                    child: Text('Đăng ký'),
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium,
                          children: [
                            const TextSpan(text: 'Đã có tài khoản? '),
                            TextSpan(
                              text: 'Đăng nhập ngay',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.removeListener(_onInputChanged);
    _emailController.removeListener(_onInputChanged);
    _passwordController.removeListener(_onInputChanged);
    _confirmPasswordController.removeListener(_onInputChanged);
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
