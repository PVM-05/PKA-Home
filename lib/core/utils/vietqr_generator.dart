import 'dart:convert';

/// Tiện ích sinh mã QR chuẩn VietQR (Napas 247) theo quy chuẩn EMVCo QR Code
/// và tạo đường dẫn VietQR Quick Link hỗ trợ mở ứng dụng ngân hàng.
class VietQrGenerator {
  const VietQrGenerator._();

  /// Sinh chuỗi chuẩn EMVCo TLV có gắn CRC16 checksum
  static String generate({
    required String bankBin,
    required String bankAccount,
    required double amount,
    required String memo,
    String? accountName,
  }) {
    final buffer = StringBuffer();

    // 00: Payload Format Indicator (01)
    buffer.write(_tlv('00', '01'));

    // 01: Point of Initiation Method (12 = Dynamic QR)
    buffer.write(_tlv('01', '12'));

    // 38: Merchant Account Information (Napas 247)
    // 00: Napas AID (A000000727)
    // 01: Beneficiary Organization (00: Bank BIN, 01: Bank Account)
    // 02: Service Code (QRIBFTTA)
    final beneficiaryInfo = _tlv('00', bankBin) + _tlv('01', bankAccount);
    final merchantAccountInfo =
        _tlv('00', 'A000000727') +
        _tlv('01', beneficiaryInfo) +
        _tlv('02', 'QRIBFTTA');
    buffer.write(_tlv('38', merchantAccountInfo));

    // 53: Transaction Currency (704 = VND)
    buffer.write(_tlv('53', '704'));

    // 54: Transaction Amount
    buffer.write(_tlv('54', amount.round().toString()));

    // 58: Country Code (VN)
    buffer.write(_tlv('58', 'VN'));

    // 62: Additional Data Field (08: Purpose / Memo)
    if (memo.isNotEmpty) {
      final additionalData = _tlv('08', memo);
      buffer.write(_tlv('62', additionalData));
    }

    // 63: CRC16-CCITT Checksum
    final payloadBeforeCrc = '${buffer.toString()}6304';
    final crc = _computeCrc16(payloadBeforeCrc);
    final crcHex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');

    return '$payloadBeforeCrc$crcHex';
  }

  /// Sinh đường dẫn Quick Link chuẩn Napas/VietQR
  static String generateQuickLinkUrl({
    required String bankBin,
    required String bankAccount,
    required double amount,
    required String memo,
    String? accountName,
  }) {
    final baseUrl = 'https://img.vietqr.io/image/$bankBin-$bankAccount-compact2.png';
    final query = StringBuffer();
    query.write('amount=${amount.round()}');
    query.write('&addInfo=${Uri.encodeComponent(memo)}');
    if (accountName != null && accountName.isNotEmpty) {
      query.write('&accountName=${Uri.encodeComponent(accountName)}');
    }
    return '$baseUrl?$query';
  }

  static String _tlv(String tag, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return '$tag$len$value';
  }

  static int _computeCrc16(String str) {
    int crc = 0xFFFF;
    final bytes = utf8.encode(str);
    for (final byte in bytes) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }
}
