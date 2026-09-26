import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kFontSizeScaleKey = 'app_font_size_scale';

enum FontSizeOption {
  normal(1.0, 'Tiêu chuẩn', 'Cỡ chữ mặc định của hệ thống'),
  large(1.15, 'Lớn', 'Dễ đọc hơn cho mắt, phù hợp người lớn tuổi'),
  extraLarge(1.30, 'Rất lớn', 'Cỡ chữ tối đa, hiển thị rõ ràng nổi bật');

  final double scale;
  final String label;
  final String description;

  const FontSizeOption(this.scale, this.label, this.description);

  static FontSizeOption fromScale(double scale) {
    if (scale >= 1.25) return FontSizeOption.extraLarge;
    if (scale >= 1.10) return FontSizeOption.large;
    return FontSizeOption.normal;
  }
}

class FontSizeNotifier extends StateNotifier<double> {
  FontSizeNotifier() : super(1.0) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScale = prefs.getDouble(kFontSizeScaleKey);
      if (savedScale != null) {
        state = savedScale;
      }
    } catch (_) {}
  }

  Future<void> setScale(double newScale) async {
    state = newScale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(kFontSizeScaleKey, newScale);
    } catch (_) {}
  }
}

final fontSizeScaleProvider = StateNotifierProvider<FontSizeNotifier, double>((ref) {
  return FontSizeNotifier();
});
