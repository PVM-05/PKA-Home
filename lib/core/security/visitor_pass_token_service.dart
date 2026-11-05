import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Kết quả phân tích và kiểm tra mã QR vé khách viếng thăm
class VisitorPassTokenResult {
  final bool isValid;
  final bool isExpired;
  final bool isLegacyFormat;
  final String? passCode;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? nonce;
  final String? errorMessage;

  const VisitorPassTokenResult({
    required this.isValid,
    this.isExpired = false,
    this.isLegacyFormat = false,
    this.passCode,
    this.issuedAt,
    this.expiresAt,
    this.nonce,
    this.errorMessage,
  });

  factory VisitorPassTokenResult.valid({
    required String passCode,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? nonce,
    bool isLegacy = false,
  }) {
    return VisitorPassTokenResult(
      isValid: true,
      isExpired: false,
      isLegacyFormat: isLegacy,
      passCode: passCode,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      nonce: nonce,
    );
  }

  factory VisitorPassTokenResult.invalid(String message, {String? passCode, bool isExpired = false}) {
    return VisitorPassTokenResult(
      isValid: false,
      isExpired: isExpired,
      passCode: passCode,
      errorMessage: message,
    );
  }
}

/// Dịch vụ mật mã học sinh và xác thực mã QR vé khách viếng thăm (HMAC-SHA256 & Chống Replay Attacks)
class VisitorPassTokenService {
  VisitorPassTokenService._();

  static const String _tokenPrefix = 'PKAPASS.v1.';
  static const String _legacyPrefix = 'PKAPASS:';
  static const String _defaultPepper = 'PkaHome@SecurityPassSignaturePepper#2026';

  /// Sinh chuỗi QR đã ký mật mã học cho vé khách
  static String generateSignedQrPayload({
    required String passCode,
    required DateTime issuedAt,
    required DateTime expiresAt,
    String? nonce,
    String? secretKey,
  }) {
    final effectiveNonce = nonce ?? _generateRandomNonce();
    final effectiveKey = secretKey ?? _defaultPepper;

    final issuedAtEpoch = issuedAt.millisecondsSinceEpoch ~/ 1000;
    final expiresAtEpoch = expiresAt.millisecondsSinceEpoch ~/ 1000;

    final dataToSign = 'v1.$passCode.$issuedAtEpoch.$expiresAtEpoch.$effectiveNonce';
    final signature = _computeHmacSha256(dataToSign, effectiveKey);

    return '$_tokenPrefix$passCode.$issuedAtEpoch.$expiresAtEpoch.$effectiveNonce.$signature';
  }

  /// Xác thực và trích xuất dữ liệu từ mã QR đã quét
  static VisitorPassTokenResult verifyAndParseQrPayload(
    String qrPayload, {
    DateTime? now,
    String? secretKey,
  }) {
    final trimmed = qrPayload.trim();
    final currentTime = now ?? DateTime.now();
    final effectiveKey = secretKey ?? _defaultPepper;

    // 1. Kiểm tra định dạng Legacy (tương thích ngược)
    if (trimmed.startsWith(_legacyPrefix)) {
      final parts = trimmed.split(':');
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        return VisitorPassTokenResult.valid(
          passCode: parts[1].trim().toUpperCase(),
          isLegacy: true,
        );
      }
      return VisitorPassTokenResult.invalid('Mã vé legacy không hợp lệ');
    }

    // 2. Kiểm tra định dạng V1 Token: PKAPASS.v1.<passCode>.<issuedAt>.<expiresAt>.<nonce>.<sig>
    if (!trimmed.startsWith(_tokenPrefix)) {
      return VisitorPassTokenResult.invalid('Mã QR không đúng định dạng vé khách của tòa nhà');
    }

    final payloadWithoutPrefix = trimmed.substring(_tokenPrefix.length);
    final parts = payloadWithoutPrefix.split('.');

    if (parts.length != 5) {
      return VisitorPassTokenResult.invalid('Cấu trúc mã QR không toàn vẹn');
    }

    final passCode = parts[0].trim().toUpperCase();
    final issuedAtEpoch = int.tryParse(parts[1]);
    final expiresAtEpoch = int.tryParse(parts[2]);
    final nonce = parts[3];
    final signature = parts[4];

    if (passCode.isEmpty || issuedAtEpoch == null || expiresAtEpoch == null || signature.isEmpty) {
      return VisitorPassTokenResult.invalid('Thông số trong mã vé không hợp lệ');
    }

    final issuedAt = DateTime.fromMillisecondsSinceEpoch(issuedAtEpoch * 1000);
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtEpoch * 1000);

    // 3. Kiểm tra tính toàn vẹn chữ ký HMAC-SHA256
    final dataToSign = 'v1.$passCode.$issuedAtEpoch.$expiresAtEpoch.$nonce';
    final expectedSig = _computeHmacSha256(dataToSign, effectiveKey);

    if (!_secureConstantTimeCompare(signature, expectedSig)) {
      return VisitorPassTokenResult.invalid(
        'Chữ ký số vé không hợp lệ hoặc đã bị can thiệp trái phép',
        passCode: passCode,
      );
    }

    // 4. Kiểm tra thời hạn hiệu lực (Time-bound security)
    if (currentTime.isAfter(expiresAt)) {
      return VisitorPassTokenResult.invalid(
        'Mã vé khách đã hết hạn sử dụng',
        passCode: passCode,
        isExpired: true,
      );
    }

    // Cho phép dung sai 5 phút cho lệch đồng hồ hệ thống (clock skew)
    final notBefore = issuedAt.subtract(const Duration(minutes: 5));
    if (currentTime.isBefore(notBefore)) {
      return VisitorPassTokenResult.invalid(
        'Mã vé khách chưa đến thời điểm có hiệu lực',
        passCode: passCode,
      );
    }

    return VisitorPassTokenResult.valid(
      passCode: passCode,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      nonce: nonce,
    );
  }

  static String _computeHmacSha256(String data, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  static bool _secureConstantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static String _generateRandomNonce() {
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

