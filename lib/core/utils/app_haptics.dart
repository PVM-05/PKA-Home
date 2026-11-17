import 'package:flutter/services.dart';

/// Bộ quản lý phản hồi xúc giác (Haptic Feedback) chuẩn 2026 cho ứng dụng Vivona.
/// Giúp nâng cao trải nghiệm vi mô (micro-interactions) khi người dùng thao tác.
abstract final class AppHaptics {
  /// Phản hồi nhẹ (dành cho chuyển tab, lọc danh mục, bấm chip, lướt thanh điều hướng).
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Phản hồi vừa (dành cho bấm nút chính, mở dialog/bottom sheet, tương tác nhanh).
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Phản hồi mạnh (dành cho các thao tác trọng yếu: xác nhận thanh toán, xóa, đổi mật khẩu).
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Phản hồi khi chọn lựa chọn (dành cho switch, radio button, date/time picker).
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Phản hồi khi thao tác thành công (thanh toán hoàn tất, gửi phản ánh thành công).
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Phản hồi khi có lỗi hoặc cảnh báo (nhập sai form, vượt hạn mức).
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }
}
