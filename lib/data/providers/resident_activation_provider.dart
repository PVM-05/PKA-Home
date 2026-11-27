import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/error_formatter.dart';
import '../models/resident_activation_model.dart';
import '../repositories/resident_activation_repository.dart';

final residentActivationRepositoryProvider =
    Provider<ResidentActivationRepository>((ref) {
  return ResidentActivationRepository();
});

enum ActivationStep {
  enterCode, // Bước 1: Nhập SĐT & Mã kích hoạt
  enterOtp,  // Bước 2: Nhập mã OTP
  setPassword, // Bước 3: Đặt mật khẩu & Điều khoản
  completed, // Bước 4: Thành công & Kích hoạt sinh trắc học
}

class ResidentActivationState {
  final ActivationStep currentStep;
  final String phone;
  final String activationCode;
  final String? fullName;
  final String? apartmentCode;
  final String? otpHint;
  final String otpCode;
  final bool agreedToTerms;
  final bool isBiometricEnabled;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const ResidentActivationState({
    this.currentStep = ActivationStep.enterCode,
    this.phone = '',
    this.activationCode = '',
    this.fullName,
    this.apartmentCode,
    this.otpHint,
    this.otpCode = '',
    this.agreedToTerms = false,
    this.isBiometricEnabled = true,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ResidentActivationState copyWith({
    ActivationStep? currentStep,
    String? phone,
    String? activationCode,
    String? fullName,
    String? apartmentCode,
    String? otpHint,
    String? otpCode,
    bool? agreedToTerms,
    bool? isBiometricEnabled,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return ResidentActivationState(
      currentStep: currentStep ?? this.currentStep,
      phone: phone ?? this.phone,
      activationCode: activationCode ?? this.activationCode,
      fullName: fullName ?? this.fullName,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      otpHint: otpHint ?? this.otpHint,
      otpCode: otpCode ?? this.otpCode,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ResidentActivationNotifier extends StateNotifier<ResidentActivationState> {
  final ResidentActivationRepository _repository;

  ResidentActivationNotifier(this._repository)
      : super(const ResidentActivationState());

  void setAgreedToTerms(bool val) {
    state = state.copyWith(agreedToTerms: val);
  }

  void setBiometricEnabled(bool val) {
    state = state.copyWith(isBiometricEnabled: val);
  }

  void reset() {
    state = const ResidentActivationState();
  }

  /// Bước 1: Kiểm tra Số điện thoại và Mã kích hoạt
  Future<bool> submitActivationCode({
    required String phone,
    required String activationCode,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final cleanCode = activationCode.trim().toUpperCase();

    if (cleanPhone.isEmpty || cleanCode.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Vui lòng nhập đầy đủ Số điện thoại và Mã kích hoạt.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      final res = await _repository.verifyActivationCode(
        phone: cleanPhone,
        activationCode: cleanCode,
      );

      final isSuccess = res['success'] == true;
      if (isSuccess) {
        state = state.copyWith(
          isLoading: false,
          currentStep: ActivationStep.enterOtp,
          phone: cleanPhone,
          activationCode: cleanCode,
          fullName: res['full_name']?.toString() ?? 'Cư dân',
          apartmentCode: res['apartment_code']?.toString() ?? '',
          otpHint: res['otp_hint']?.toString(),
          successMessage: res['message']?.toString(),
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: res['message']?.toString() ??
              'Số điện thoại hoặc mã kích hoạt không chính xác.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatErrorMessage(e),
      );
      return false;
    }
  }

  /// Bước 2: Xác thực mã OTP
  Future<bool> submitOtp(String otp) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length < 6) {
      state = state.copyWith(
        errorMessage: 'Mã xác thực OTP phải gồm 6 chữ số.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      final res = await _repository.verifyActivationOtp(
        phone: state.phone,
        activationCode: state.activationCode,
        otpCode: cleanOtp,
      );

      final isSuccess = res['success'] == true;
      if (isSuccess) {
        state = state.copyWith(
          isLoading: false,
          currentStep: ActivationStep.setPassword,
          otpCode: cleanOtp,
          successMessage: res['message']?.toString(),
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: res['message']?.toString() ??
              'Mã xác thực OTP không chính xác hoặc đã hết hạn.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatErrorMessage(e),
      );
      return false;
    }
  }

  /// Gửi lại mã OTP
  Future<void> resendOtp() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final res = await _repository.verifyActivationCode(
        phone: state.phone,
        activationCode: state.activationCode,
      );
      state = state.copyWith(
        isLoading: false,
        otpHint: res['otp_hint']?.toString(),
        successMessage: 'Mã OTP mới đã được gửi lại vào số điện thoại của bạn.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatErrorMessage(e),
      );
    }
  }

  /// Bước 3 & 4: Tạo mật khẩu mới, liên kết tài khoản và hoàn tất
  Future<bool> completeActivation({
    required String password,
    required String confirmPassword,
  }) async {
    if (password.length < 6) {
      state = state.copyWith(
        errorMessage: 'Mật khẩu phải có độ dài tối thiểu từ 6 ký tự.',
      );
      return false;
    }

    if (password != confirmPassword) {
      state = state.copyWith(
        errorMessage: 'Xác nhận mật khẩu không trùng khớp.',
      );
      return false;
    }

    if (!state.agreedToTerms) {
      state = state.copyWith(
        errorMessage: 'Vui lòng đọc và tích chọn đồng ý với Quy chế chung cư.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      String authUserId;
      final virtualEmail = '${state.phone}@vivona.vn';

      // 1. Đăng ký tài khoản trong Supabase Auth (chỉ fallback offline khi Supabase chưa cấu hình trong môi trường kiểm thử)
      if (!SupabaseConfig.isConfigured) {
        authUserId = 'auth-${state.phone}';
      } else {
        try {
          final authRes = await SupabaseConfig.client.auth.signUp(
            email: virtualEmail,
            password: password,
            data: {
              'phone': state.phone,
              'full_name': state.fullName,
            },
          );

          if (authRes.user != null) {
            authUserId = authRes.user!.id;
          } else {
            final loginRes = await SupabaseConfig.client.auth.signInWithPassword(
              email: virtualEmail,
              password: password,
            );
            authUserId = loginRes.user?.id ?? '';
          }
        } catch (_) {
          // Thử đăng nhập nếu tài khoản Auth đã tồn tại trước đó
          try {
            final loginRes = await SupabaseConfig.client.auth.signInWithPassword(
              email: virtualEmail,
              password: password,
            );
            authUserId = loginRes.user?.id ?? '';
          } catch (_) {
            state = state.copyWith(
              isLoading: false,
              errorMessage:
                  'Không thể khởi tạo tài khoản xác thực cho số điện thoại này. Vui lòng kiểm tra kết nối hoặc liên hệ Ban Quản Lý.',
            );
            return false;
          }
        }
      }

      if (authUserId.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Không thể lấy mã định danh tài khoản sau khi đăng ký.',
        );
        return false;
      }

      // 2. Gọi RPC hoàn tất kích hoạt trên Database
      final completeRes = await _repository.completeActivation(
        phone: state.phone,
        activationCode: state.activationCode,
        otpCode: state.otpCode,
        authUserId: authUserId,
        email: virtualEmail,
      );

      final isSuccess = completeRes['success'] == true;
      if (isSuccess) {
        // Lưu cấu hình sinh trắc học nếu được chọn
        if (state.isBiometricEnabled) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('biometric_auth_enabled_${state.phone}', true);
          } catch (_) {}
        }

        state = state.copyWith(
          isLoading: false,
          currentStep: ActivationStep.completed,
          successMessage: completeRes['message']?.toString() ??
              'Kích hoạt tài khoản thành công!',
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: completeRes['message']?.toString() ??
              'Không thể hoàn tất kích hoạt tài khoản.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: formatErrorMessage(e),
      );
      return false;
    }
  }
}

final residentActivationProvider =
    StateNotifierProvider<ResidentActivationNotifier, ResidentActivationState>(
        (ref) {
  final repo = ref.watch(residentActivationRepositoryProvider);
  return ResidentActivationNotifier(repo);
});

final buildingActivationListProvider =
    FutureProvider.family<List<ResidentActivationModel>, String>(
        (ref, buildingId) async {
  final repo = ref.watch(residentActivationRepositoryProvider);
  return repo.fetchBuildingActivationList(buildingId);
});
