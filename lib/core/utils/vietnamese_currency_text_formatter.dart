import 'package:intl/intl.dart';

/// Tiện ích đọc và định dạng số tiền bằng chữ tiếng Việt chuẩn mực cho Hóa đơn & Biên lai (PKA-Home)
class VietnameseCurrencyTextFormatter {
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

  static const List<String> _groupUnits = [
    '',
    'nghìn',
    'triệu',
    'tỷ',
    'nghìn tỷ',
    'triệu tỷ',
    'tỷ tỷ',
  ];

  /// Định dạng số tiền sang chuỗi hiển thị có dấu chấm phân cách (VD: `1250000` -> `"1.250.000 đ"`)
  static String format(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(amount).trim();
  }

  /// Chuyển đổi số tiền thành chữ tiếng Việt chuẩn xác.
  /// Ví dụ: `1250000` -> `"Một triệu hai trăm năm mươi nghìn đồng"`
  static String toWords(num amount, {bool appendChan = false}) {
    final int rounded = amount.round().abs();
    if (rounded == 0) {
      return appendChan ? 'Không đồng chẵn' : 'Không đồng';
    }

    final List<int> chunks = [];
    int temp = rounded;
    while (temp > 0) {
      chunks.add(temp % 1000);
      temp ~/= 1000;
    }

    // Tìm nhóm khác 0 cao nhất
    int highestNonZeroIndex = chunks.length - 1;
    while (highestNonZeroIndex >= 0 && chunks[highestNonZeroIndex] == 0) {
      highestNonZeroIndex--;
    }

    if (highestNonZeroIndex < 0) {
      return appendChan ? 'Không đồng chẵn' : 'Không đồng';
    }

    final List<String> parts = [];

    for (int i = highestNonZeroIndex; i >= 0; i--) {
      final int chunk = chunks[i];
      if (chunk == 0) {
        continue;
      }

      final int h = chunk ~/ 100;
      final int t = (chunk % 100) ~/ 10;
      final int u = chunk % 10;
      final bool isHighestGroup = (i == highestNonZeroIndex);

      final String chunkWords = _readThreeDigits(
        h,
        t,
        u,
        isHighestGroup: isHighestGroup,
      );

      if (chunkWords.isNotEmpty) {
        final String unit = i < _groupUnits.length ? _groupUnits[i] : '';
        if (unit.isNotEmpty) {
          parts.add('$chunkWords $unit');
        } else {
          parts.add(chunkWords);
        }
      }
    }

    final String text = parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) {
      return appendChan ? 'Không đồng chẵn' : 'Không đồng';
    }

    final String capitalized = '${text[0].toUpperCase()}${text.substring(1)}';
    final String suffix = appendChan ? ' đồng chẵn' : ' đồng';
    return '$capitalized$suffix';
  }

  static String _readThreeDigits(
    int h,
    int t,
    int u, {
    required bool isHighestGroup,
  }) {
    final List<String> words = [];

    // 1. Hàng trăm
    if (!isHighestGroup) {
      words.add('${_digits[h]} trăm');
    } else if (h > 0) {
      words.add('${_digits[h]} trăm');
    }

    // 2. Hàng chục
    if (t > 1) {
      words.add('${_digits[t]} mươi');
    } else if (t == 1) {
      words.add('mười');
    } else if (t == 0) {
      if (u > 0) {
        if (h > 0 || !isHighestGroup) {
          words.add('linh');
        }
      }
    }

    // 3. Hàng đơn vị
    if (u > 0) {
      if (u == 1) {
        if (t > 1) {
          words.add('mốt');
        } else {
          words.add('một');
        }
      } else if (u == 5) {
        if (t >= 1) {
          words.add('lăm');
        } else {
          words.add('năm');
        }
      } else {
        words.add(_digits[u]);
      }
    }

    return words.join(' ');
  }
}
