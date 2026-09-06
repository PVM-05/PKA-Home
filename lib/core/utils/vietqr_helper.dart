/// Tiện ích sinh mã thanh toán chuẩn VietQR
class VietQrHelper {
  // Cấu hình tài khoản mặc định của Ban Quản Lý chung cư PKA-Home
  static const String defaultBankId = 'MB'; // MBBank (Ngân hàng Quân Đội)
  static const String defaultAccountNo = '0987654321';
  static const String defaultAccountName = 'BQL CHUNG CU PKA HOME';

  /// Sinh nội dung chuyển khoản chuẩn ngắn gọn: [Mã căn hộ] [Kỳ phí]
  static String buildTransferMemo(String apartmentCode, String period) {
    return '$apartmentCode $period';
  }

  /// Sinh URL ảnh mã QR theo chuẩn VietQR QuickLink (dạng compact2)
  static String generateQrUrl({
    required String bankId,
    required String accountNo,
    required double amount,
    required String memo,
    required String accountName,
  }) {
    final cleanAmount = amount.toInt();
    final encodedMemo = Uri.encodeComponent(memo);
    final encodedName = Uri.encodeComponent(accountName);

    return 'https://img.vietqr.io/image/$bankId-$accountNo-compact2.png'
        '?amount=$cleanAmount'
        '&addInfo=$encodedMemo'
        '&accountName=$encodedName';
  }

  /// Sinh URL ảnh VietQR thanh toán hóa đơn theo tài khoản Ban Quản Lý
  static String generateBqlInvoiceQrUrl({
    required String apartmentCode,
    required String period,
    required double amount,
  }) {
    final memo = buildTransferMemo(apartmentCode, period);
    return generateQrUrl(
      bankId: defaultBankId,
      accountNo: defaultAccountNo,
      amount: amount,
      memo: memo,
      accountName: defaultAccountName,
    );
  }
}
