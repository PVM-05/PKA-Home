import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/providers/resident_activation_provider.dart';

class ResidentActivationScreen extends ConsumerStatefulWidget {
  const ResidentActivationScreen({super.key});

  @override
  ConsumerState<ResidentActivationScreen> createState() =>
      _ResidentActivationScreenState();
}

class _ResidentActivationScreenState
    extends ConsumerState<ResidentActivationScreen> {
  // Controllers Bước 1
  final _phoneController = TextEditingController();
  final _activationCodeController = TextEditingController();

  // Controllers Bước 2
  final _otpController = TextEditingController();
  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _canResendOtp = false;

  // Controllers Bước 3
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(residentActivationProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _activationCodeController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startOtpTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _canResendOtp = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _secondsRemaining = 0;
          _canResendOtp = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentActivationProvider);
    final notifier = ref.read(residentActivationProvider.notifier);

    // Lắng nghe khi chuyển bước để xử lý timer
    ref.listen<ResidentActivationState>(residentActivationProvider, (prev, next) {
      if (prev?.currentStep != ActivationStep.enterOtp &&
          next.currentStep == ActivationStep.enterOtp) {
        _startOtpTimer();
        if (next.otpHint != null) {
          _otpController.text = next.otpHint!;
        }
      } else if (next.currentStep != ActivationStep.enterOtp) {
        _countdownTimer?.cancel();
      }

      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kích Hoạt Tài Khoản'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (state.currentStep == ActivationStep.enterOtp) {
              notifier.reset();
            } else if (state.currentStep == ActivationStep.setPassword) {
              notifier.reset();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final contentPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;

            if (isDesktop) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cột trái: Hero Brand Showcase
                        Expanded(
                          flex: 5,
                          child: _buildHeroShowcase(context),
                        ),
                        const SizedBox(width: 32),
                        // Cột phải: Form kích hoạt 4 bước
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildStepIndicator(state.currentStep),
                              const SizedBox(height: 28),
                              switch (state.currentStep) {
                                ActivationStep.enterCode => _buildStep1EnterCode(state, notifier),
                                ActivationStep.enterOtp => _buildStep2EnterOtp(state, notifier),
                                ActivationStep.setPassword => _buildStep3SetPassword(state, notifier),
                                ActivationStep.completed => _buildStep4Completed(state),
                              },
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Bố cục Mobile (< 900dp)
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(contentPadding),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Thanh tiến trình 4 bước
                      _buildStepIndicator(state.currentStep),
                      const SizedBox(height: 28),

                      // Nội dung từng bước
                      switch (state.currentStep) {
                        ActivationStep.enterCode => _buildStep1EnterCode(state, notifier),
                        ActivationStep.enterOtp => _buildStep2EnterOtp(state, notifier),
                        ActivationStep.setPassword => _buildStep3SetPassword(state, notifier),
                        ActivationStep.completed => _buildStep4Completed(state),
                      },
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET HERO SHOWCASE (DESKTOP) ---
  Widget _buildHeroShowcase(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.heroDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.cardGlow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppGradients.brandPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'PKA-Home',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.sapphire.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.sapphire.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF60A5FA)),
                SizedBox(width: 6),
                Text(
                  'Cổng Kích Hoạt Cư Dân Số Hóa',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Chào Mừng Cư Dân Đến Với\nKhông Gian Sống Thông Minh',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kích hoạt tài khoản để tiếp nhận mã căn hộ số hóa, tra cứu chỉ số điện nước minh bạch, nhận thông báo kịp thời và thanh toán phí dịch vụ tiện lợi.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _buildHeroFeaturePill(
            icon: Icons.domain_verification_rounded,
            title: 'Định danh & Sở hữu căn hộ chuẩn xác',
            desc: 'Liên kết trực tiếp mã căn hộ và hồ sơ cư dân bảo mật.',
          ),
          const SizedBox(height: 14),
          _buildHeroFeaturePill(
            icon: Icons.qr_code_2_rounded,
            title: 'Hóa đơn & Biểu phí minh bạch',
            desc: 'Đối soát tức thì qua cổng VietQR Napas 247 an toàn.',
          ),
          const SizedBox(height: 14),
          _buildHeroFeaturePill(
            icon: Icons.build_circle_outlined,
            title: 'Tiếp nhận phản ánh kỹ thuật 24/7',
            desc: 'Cam kết thời gian xử lý sự cố chuẩn mực theo SLA.',
          ),
          const SizedBox(height: 14),
          _buildHeroFeaturePill(
            icon: Icons.notifications_active_outlined,
            title: 'Thông báo khẩn cấp từ Ban Quản Lý',
            desc: 'Cập nhật lịch bảo trì, thông điệp an ninh toàn diện.',
          ),
        ],
      ),
    );
  }

  Widget _buildHeroFeaturePill({
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
          child: Icon(icon, size: 18, color: const Color(0xFF60A5FA)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET TIẾN TRÌNH 4 BƯỚC ---
  Widget _buildStepIndicator(ActivationStep currentStep) {
    final steps = [
      {'title': 'Mã mời', 'step': ActivationStep.enterCode},
      {'title': 'Xác thực', 'step': ActivationStep.enterOtp},
      {'title': 'Mật khẩu', 'step': ActivationStep.setPassword},
      {'title': 'Hoàn tất', 'step': ActivationStep.completed},
    ];

    final currentIndex = steps.indexWhere((s) => s['step'] == currentStep);

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final isPassed = (index ~/ 2) < currentIndex;
          return Expanded(
            flex: 2,
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: isPassed ? AppTheme.primary : Colors.grey.shade300,
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final stepItem = steps[stepIndex];
        final isActive = stepIndex <= currentIndex;
        final isCurrent = stepIndex == currentIndex;

        return Expanded(
          flex: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: isCurrent
                    ? AppTheme.primary
                    : (isActive ? AppTheme.success : Colors.grey.shade300),
                child: isActive && !isCurrent
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stepItem['title'] as String,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // --- BƯỚC 1: NHẬP SĐT VÀ MÃ KÍCH HOẠT ---
  Widget _buildStep1EnterCode(
    ResidentActivationState state,
    ResidentActivationNotifier notifier,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key_rounded, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kích hoạt lần đầu',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Dành cho cư dân mới nhận bàn giao nhà',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          const Text(
            'Nhập Số điện thoại đã đăng ký với Ban Quản Lý và Mã kích hoạt trong thư mời hoặc phiếu bàn giao căn hộ.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại cư dân (*)',
              hintText: 'VD: 0901234567',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _activationCodeController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Mã kích hoạt (*)',
              hintText: 'VD: ACT-123456',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () {
                    notifier.submitActivationCode(
                      phone: _phoneController.text,
                      activationCode: _activationCodeController.text,
                    );
                  },
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Tiếp tục xác thực OTP'),
                  ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hướng dẫn nhận mã kích hoạt'),
                    content: const Text(
                      'Mã kích hoạt (Activation Code) được cấp riêng cho từng cư dân khi nhận bàn giao căn hộ hoặc gửi qua tin nhắn SMS/Zalo từ Ban Quản Lý.\n\n'
                      'Nếu bạn chưa nhận được mã, vui lòng liên hệ trực tiếp Văn phòng Quản lý hoặc Hotline tòa nhà.',
                      style: TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Đã hiểu'),
                      ),
                    ],
                  ),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.help_outline, size: 16),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Chưa có mã kích hoạt? Liên hệ BQL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BƯỚC 2: XÁC THỰC MÃ OTP ---
  Widget _buildStep2EnterOtp(
    ResidentActivationState state,
    ResidentActivationNotifier notifier,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thẻ thông tin căn hộ nhận diện
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chào mừng, ${state.fullName ?? "Cư dân"}!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hồ sơ gắn liền Căn hộ ${state.apartmentCode ?? ""}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Mã OTP 6 chữ số đã được gửi đến số điện thoại ${state.phone}. Vui lòng nhập mã để xác nhận quyền sử dụng.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              labelText: 'Mã xác thực OTP',
              counterText: '',
              prefixIcon: Icon(Icons.security),
            ),
          ),
          const SizedBox(height: 12),

          // Bộ đếm thời gian hoặc nút gửi lại
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_canResendOtp)
                Text(
                  'Gửi lại mã sau ${_secondsRemaining}s',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Gửi lại mã OTP'),
                  onPressed: state.isLoading ? null : () => notifier.resendOtp(),
                ),
            ],
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () => notifier.submitOtp(_otpController.text),
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Xác thực OTP & Thiết lập mật khẩu'),
                  ),
          ),
        ],
      ),
    );
  }

  // --- BƯỚC 3: ĐẶT MẬT KHẨU & ĐIỀU KHOẢN ---
  Widget _buildStep3SetPassword(
    ResidentActivationState state,
    ResidentActivationNotifier notifier,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Thiết lập mật khẩu đăng nhập',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mật khẩu này sẽ được dùng để đăng nhập vào ứng dụng PKA-Home trong các lần tiếp theo.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          const Divider(height: 24),

          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới (tối thiểu 6 ký tự) (*)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Xác nhận lại mật khẩu (*)',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cờ bật sinh trắc học
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Bật đăng nhập Sinh trắc học (Face ID / Vân tay)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Cho phép mở khóa nhanh và bảo mật cho thiết bị này',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            value: state.isBiometricEnabled,
            onChanged: (val) => notifier.setBiometricEnabled(val),
          ),
          const SizedBox(height: 8),

          // Điều khoản quy chế chung cư
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: state.agreedToTerms,
                onChanged: (val) => notifier.setAgreedToTerms(val ?? false),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: Text(
                    'Tôi đã đọc, hiểu rõ và đồng ý tuân thủ Nội quy & Quy chế quản lý sử dụng chung cư PKA-Home.',
                    style: TextStyle(fontSize: 12.5, height: 1.3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () {
                    notifier.completeActivation(
                      password: _passwordController.text,
                      confirmPassword: _confirmPasswordController.text,
                    );
                  },
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Hoàn tất kích hoạt'),
                  ),
          ),
        ],
      ),
    );
  }

  // --- BƯỚC 4: KÍCH HOẠT THÀNH CÔNG ---
  Widget _buildStep4Completed(ResidentActivationState state) {
    return AppCard(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, size: 64, color: AppTheme.success),
          ),
          const SizedBox(height: 20),

          const Text(
            'Kích Hoạt Thành Công!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tài khoản của cư dân ${state.fullName ?? ""} đã được kết nối chính thức với Căn hộ ${state.apartmentCode ?? ""}.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Số điện thoại đăng nhập:', state.phone),
                const Divider(height: 16),
                _buildSummaryRow('Mã căn hộ:', state.apartmentCode ?? 'A0110'),
                const Divider(height: 16),
                _buildSummaryRow(
                  'Bảo mật sinh trắc học:',
                  state.isBiometricEnabled ? 'Đã bật' : 'Chưa bật',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('Bắt đầu trải nghiệm ngay'),
              onPressed: () {
                // Chuyển về màn hình đăng nhập hoặc vào trang chủ cư dân
                context.go(AppRoutes.login);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
