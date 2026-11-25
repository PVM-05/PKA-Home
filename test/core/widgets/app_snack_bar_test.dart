import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_snack_bar.dart';

void main() {
  testWidgets('AppSnackBar.showSuccess hiển thị SnackBar với icon check và nền xanh lá', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => AppSnackBar.showSuccess(ctx, 'Thao tác thành công!'),
                child: const Text('Bấm'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bấm'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Thao tác thành công!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, AppTheme.textSuccess);
    expect(snackBar.behavior, SnackBarBehavior.floating);
  });

  testWidgets('AppSnackBar.showError hiển thị SnackBar với icon cảnh báo và nền đỏ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => AppSnackBar.showError(ctx, 'Đã xảy ra lỗi kết nối!'),
                child: const Text('Bấm lỗi'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bấm lỗi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Đã xảy ra lỗi kết nối!'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, AppTheme.textError);
    expect(snackBar.behavior, SnackBarBehavior.floating);
  });

  testWidgets('AppSnackBar.showInfo hiển thị SnackBar với icon info và nền xanh dương', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => AppSnackBar.showInfo(ctx, 'Thông báo hướng dẫn'),
                child: const Text('Bấm info'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bấm info'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Thông báo hướng dẫn'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, AppTheme.primary);
    expect(snackBar.behavior, SnackBarBehavior.floating);
  });
}

