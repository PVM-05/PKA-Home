import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

/// Dữ liệu trả về khi đăng ký mới yếu tố xác thực TOTP
class MfaEnrollData {
  final String factorId;
  final String secret;
  final String qrCodeUri;

  const MfaEnrollData({
    required this.factorId,
    required this.secret,
    required this.qrCodeUri,
  });
}

typedef MfaStatusChecker = Future<bool> Function();
typedef MfaEnrollHandler = Future<MfaEnrollData> Function();
typedef MfaVerifyHandler = Future<bool> Function(String factorId, String code);
typedef MfaUnenrollHandler = Future<void> Function(String factorId);

/// Dịch vụ quản lý xác thực hai yếu tố (Multi-Factor Authentication / TOTP)
class MfaService {
  final SupabaseClient? client;
  final MfaStatusChecker? statusChecker;
  final MfaEnrollHandler? enrollHandler;
  final MfaVerifyHandler? verifyHandler;
  final MfaUnenrollHandler? unenrollHandler;

  MfaService({
    this.client,
    this.statusChecker,
    this.enrollHandler,
    this.verifyHandler,
    this.unenrollHandler,
  });

  SupabaseClient get _effectiveClient => client ?? SupabaseConfig.client;

  /// Kiểm tra tài khoản hiện tại đã kích hoạt MFA TOTP chưa
  Future<bool> isMfaEnrolled() async {
    if (statusChecker != null) {
      return await statusChecker!();
    }

    try {
      final factors = await _effectiveClient.auth.mfa.listFactors();
      return factors.totp.any((f) => f.status == FactorStatus.verified);
    } catch (e) {
      debugPrint('[MfaService] Lỗi kiểm tra trạng thái MFA: $e');
      return false;
    }
  }

  /// Lấy ID của yếu tố xác thực TOTP đang kích hoạt đầu tiên
  Future<String?> getVerifiedFactorId() async {
    try {
      final factors = await _effectiveClient.auth.mfa.listFactors();
      final verified = factors.totp.where((f) => f.status == FactorStatus.verified);
      if (verified.isNotEmpty) {
        return verified.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('[MfaService] Lỗi lấy verified factor ID: $e');
      return null;
    }
  }

  /// Đăng ký mới yếu tố xác thực TOTP (lấy mã bí mật và URI mã QR)
  Future<MfaEnrollData> enrollTotp({String? friendlyName}) async {
    if (enrollHandler != null) {
      return await enrollHandler!();
    }

    try {
      final response = await _effectiveClient.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'PKA-Home',
        friendlyName: friendlyName ?? 'Ban Quản Lý PKA',
      );

      return MfaEnrollData(
        factorId: response.id,
        secret: response.totp?.secret ?? '',
        qrCodeUri: response.totp?.uri ?? '',
      );
    } catch (e) {
      debugPrint('[MfaService] Lỗi khởi tạo đăng ký TOTP: $e');
      throw Exception('Không thể khởi tạo mã xác thực hai yếu tố: $e');
    }
  }

  /// Xác thực mã TOTP 6 số
  Future<bool> verifyTotp({
    required String factorId,
    required String code,
  }) async {
    final cleanCode = code.trim();
    if (cleanCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      throw ArgumentError('Mã xác thực TOTP phải bao gồm đúng 6 chữ số.');
    }

    if (verifyHandler != null) {
      return await verifyHandler!(factorId, cleanCode);
    }

    try {
      final challenge = await _effectiveClient.auth.mfa.challenge(factorId: factorId);
      final verifyRes = await _effectiveClient.auth.mfa.verify(
        factorId: factorId,
        challengeId: challenge.id,
        code: cleanCode,
      );

      return verifyRes.accessToken.isNotEmpty;
    } catch (e) {
      debugPrint('[MfaService] Lỗi xác thực TOTP: $e');
      return false;
    }
  }

  /// Hủy kích hoạt yếu tố xác thực MFA
  Future<void> unenroll({required String factorId}) async {
    if (unenrollHandler != null) {
      return await unenrollHandler!(factorId);
    }

    try {
      await _effectiveClient.auth.mfa.unenroll(factorId);
    } catch (e) {
      debugPrint('[MfaService] Lỗi hủy đăng ký MFA: $e');
      throw Exception('Không thể hủy kích hoạt xác thực hai yếu tố: $e');
    }
  }
}

/// Riverpod Provider cung cấp MfaService
final mfaServiceProvider = Provider<MfaService>((ref) {
  return MfaService();
});
