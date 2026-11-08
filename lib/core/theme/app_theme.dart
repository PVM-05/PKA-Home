import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppStatusColors {
  static const Color paid = Color(0xFF4CAF50); // Xanh lá
  static const Color unpaid = Color(0xFFF44336); // Đỏ
  static const Color pendingConfirmation = Color(0xFFFFB300); // Vàng/Cam
  
  static const Color priorityHigh = Color(0xFFD32F2F); // Đỏ đậm
  static const Color priorityMedium = Color(0xFFFF9800); // Cam
  static const Color priorityLow = Color(0xFF64B5F6); // Xanh dương nhạt
  
  static const Color pending = Color(0xFFFF9800); // Cam
  static const Color rejected = Color(0xFFE57373); // Đỏ nhạt
}

class AppGradients {
  static const LinearGradient brandPrimary = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroDark = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardHighlight = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF334155)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldSuccess = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  static const List<BoxShadow> softSm = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> softMd = [
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardGlow = [
    BoxShadow(
      color: Color(0x1F2563EB),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}

class AppTheme {
  // 1. Màu Sắc Modern Enterprise PropTech (Color Palette)
  static const Color sapphire = Color(0xFF2563EB); // Sapphire Blue
  static const Color slate900 = Color(0xFF0F172A); // Deep Slate Navy
  static const Color slate800 = Color(0xFF1E293B); // Dark Slate
  static const Color slate700 = Color(0xFF334155); // Muted Slate
  static const Color slate100 = Color(0xFFF1F5F9); // Light Slate
  static const Color slate50 = Color(0xFFF8FAFC);  // Off-white Slate
  static const Color emerald = Color(0xFF10B981);  // Success Emerald
  static const Color amber = Color(0xFFF59E0B);    // Warning Amber
  static const Color rose = Color(0xFFF43F5E);     // Error Rose

  static const Color primary = sapphire;
  static const Color secondary = Color(0xFF0EA5E9); // Sky Cyan
  static const Color success = emerald;
  static const Color warning = amber;
  static const Color error = rose;
  static const Color background = slate50;
  static const Color surface = Color(0xFFFFFFFF); // Trắng
  static const Color textPrimary = Color(0xFF0F172A); // Slate đen sắc nét
  static const Color textSecondary = Color(0xFF64748B); // Slate trung tính
  static const Color border = Color(0xFFE2E8F0); // Viền Slate nhạt tinh tế
  static const Color warningBackground = Color(0xFFFFFBEB); // Nền vàng ấm
  static const Color warningText = Color(0xFFB45309); // Chữ cảnh báo
  static const Color warningBorder = Color(0xFFFDE68A); // Viền cảnh báo

  // Spacing chuẩn (theme_spec.md)
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // BorderRadius chuẩn (theme_spec.md)
  static final BorderRadius radiusSm = BorderRadius.circular(8.0);
  static final BorderRadius radiusMd = BorderRadius.circular(12.0);
  static final BorderRadius radiusLg = BorderRadius.circular(16.0);

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
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),

      // Cấu hình NavigationBar Material 3
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 65,
        backgroundColor: surface,
      ),
    );
  }

  // 3. Dark Theme
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    const darkSurface = Color(0xFF1E1E1E);
    const darkBackground = Color(0xFF121212);
    const darkTextPrimary = Colors.white;
    const darkTextSecondary = Colors.white70;

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: darkSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground,
      
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: darkTextPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: darkTextPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: darkTextPrimary),
        labelSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: darkTextSecondary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(color: darkTextSecondary),
      ),

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
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),

      // Cấu hình NavigationBar Material 3
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: primary.withValues(alpha: 0.25),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 65,
        backgroundColor: darkSurface,
      ),
    );
  }
}
