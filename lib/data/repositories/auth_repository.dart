import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository([SupabaseClient? client]) : _client = client ?? SupabaseConfig.client;

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
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
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
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
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
    try {
      return await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('expired') || e.code == 'otp_expired') {
        throw Exception('Mã xác thực đã hết hạn. Vui lòng gửi lại mã mới.');
      }
      throw Exception('Mã xác thực không chính xác hoặc đã hết hạn.');
    }
  }
}
