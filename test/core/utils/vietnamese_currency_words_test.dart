import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/vietnamese_currency_words.dart';

void main() {
  group('VietnameseCurrencyWords Tests', () {
    test('converts 0 correctly', () {
      expect(VietnameseCurrencyWords.toVietnameseWords(0), equals('Không đồng'));
    });

    test('converts standard amounts correctly with capitalized first letter and dong chan', () {
      expect(
        VietnameseCurrencyWords.toVietnameseWords(1500000),
        equals('Một triệu năm trăm nghìn đồng chẵn'),
      );
      expect(
        VietnameseCurrencyWords.toVietnameseWords(250000),
        equals('Hai trăm năm mươi nghìn đồng chẵn'),
      );
      expect(
        VietnameseCurrencyWords.toVietnameseWords(1000000),
        equals('Một triệu đồng chẵn'),
      );
      expect(
        VietnameseCurrencyWords.toVietnameseWords(55000),
        equals('Năm mươi lăm nghìn đồng chẵn'),
      );
      expect(
        VietnameseCurrencyWords.toVietnameseWords(101000),
        equals('Một trăm linh một nghìn đồng chẵn'),
      );
      expect(
        VietnameseCurrencyWords.toVietnameseWords(21000000),
        equals('Hai mươi mốt triệu đồng chẵn'),
      );
    });
  });
}
