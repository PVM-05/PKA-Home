import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/features/auth/widgets/otp_input_boxes.dart';

void main() {
  group('OtpInputBoxes Widget Tests', () {
    testWidgets('renders 6 input boxes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputBoxes(
              onCompleted: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('calls onCompleted when 6 digits are typed', (tester) async {
      String completedCode = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputBoxes(
              onCompleted: (code) => completedCode = code,
            ),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '${i + 1}');
        await tester.pump();
      }

      expect(completedCode, '123456');
    });

    testWidgets('pasting 6-digit string fills all boxes and triggers onCompleted', (tester) async {
      String completedCode = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputBoxes(
              onCompleted: (code) => completedCode = code,
            ),
          ),
        ),
      );

      final firstBox = find.byType(TextField).first;
      await tester.enterText(firstBox, '987654');
      await tester.pump();

      expect(completedCode, '987654');
    });
  });
}
