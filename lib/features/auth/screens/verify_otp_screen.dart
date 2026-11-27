import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/repositories/auth_repository.dart';
import '../widgets/auth_security_card_layout.dart';
import '../widgets/otp_input_boxes.dart';

/// Màn hình nhập mã xác thực OTP 6 số để khôi phục mật khẩu
class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  String _currentOtp = '';
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).sendPasswordResetOtp(widget.email);
      if (!mounted) return;

      AppSnackBar.showSuccess(
        context,
        'Đã gửi lại mã OTP mới vào hòm thư của bạn.',
      );
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = formatErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _verifyOtp([String? token]) async {
    final otpToVerify = token ?? _currentOtp;
    if (otpToVerify.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đủ 6 chữ số mã xác thực';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPasswordResetOtp(email: widget.email, token: otpToVerify);

      if (!mounted) return;

      context.push(AppRoutes.resetPassword, extra: widget.email);
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
      context.go(AppRoutes.forgotPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực OTP'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
      ),
      body: AuthSecurityCardLayout(
        icon: Icons.mark_email_read_outlined,
        title: 'Xác nhận mã OTP',
        subtitle: 'Mã xác thực gồm 6 chữ số đã được gửi đến:',
        subtitleExtra: Text(
          widget.email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        cardChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OtpInputBoxes(
              length: 6,
              onChanged: (val) {
                setState(() {
                  _currentOtp = val;
                  if (_errorMessage != null) {
                    _errorMessage = null;
                  }
                });
              },
              onCompleted: (val) {
                _currentOtp = val;
                _verifyOtp(val);
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              AuthInlineErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: (_isLoading || _currentOtp.length != 6)
                  ? null
                  : () => _verifyOtp(),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Xác nhận'),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  _secondsRemaining > 0
                      ? 'Gửi lại mã sau ($_secondsRemaining s)'
                      : 'Chưa nhận được mã?',
                  style: context.bodySmall?.copyWith(
                    color: _secondsRemaining > 0
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (_secondsRemaining == 0)
                  TextButton(
                    onPressed: _isResending ? null : _resendOtp,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Gửi lại mã',
                            style: context.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
              ],
            ),
          ],
        ),
        footer: Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _navigateBack,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Nhập lại địa chỉ thư điện tử'),
          ),
        ),
      ),
    );
  }
}
