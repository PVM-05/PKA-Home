import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../../core/security/mfa_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_provider.dart';

/// Màn hình cổng bảo mật bắt buộc xác thực hai yếu tố (TOTP / AAL2 Gate)
class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ 6 chữ số mã xác thực.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mfaService = ref.read(mfaServiceProvider);
      final factorId = await mfaService.getVerifiedFactorId();

      if (factorId == null || factorId.isEmpty) {
        throw Exception('Không tìm thấy yếu tố xác thực TOTP đang kích hoạt.');
      }

      final success = await mfaService.verifyTotp(
        factorId: factorId,
        code: code,
      );

      if (!mounted) return;

      if (success) {
        HapticFeedback.mediumImpact();
        ref.read(authProvider.notifier).clearMfaChallenge();
        ref.read(appRouterProvider).refresh();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Mã xác thực không chính xác hoặc đã hết hạn.';
          _isLoading = false;
        });
        _codeController.clear();
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi xác thực: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đăng nhập'),
        content: const Text('Bạn có chắc chắn muốn hủy phiên đăng nhập hiện tại và quay về màn hình đăng nhập?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : AppTheme.border;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleLogout();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: isDark ? null : AppShadows.softMd,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          size: 40,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Xác thực hai bước',
                        style: context.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tài khoản của bạn được bảo vệ bằng lớp xác thực nâng cao TOTP. Vui lòng mở ứng dụng Google Authenticator hoặc Microsoft Authenticator để lấy mã 6 chữ số.',
                        style: context.bodyMedium?.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _codeController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: context.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: context.headlineMedium?.copyWith(
                            letterSpacing: 8,
                            color: AppTheme.getTextSecondary(context).withValues(alpha: 0.4),
                          ),
                          prefixIcon: const Icon(Icons.pin_outlined),
                          errorText: _errorMessage,
                        ),
                        onSubmitted: (_) => _handleVerify(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleVerify,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Xác nhận đăng nhập'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _handleLogout,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Đăng xuất / Đổi tài khoản'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

