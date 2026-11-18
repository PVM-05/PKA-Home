import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_unsaved_changes_guard.dart';

void main() {
  group('AppUnsavedChangesGuard Widget Tests', () {
    testWidgets('cho phep pop truc tiep khi khong co du lieu chua luu (hasUnsavedChanges = false)', (tester) async {
      bool isPopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const AppUnsavedChangesGuard(
                        hasUnsavedChanges: false,
                        child: Scaffold(
                          body: Text('Form rong'),
                        ),
                      ),
                    ),
                  );
                  isPopped = true;
                },
                child: const Text('Mo Form'),
              ),
            ),
          ),
        ),
      );

      // Mo form
      await tester.tap(find.text('Mo Form'));
      await tester.pumpAndSettle();
      expect(find.text('Form rong'), findsOneWidget);

      // Back pop
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // Form duoc pop thang ma khong hien dialog
      expect(find.text('Rời khỏi biểu mẫu?'), findsNothing);
      expect(isPopped, isTrue);
    });

    testWidgets('chan pop va hien thi dialog khi hasUnsavedChanges = true, bam Tiep tuc giu nguyen trang', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const AppUnsavedChangesGuard(
                        hasUnsavedChanges: true,
                        child: Scaffold(
                          body: Text('Form dang go do'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Mo Form'),
              ),
            ),
          ),
        ),
      );

      // Mo form
      await tester.tap(find.text('Mo Form'));
      await tester.pumpAndSettle();
      expect(find.text('Form dang go do'), findsOneWidget);

      // Trigger back pop
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // Dialog xac nhan xuat hien
      expect(find.text('Rời khỏi biểu mẫu?'), findsOneWidget);
      expect(find.text('Những thông tin bạn vừa nhập chưa được lưu và sẽ bị mất nếu rời khỏi.'), findsOneWidget);

      // Bam "Tiếp tục nhập"
      await tester.tap(find.text('Tiếp tục nhập'));
      await tester.pumpAndSettle();

      // Dialog dong nhung trang van con nguyen
      expect(find.text('Rời khỏi biểu mẫu?'), findsNothing);
      expect(find.text('Form dang go do'), findsOneWidget);
    });

    testWidgets('chan pop va khi bam Roi khoi thi pop thanh cong', (tester) async {
      bool isPopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const AppUnsavedChangesGuard(
                        hasUnsavedChanges: true,
                        child: Scaffold(
                          body: Text('Form dang go do'),
                        ),
                      ),
                    ),
                  );
                  isPopped = true;
                },
                child: const Text('Mo Form'),
              ),
            ),
          ),
        ),
      );

      // Mo form
      await tester.tap(find.text('Mo Form'));
      await tester.pumpAndSettle();
      expect(find.text('Form dang go do'), findsOneWidget);

      // Trigger back pop
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // Bam "Rời khỏi"
      await tester.tap(find.text('Rời khỏi'));
      await tester.pumpAndSettle();

      // Da pop thanh cong
      expect(find.text('Form dang go do'), findsNothing);
      expect(isPopped, isTrue);
    });
  });
}

