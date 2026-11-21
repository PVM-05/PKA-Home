import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/security/mfa_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_provider.dart';
import '../widgets/auth_security_card_layout.dart';

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
        content: const Text(
          'Bạn có chắc chắn muốn hủy phiên đăng nhập hiện tại và quay về màn hình đăng nhập?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(88, 48),
              backgroundColor: AppTheme.textError,
              foregroundColor: Colors.white,
            ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleLogout();
        }
      },
      child: Scaffold(
        body: AuthSecurityCardLayout(
          icon: Icons.security_rounded,
          title: 'Xác thực hai bước',
          subtitle:
              'Tài khoản của bạn được bảo vệ bằng lớp xác thực nâng cao TOTP. Vui lòng mở ứng dụng Google Authenticator hoặc Microsoft Authenticator để lấy mã 6 chữ số.',
          cardChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: context.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  hintText: '000000',
                  hintStyle: context.headlineMedium?.copyWith(
                    letterSpacing: 8,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                  prefixIcon: const Icon(Icons.pin_outlined),
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.radiusMd,
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppTheme.radiusMd,
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                onSubmitted: (_) => _handleVerify(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
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
            ],
          ),
          footer: Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _isLoading ? null : _handleLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Đăng xuất / Đổi tài khoản'),
            ),
          ),
        ),
      ),
    );
  }
}
