import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Dịch vụ tích hợp Cổng thanh toán trực tuyến VNPay chuẩn 2.1.0
/// Đảm bảo ký số HMAC-SHA512 an toàn, tuân thủ tiêu chuẩn tài chính thương mại B2B SaaS.
class VnpayService {
  static const String sandboxEndpoint = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
  static const String productionEndpoint = 'https://vnpayment.vn/paymentv2/vpcpay.html';

  /// Tạo URL thanh toán VNPay có kèm chữ ký số HMAC-SHA512
  static String createPaymentUrl({
    required String tmnCode,
    required String hashSecret,
    required double amount,
    required String txnRef,
    required String orderInfo,
    required String returnUrl,
    String? bankCode,
    String ipAddress = '127.0.0.1',
    DateTime? createDate,
    bool isSandbox = false,
  }) {
    final now = createDate ?? DateTime.now();
    final createDateStr = _formatDate(now);

    final params = <String, String>{
      'vnp_Version': '2.1.0',
      'vnp_Command': 'pay',
      'vnp_TmnCode': tmnCode,
      'vnp_Amount': (amount * 100).toInt().toString(),
      'vnp_CurrCode': 'VND',
      'vnp_TxnRef': txnRef,
      'vnp_OrderInfo': orderInfo,
      'vnp_OrderType': 'other',
      'vnp_Locale': 'vn',
      'vnp_ReturnUrl': returnUrl,
      'vnp_IpAddr': ipAddress,
      'vnp_CreateDate': createDateStr,
    };

    if (bankCode != null && bankCode.trim().isNotEmpty) {
      params['vnp_BankCode'] = bankCode.trim();
    }

    final secureHash = generateChecksum(params, hashSecret);
    params['vnp_SecureHash'] = secureHash;

    final baseUrl = isSandbox ? sandboxEndpoint : productionEndpoint;
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$baseUrl?$queryString';
  }

  /// Sinh mã kiểm tra chữ ký số HMAC-SHA512 từ danh sách tham số
  static String generateChecksum(Map<String, String> params, String hashSecret) {
    // Sắp xếp các tham số theo thứ tự alphabet mã ASCII của key
    final sortedKeys = params.keys
        .where((k) =>
            k.startsWith('vnp_') &&
            k != 'vnp_SecureHash' &&
            k != 'vnp_SecureHashType' &&
            params[k] != null &&
            params[k]!.isNotEmpty)
        .toList()
      ..sort();

    final signData = sortedKeys
        .map((k) => '${Uri.encodeComponent(k)}=${Uri.encodeComponent(params[k]!)}')
        .join('&');

    final keyBytes = utf8.encode(hashSecret);
    final dataBytes = utf8.encode(signData);
    final hmac = Hmac(sha512, keyBytes);
    final digest = hmac.convert(dataBytes);

    return digest.toString();
  }

  /// Xác thực chữ ký số do VNPay trả về
  static bool verifyChecksum(Map<String, String> params, String hashSecret) {
    final receivedHash = params['vnp_SecureHash'];
    if (receivedHash == null || receivedHash.isEmpty) {
      return false;
    }

    final calculatedHash = generateChecksum(params, hashSecret);
    return calculatedHash.toLowerCase() == receivedHash.toLowerCase();
  }

  /// Định dạng DateTime thành định dạng `yyyyMMddHHmmss` theo quy định của VNPay
  static String _formatDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$year$month$day$hour$minute$second';
  }

  /// Danh mục thông điệp mô tả mã lỗi phản hồi từ cổng VNPay bằng tiếng Việt chuẩn
  static String getResponseDescription(String responseCode) {
    switch (responseCode) {
      case '00':
        return 'Giao dịch thành công';
      case '07':
        return 'Trừ tiền thành công. Giao dịch bị nghi ngờ gian lận (liên quan tới lừa đảo hoặc giao dịch bất thường).';
      case '09':
        return 'Giao dịch không thành công: Thẻ/Tài khoản chưa đăng ký dịch vụ InternetBanking tại ngân hàng.';
      case '10':
        return 'Giao dịch không thành công: Khách hàng xác thực thông tin thẻ/tài khoản không đúng quá 3 lần.';
      case '11':
        return 'Giao dịch không thành công: Đã hết hạn chờ thanh toán. Xin vui lòng thực hiện lại giao dịch.';
      case '12':
        return 'Giao dịch không thành công: Thẻ/Tài khoản bị khóa.';
      case '13':
        return 'Giao dịch không thành công: Quý khách nhập sai mật khẩu xác thực giao dịch (OTP).';
      case '24':
        return 'Giao dịch không thành công: Quý khách hàng hủy giao dịch.';
      case '51':
        return 'Giao dịch không thành công: Tài khoản của quý khách không đủ số dư để thực hiện giao dịch.';
      case '65':
        return 'Giao dịch không thành công: Tài khoản đã vượt quá hạn mức giao dịch trong ngày.';
      case '75':
        return 'Ngân hàng thanh toán đang bảo trì.';
      case '79':
        return 'Giao dịch không thành công: Khách hàng nhập sai mật khẩu thanh toán quá số lần quy định.';
      default:
        return 'Lỗi không xác định từ cổng thanh toán VNPay (Mã: $responseCode).';
    }
  }
}
