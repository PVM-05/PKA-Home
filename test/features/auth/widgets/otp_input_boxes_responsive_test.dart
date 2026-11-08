import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/features/auth/widgets/otp_input_boxes.dart';

void main() {
  group('OtpInputBoxes Responsive & Anti-Overflow Tests', () {
    testWidgets('renders safely on 260dp narrow container without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: OtpInputBoxes(
                  onCompleted: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect 6 textfields rendered without any overflow exception
      expect(find.byType(TextField), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('adapts to ultra-narrow 240dp container without crashing or overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: OtpInputBoxes(
                  onCompleted: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });
  });
}

