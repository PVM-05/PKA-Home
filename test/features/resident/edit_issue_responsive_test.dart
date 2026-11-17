import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/issue_model.dart';
import 'package:vivona/features/resident/screens/edit_issue_screen.dart';

void main() {
  final now = DateTime.now();

  final mockIssue = IssueModel(
    id: 'iss-edit-01',
    apartmentId: 'apt-01',
    reporterId: 'usr-res-01',
    description: 'Bóng đèn hành lang tầng 5 chập chờn, cần kiểm tra gấp',
    status: 'assigned',
    priority: 'medium',
    category: 'electrical',
    createdAt: now.subtract(const Duration(hours: 5)),
    imageUrls: const ['https://example.com/test_img.jpg'],
  );

  Widget createWidget({required IssueModel issue}) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: EditIssueScreen(issue: issue),
      ),
    );
  }

  group('EditIssueScreen Responsive & Impeccable Tests', () {
    testWidgets('renders cleanly on Desktop 1000dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget(issue: mockIssue));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa phản ánh'), findsOneWidget);
      expect(find.text('Mô tả sự cố'), findsOneWidget);
      expect(find.text('Hình ảnh đính kèm'), findsOneWidget);
      expect(find.text('Lưu thay đổi'), findsOneWidget);
      expect(find.text('Bóng đèn hành lang tầng 5 chập chờn, cần kiểm tra gấp'), findsOneWidget);
    });

    testWidgets('renders cleanly on Mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(createWidget(issue: mockIssue));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa phản ánh'), findsOneWidget);
      expect(find.text('Lưu thay đổi'), findsOneWidget);
    });
  });
}

