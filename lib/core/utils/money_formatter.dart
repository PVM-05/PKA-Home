import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatter tự động định dạng số tiền theo chuẩn phân cách hàng nghìn Việt Nam (VD: `1500000` -> `1.500.000`)
class MoneyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final parsedNumber = int.tryParse(digits);
    if (parsedNumber == null) {
      return oldValue;
    }

    final formattedText = _formatter.format(parsedNumber);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

/// Trích xuất số tiền nguyên (đồng) từ chuỗi có chứa ký tự định dạng, dấu chấm, dấu phẩy
int parseMoney(String s) {
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}

/// Định dạng số tiền nguyên thành chuỗi hiển thị chuẩn Việt Nam (VD: `1500000` -> `1.500.000 đ`)
String formatMoney(int amount, {bool includeSymbol = true}) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  final formatted = formatter.format(amount);
  return includeSymbol ? '$formatted đ' : formatted;
}

