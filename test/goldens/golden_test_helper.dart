import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vivona/core/theme/app_theme.dart';

/// Khởi tạo môi trường kiểm thử Golden Tests cô lập,
/// ngăn chặn việc tải font từ mạng bất đồng bộ để đảm bảo pixel-perfect rendering.
void setupGoldenTests() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Helper nạp widget trong môi trường giả lập kích thước chuẩn và giao diện thống nhất.
Future<void> pumpGoldenWidget(
  WidgetTester tester,
  Widget widget, {
  Size surfaceSize = const Size(420, 320),
  ThemeData? theme,
  bool isDark = false,
  Color? backgroundColor,
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final activeTheme = theme ?? (isDark ? AppTheme.darkTheme : AppTheme.lightTheme);
  final bg = backgroundColor ?? activeTheme.scaffoldBackgroundColor;

  await tester.pumpWidget(
    MaterialApp(
      theme: activeTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: widget,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}
