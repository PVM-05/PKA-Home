/// Tiện ích chuyển đổi số tiền (VND) thành chữ đọc tiếng Việt chuẩn mực
/// phục vụ in chứng từ, biên lai thu tiền và quyết toán.
class VietnameseCurrencyWords {
  const VietnameseCurrencyWords._();

  static const List<String> _digits = [
    'không',
    'một',
    'hai',
    'ba',
    'bốn',
    'năm',
    'sáu',
    'bảy',
    'tám',
    'chín',
  ];

  static const List<String> _units = [
    '',
    'nghìn',
    'triệu',
    'tỷ',
    'nghìn tỷ',
    'triệu tỷ',
  ];

  /// Đọc số tiền ra chữ tiếng Việt kèm đuôi "đồng chẵn"
  static String toVietnameseWords(double amount) {
    final intValue = amount.round();
    if (intValue <= 0) return 'Không đồng';

    String s = intValue.toString();
    final List<String> groups = [];
    while (s.isNotEmpty) {
      if (s.length > 3) {
        groups.insert(0, s.substring(s.length - 3));
        s = s.substring(0, s.length - 3);
      } else {
        groups.insert(0, s);
        s = '';
      }
    }

    final List<String> resultParts = [];
    for (int i = 0; i < groups.length; i++) {
      final unitIndex = groups.length - 1 - i;
      final num = int.parse(groups[i]);
      if (num == 0) continue;

      final readFull = i > 0;
      final groupWords = _readThreeDigits(num, readFull);
      if (groupWords.isNotEmpty) {
        final unit = _units[unitIndex % _units.length];
        if (unit.isNotEmpty) {
          resultParts.add('$groupWords $unit');
        } else {
          resultParts.add(groupWords);
        }
      }
    }

    var fullStr = resultParts.join(' ').trim();
    if (fullStr.isEmpty) return 'Không đồng';

    // Viết hoa chữ cái đầu tiên
    fullStr = fullStr[0].toUpperCase() + fullStr.substring(1);
    return '$fullStr đồng chẵn';
  }

  static String _readThreeDigits(int number, bool readFullHundreds) {
    final hundreds = number ~/ 100;
    final tens = (number % 100) ~/ 10;
    final units = number % 10;

    final List<String> words = [];

    if (hundreds > 0 || readFullHundreds) {
      words.add('${_digits[hundreds]} trăm');
    }

    if (tens > 1) {
      words.add('${_digits[tens]} mươi');
      if (units == 1) {
        words.add('mốt');
      } else if (units == 5) {
        words.add('lăm');
      } else if (units > 0) {
        words.add(_digits[units]);
      }
    } else if (tens == 1) {
      words.add('mười');
      if (units == 5) {
        words.add('lăm');
      } else if (units > 0) {
        words.add(_digits[units]);
      }
    } else {
      if ((hundreds > 0 || readFullHundreds) && units > 0) {
        words.add('linh');
        words.add(_digits[units]);
      } else if (units > 0) {
        words.add(_digits[units]);
      }
    }

    return words.join(' ');
  }
}
