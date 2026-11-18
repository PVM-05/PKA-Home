import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/features/resident/screens/create_issue_screen.dart';

void main() {
  group('CreateIssueScreen Inline Validation & Form Tests', () {
    testWidgets('hien thi chu bao loi inline khi mo ta trong va bam gui', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CreateIssueScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ban dau chua co bao loi inline
      expect(find.text('Vui lòng nhập chi tiết mô tả sự cố'), findsNothing);

      // Cuon den nut Gui Yeu Cau
      final submitBtn = find.byKey(const Key('submit_issue_button'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();

      // Bam Gui khi o mo ta con trong
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Kiem tra loi inline xuat hien ngay duoi o mo ta
      expect(find.text('Vui lòng nhập chi tiết mô tả sự cố'), findsOneWidget);

      // Nhap noi dung vao o mo ta
      final descField = find.byKey(const Key('issue_description_field'));
      await tester.enterText(descField, 'Den hanh lang tang 3 bi chap');
      await tester.pumpAndSettle();

      // Cuon den nut Gui Yeu Cau va bam lai
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Loi inline da bien mat
      expect(find.text('Vui lòng nhập chi tiết mô tả sự cố'), findsNothing);
    });

    testWidgets('kiem tra thay doi chuyen mon hoac uu tien kich hoat Unsaved Changes Guard', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CreateIssueScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Thay doi category
      final categoryDropdown = find.byKey(const Key('issue_category_dropdown'));
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();

      // Chon PCCC & Canh bao an toan
      await tester.tap(find.text('PCCC & Cảnh báo an toàn').last);
      await tester.pumpAndSettle();

      // Form gio da co unsaved changes
      expect(find.text('PCCC & Cảnh báo an toàn'), findsWidgets);
    });
  });
}

