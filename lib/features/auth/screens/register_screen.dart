import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  void _register() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (fullName.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
      try {
        await ref.read(authProvider.notifier).register(email, password, fullName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi đăng ký: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo tài khoản'),
        leading: IconButton(
          icon: const Icon(FluentIcons.chevron_left_24_regular),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Đăng ký Cư dân',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Điền thông tin để tham gia PKA-Home',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên',
                              prefixIcon: Icon(FluentIcons.person_24_regular),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Thư điện tử',
                              prefixIcon: Icon(FluentIcons.mail_24_regular),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(FluentIcons.password_24_regular),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword 
                                    ? FluentIcons.eye_24_regular 
                                    : FluentIcons.eye_off_24_regular,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _register(),
                          ),
                          const SizedBox(height: 32),
                          
                          ElevatedButton(
                            onPressed: authState.isLoading ? null : _register,
                            child: authState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Đăng ký'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: const [
                          TextSpan(text: 'Đã có tài khoản? '),
                          TextSpan(
                            text: 'Đăng nhập ngay',
                            style: TextStyle(
                              color: AppTheme.primary,
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
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
