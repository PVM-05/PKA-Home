import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_search_field.dart';

void main() {
  testWidgets('AppSearchField có kích thước cảm ứng tối thiểu >= 48dp', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppSearchField(),
        ),
      ),
    );

    final size = tester.getSize(find.byType(AppSearchField));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('AppSearchField debounce 300ms trước khi kích hoạt onChanged', (
    tester,
  ) async {
    String query = '';
    int callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            debounceDuration: const Duration(milliseconds: 300),
            onChanged: (val) {
              query = val;
              callCount++;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Phòng A0110');
    // Chưa trôi qua 300ms -> chưa gọi callback
    expect(callCount, 0);
    expect(query, '');

    await tester.pump(const Duration(milliseconds: 150));
    expect(callCount, 0);

    // Qua 300ms
    await tester.pump(const Duration(milliseconds: 200));
    expect(callCount, 1);
    expect(query, 'Phòng A0110');
  });

  testWidgets('Nút xóa hiển thị khi có chữ và xóa sạch nội dung khi nhấn', (
    tester,
  ) async {
    bool cleared = false;
    String query = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            onChanged: (val) => query = val,
            onClear: () => cleared = true,
          ),
        ),
      ),
    );

    // Lúc đầu không có nút clear
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // Nhập text
    await tester.enterText(find.byType(TextField), 'Test search');
    await tester.pump();

    // Nút clear xuất hiện
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Bấm nút clear
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(cleared, isTrue);
    expect(query, '');
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}

