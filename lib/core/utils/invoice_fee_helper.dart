import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Helper chuẩn hóa tên hiển thị, icon, màu sắc và đơn vị tính cho các mục trong hóa đơn
class InvoiceFeeHelper {
  static String getFeeName(String? rawFeeType) {
    if (rawFeeType == null || rawFeeType.trim().isEmpty) {
      return 'Phí dịch vụ khác';
    }
    final lower = rawFeeType.toLowerCase().trim();
    if (lower == 'management' || lower == 'phí quản lý') {
      return 'Phí quản lý';
    } else if (lower == 'electricity' || lower == 'tiền điện') {
      return 'Tiền điện';
    } else if (lower == 'water' || lower == 'tiền nước') {
      return 'Tiền nước';
    } else if (lower == 'parking_motorbike' || lower == 'phí gửi xe máy' || lower.contains('xe_may')) {
      return 'Phí gửi xe máy';
    } else if (lower == 'parking_car' || lower == 'phí gửi ô tô' || lower == 'parking') {
      return 'Phí gửi ô tô';
    } else if (lower == 'internet') {
      return 'Phí Internet';
    }
    return rawFeeType;
  }

  static String getFeeUnit(String? rawFeeType) {
    if (rawFeeType == null) return '';
    final lower = rawFeeType.toLowerCase().trim();
    if (lower == 'management' || lower.contains('quản lý')) {
      return ' m²';
    } else if (lower == 'electricity' || lower.contains('điện')) {
      return ' kWh';
    } else if (lower == 'water' || lower.contains('nước')) {
      return ' m³';
    } else if (lower.contains('xe') || lower.contains('parking')) {
      return ' xe';
    }
    return '';
  }

  static IconData getFeeIcon(String? rawFeeType) {
    if (rawFeeType == null) return Icons.receipt_long_rounded;
    final lower = rawFeeType.toLowerCase().trim();
    if (lower == 'management' || lower.contains('quản lý')) {
      return Icons.domain_rounded;
    } else if (lower == 'electricity' || lower.contains('điện')) {
      return Icons.electric_bolt_rounded;
    } else if (lower == 'water' || lower.contains('nước')) {
      return Icons.water_drop_rounded;
    } else if (lower == 'parking_motorbike' || lower.contains('xe máy') || lower.contains('xe_may')) {
      return Icons.two_wheeler_rounded;
    } else if (lower == 'parking_car' || lower.contains('ô tô') || lower.contains('o to') || lower == 'parking') {
      return Icons.directions_car_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  static Color getFeeColor(String? rawFeeType) {
    if (rawFeeType == null) return AppTheme.primary;
    final lower = rawFeeType.toLowerCase().trim();
    if (lower == 'management' || lower.contains('quản lý')) {
      return const Color(0xFF3F51B5); // Indigo
    } else if (lower == 'electricity' || lower.contains('điện')) {
      return const Color(0xFFE65100); // Deep Orange
    } else if (lower == 'water' || lower.contains('nước')) {
      return const Color(0xFF0288D1); // Light Blue
    } else if (lower == 'parking_motorbike' || lower.contains('xe máy') || lower.contains('xe_may')) {
      return const Color(0xFF00897B); // Teal
    } else if (lower == 'parking_car' || lower.contains('ô tô') || lower.contains('o to') || lower == 'parking') {
      return const Color(0xFF5E35B1); // Deep Purple
    }
    return AppTheme.primary;
  }
}
