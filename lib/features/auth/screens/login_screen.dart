import '../../../core/security/mfa_service.dart';
import '../widgets/mfa_verification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Email và mật khẩu'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Định dạng Email không hợp lệ.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authProvider.notifier).login(email, password);

      // Kiểm tra xác thực 2 bước (MFA / TOTP)
      if (mounted) {
        final mfaService = ref.read(mfaServiceProvider);
        final hasMfa = await mfaService.isMfaEnrolled();
        if (hasMfa && mounted) {
          final factorId = await mfaService.getVerifiedFactorId();
          if (factorId != null && factorId.isNotEmpty) {
            if (!mounted) return;
            final mfaPassed = await MfaVerificationDialog.show(
              context,
              onVerify: (code) =>
                  mfaService.verifyTotp(factorId: factorId, code: code),
            );

            if (mfaPassed != true) {
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Xác thực hai bước (MFA) không thành công. Phiên đăng nhập đã bị hủy.',
                    ),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
              return;
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = formatErrorMessage(
            e,
            fallback: 'Đăng nhập thất bại. Vui lòng kiểm tra lại.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Row(
              children: [
                // 1. CỘT TRÁI: HERO BRAND SHOWCASE (CHUẨN B2B SAAS QUỐC TẾ)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: AppGradients.heroDark,
                    ),
                    child: LayoutBuilder(
                      builder: (context, heroConstraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: (heroConstraints.maxHeight - 72).clamp(0.0, double.infinity),
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Header logo
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: AppGradients.brandPrimary,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: AppShadows.cardGlow,
                                        ),
                                        child: const Icon(
                                          Icons.apartment_rounded,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        'Vivona',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Mid showcase content
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.sapphire.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppTheme.sapphire.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified_rounded, size: 14, color: AppTheme.secondary),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Commercial PropTech SaaS Platform',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: AppTheme.secondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Vận Hành Tòa Nhà\nThông Minh & Chuẩn Mực',
                                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                          color: Colors.white,
                                          height: 1.25,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Giải pháp quản trị bất động sản toàn diện: đối soát ngân hàng VietQR tự động, sổ cái công nợ bất biến, điều phối sự cố SLA đa tầng và kết nối cư dân số hóa.',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Colors.white70,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      _buildShowcasePill(
                                        icon: Icons.shield_outlined,
                                        title: 'Bảo Mật Tiêu Chuẩn Doanh Nghiệp',
                                        desc: 'Tuân thủ Luật Dữ liệu cá nhân 2026 & Luật Nhà ở 2023',
                                      ),
                                      const SizedBox(height: 14),
                                      _buildShowcasePill(
                                        icon: Icons.qr_code_2_rounded,
                                        title: 'Đối Soát Ngân Hàng Tự Động 2 Giây',
                                        desc: 'Tích hợp VietQR Napas 247 & Webhook SePay gạch nợ tức thì',
                                      ),
                                      const SizedBox(height: 14),
                                      _buildShowcasePill(
                                        icon: Icons.menu_book_rounded,
                                        title: 'Sổ Cái Kế Toán Append-Only Bất Biến',
                                        desc: 'Kiểm toán minh bạch dòng tiền vận hành & Quỹ bảo trì 2%',
                                      ),
                                    ],
                                  ),

                                  // Footer
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: Text(
                                      '© 2026 Vivona Commercial SaaS. Tất cả các quyền được bảo lưu.',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. CỘT PHẢI: FORM ĐĂNG NHẬP TINH TẾ (CENTERED 440DP)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _buildFormContent(context, isDesktop: true),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // BỐ CỤC MOBILE (< 900DP)
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo / Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppGradients.brandPrimary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppShadows.cardGlow,
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Vivona',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ứng Dụng Quản Lý Chung Cư',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildFormContent(context, isDesktop: false),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShowcasePill({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 18, color: AppTheme.secondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(BuildContext context, {required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDesktop) ...[
          Text(
            'Đăng nhập tài khoản',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chào mừng bạn đến với hệ sinh thái quản lý tòa nhà Vivona',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (ref.watch(accountLockedNoticeProvider)) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade400),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.red.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ Ban Quản Lý để được hỗ trợ.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (ref.watch(sessionExpiredNoticeProvider)) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục sử dụng.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Card form
        AppCard(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Thư điện tử',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
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
                onSubmitted: (_) => _login(),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Nút đăng nhập
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Đăng nhập',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              // Quên mật khẩu
              Center(
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  child: Text(
                    'Quên mật khẩu?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'HOẶC',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 14),

              // Nút Kích hoạt tài khoản lần đầu
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                  side: const BorderSide(color: AppTheme.primary, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.key_rounded, size: 20),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Kích hoạt tài khoản lần đầu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                onPressed: () => context.push(AppRoutes.residentActivation),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Nút chuyển trang đăng ký
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: const [
                  TextSpan(text: 'Chưa có tài khoản? '),
                  TextSpan(
                    text: 'Đăng ký ngay',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
