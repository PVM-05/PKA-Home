import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_text_field.dart';

void main() {
  group('AppTextField Widget Tests', () {
    testWidgets('đảm bảo chiều cao vùng chạm tối thiểu >= 48dp và hiển thị label/hint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: AppTextField(
                labelText: 'Mã căn hộ',
                hintText: 'VD: A0110',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
            ),
          ),
        ),
      );

      final fieldFinder = find.byType(AppTextField);
      expect(fieldFinder, findsOneWidget);
      expect(find.text('Mã căn hộ'), findsOneWidget);

      final size = tester.getSize(fieldFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('hỗ trợ kiểm tra hợp lệ Form validator và onChanged', (tester) async {
      final formKey = GlobalKey<FormState>();
      String latestValue = '';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppTextField(
                  labelText: 'Số điện thoại',
                  onChanged: (v) => latestValue = v,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Không được bỏ trống' : null,
                ),
              ),
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Không được bỏ trống'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '0901234567');
      expect(latestValue, '0901234567');
      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
