import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_form_scaffold.dart';

void main() {
  testWidgets('AppFormScaffold hiển thị tiêu đề, body và Sticky Footer CTA 48dp', (
    tester,
  ) async {
    bool saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AppFormScaffold(
          title: 'Lập hóa đơn mới',
          primaryButtonLabel: 'Tạo phiếu thu',
          onPrimaryPressed: () => saved = true,
          body: const Column(
            children: [
              Text('Nội dung biểu mẫu'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Lập hóa đơn mới'), findsOneWidget);
    expect(find.text('Nội dung biểu mẫu'), findsOneWidget);
    expect(find.text('Tạo phiếu thu'), findsOneWidget);

    final buttonFinder = find.widgetWithText(ElevatedButton, 'Tạo phiếu thu');
    expect(buttonFinder, findsOneWidget);

    await tester.tap(buttonFinder);
    await tester.pump();

    expect(saved, isTrue);
  });

  testWidgets(
    'AppFormScaffold kích hoạt AppUnsavedChangesGuard khi có thay đổi chưa lưu',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppFormScaffold(
                        title: 'Chỉnh sửa căn hộ',
                        hasUnsavedChanges: true,
                        primaryButtonLabel: 'Lưu thay đổi',
                        onPrimaryPressed: () {},
                        body: const Text('Biểu mẫu có dữ liệu bẩn'),
                      ),
                    ),
                  );
                },
                child: const Text('Mở form'),
              ),
            ),
          ),
        ),
      );

      // Mở màn hình form
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa căn hộ'), findsOneWidget);

      // Bấm nút back trên AppBar
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Hộp thoại cảnh báo chưa lưu xuất hiện
      expect(find.text('Rời khỏi biểu mẫu?'), findsOneWidget);
      expect(
        find.text(
          'Những thông tin bạn vừa nhập chưa được lưu và sẽ bị mất nếu rời khỏi.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tiếp tục nhập'), findsOneWidget);
      expect(find.text('Rời khỏi'), findsOneWidget);

      // Bấm tiếp tục nhập -> vẫn ở lại form
      await tester.tap(find.text('Tiếp tục nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa căn hộ'), findsOneWidget);
      expect(find.text('Rời khỏi biểu mẫu?'), findsNothing);
    },
  );
}

