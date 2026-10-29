import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/vietnamese_currency_text_formatter.dart';

void main() {
  group('VietnameseCurrencyTextFormatter Tests', () {
    test('converts zero amount to "Không đồng"', () {
      expect(VietnameseCurrencyTextFormatter.toWords(0), equals('Không đồng'));
    });

    test('converts round thousands amounts correctly', () {
      expect(
        VietnameseCurrencyTextFormatter.toWords(50000),
        equals('Năm mươi nghìn đồng'),
      );
      expect(
        VietnameseCurrencyTextFormatter.toWords(150000),
        equals('Một trăm năm mươi nghìn đồng'),
      );
    });

    test('converts millions amounts with mixed digits', () {
      expect(
        VietnameseCurrencyTextFormatter.toWords(1250000),
        equals('Một triệu hai trăm năm mươi nghìn đồng'),
      );
      expect(
        VietnameseCurrencyTextFormatter.toWords(2005000),
        equals('Hai triệu không trăm linh năm nghìn đồng'),
      );
      expect(
        VietnameseCurrencyTextFormatter.toWords(15000000),
        equals('Mười lăm triệu đồng'),
      );
      expect(
        VietnameseCurrencyTextFormatter.toWords(101000000),
        equals('Một trăm linh một triệu đồng'),
      );
    });

    test('converts billions amounts with zeros and ones', () {
      expect(
        VietnameseCurrencyTextFormatter.toWords(1001001001),
        equals('Một tỷ không trăm linh một triệu không trăm linh một nghìn không trăm linh một đồng'),
      );
    });

    test('handles small numbers with special words (mốt, lăm, mười, linh)', () {
      expect(VietnameseCurrencyTextFormatter.toWords(1), equals('Một đồng'));
      expect(VietnameseCurrencyTextFormatter.toWords(5), equals('Năm đồng'));
      expect(VietnameseCurrencyTextFormatter.toWords(10), equals('Mười đồng'));
      expect(VietnameseCurrencyTextFormatter.toWords(11), equals('Mười một đồng'));
      expect(VietnameseCurrencyTextFormatter.toWords(15), equals('Mười lăm đồng'));
      expect(VietnameseCurrencyTextFormatter.toWords(21), equals('Hai mươi mốt đồng'));
      expect(VietnameseCurrencyTextFormatter.toWords(25), equals('Hai mươi lăm đồng'));
      expect(VietnameseCurrencyTextFormatter.toWords(105), equals('Một trăm linh năm đồng'));
      expect(VietnameseCurrencyTextFormatter.toWords(115), equals('Một trăm mười lăm đồng'));
    });

    test('handles decimal and negative numbers safely', () {
      // Decimal amounts should be rounded
      expect(
        VietnameseCurrencyTextFormatter.toWords(1250000.4),
        equals('Một triệu hai trăm năm mươi nghìn đồng'),
      );
      expect(
        VietnameseCurrencyTextFormatter.toWords(1250000.8),
        equals('Một triệu hai trăm năm mươi nghìn không trăm linh một đồng'),
      );

      // Negative values should be converted via absolute magnitude
      expect(
        VietnameseCurrencyTextFormatter.toWords(-50000),
        equals('Năm mươi nghìn đồng'),
      );
    });
  });
}
