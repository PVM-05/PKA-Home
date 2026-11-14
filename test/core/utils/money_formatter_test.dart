import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/money_formatter.dart';

void main() {
  group('MoneyInputFormatter & parseMoney Tests', () {
    test('parseMoney trích xuất chính xác số tiền từ chuỗi có dấu chấm/phẩy/ký tự', () {
      expect(parseMoney('1.500.000'), equals(1500000));
      expect(parseMoney('50.000 đ'), equals(50000));
      expect(parseMoney('10,000,000 VND'), equals(10000000));
      expect(parseMoney(''), equals(0));
      expect(parseMoney('abc'), equals(0));
    });

    test('formatMoney định dạng chuẩn tiếng Việt', () {
      expect(formatMoney(1500000), equals('1.500.000 đ'));
      expect(formatMoney(1500000, includeSymbol: false), equals('1.500.000'));
      expect(formatMoney(0), equals('0 đ'));
    });

    test('MoneyInputFormatter format đúng khi gõ chữ số', () {
      final formatter = MoneyInputFormatter();
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '1500000',
        selection: TextSelection.collapsed(offset: 7),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1.500.000'));
      expect(result.selection.baseOffset, equals(9));
    });
  });
}
