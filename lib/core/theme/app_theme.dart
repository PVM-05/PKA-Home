import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 1. Màu Sắc (Color Palette)
  static const Color primary = Color(0xFF1E88E5); // Xanh biển
  static const Color secondary = Color(0xFF03A9F4); // Xanh sáng
  static const Color success = Color(0xFF4CAF50); // Xanh lá
  static const Color warning = Color(0xFFFF9800); // Cam
  static const Color error = Color(0xFFF44336); // Đỏ
  static const Color background = Color(0xFFF5F7FA); // Xám rất nhạt
  static const Color surface = Color(0xFFFFFFFF); // Trắng
  static const Color textPrimary = Color(0xFF212121); // Xám đen
  static const Color textSecondary = Color(0xFF757575); // Xám trung tính

  // 2. ThemeData
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      
      // Cấu hình AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Cấu hình Text
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: textPrimary),
        labelSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: textSecondary),
      ),

      // Cấu hình TextField
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),

      // Cấu hình Nút bấm (ElevatedButton)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Cấu hình Nút Text (TextButton)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Cấu hình Card
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1, // Đổ bóng nhẹ
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }
}
