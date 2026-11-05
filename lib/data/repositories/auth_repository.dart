import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/security/auth_rate_limiter.dart';
import '../../core/supabase_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final limiter = ref.watch(authRateLimiterProvider);
  return AuthRepository(null, limiter);
});

class AuthRepository {
  final SupabaseClient _client;
  final AuthRateLimiter _rateLimiter;

  AuthRepository([
    SupabaseClient? client,
    AuthRateLimiter? limiter,
  ])  : _client = client ?? SupabaseConfig.client,
        _rateLimiter = limiter ?? AuthRateLimiter();

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>> fetchUserInfo(String userId) async {
    return await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();
  }

  Future<void> login(String email, String password) async {
    final rateCheck = _rateLimiter.checkLoginAllowed(email);
    if (!rateCheck.isAllowed) {
      throw Exception(rateCheck.message ?? 'Tài khoản tạm thời bị khóa do thử sai nhiều lần.');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _rateLimiter.resetLoginAttempts(email);
    } catch (e) {
      _rateLimiter.recordLoginFailure(email);
      rethrow;
    }
  }

  Future<void> register(String email, String password, String fullName) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Gửi mã OTP 6 số đến email của người dùng để phục hồi mật khẩu
  Future<void> sendPasswordResetOtp(String email) async {
    final check = _rateLimiter.checkOtpSendAllowed(email);
    if (!check.isAllowed) {
      throw Exception(check.message ?? 'Vui lòng chờ trước khi gửi lại mã OTP.');
    }

    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      _rateLimiter.recordOtpSent(email);
    } on AuthException catch (e) {
      if (e.statusCode == '429' || e.message.toLowerCase().contains('too many requests')) {
        throw Exception('Bạn đã gửi yêu cầu quá nhiều lần. Vui lòng chờ ít phút.');
      }
      // Anti-enumeration: Không rethrow lỗi user not found ra ngoài
      if (!e.message.toLowerCase().contains('user not found')) {
        rethrow;
      }
    }
  }

  /// Xác thực mã OTP 6 số do người dùng nhập vào
  Future<AuthResponse> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    final check = _rateLimiter.checkOtpVerifyAllowed(email);
    if (!check.isAllowed) {
      throw Exception(check.message ?? 'Quá số lần thử xác thực OTP.');
    }

    try {
      final res = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );
      _rateLimiter.resetOtpVerifyAttempts(email);
      return res;
    } on AuthException catch (e) {
      _rateLimiter.recordOtpVerifyFailure(email);
      if (e.message.toLowerCase().contains('expired') || e.code == 'otp_expired') {
        throw Exception('Mã xác thực đã hết hạn. Vui lòng gửi lại mã mới.');
      }
      throw Exception('Mã xác thực không chính xác hoặc đã hết hạn.');
    } catch (e) {
      _rateLimiter.recordOtpVerifyFailure(email);
      rethrow;
    }
  }
}
