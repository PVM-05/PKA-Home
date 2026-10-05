import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/features/management/widgets/bulk_invoice_dialog.dart';

void main() {
  testWidgets('BulkInvoiceDialog hiển thị đầy đủ các trường cấu hình tạo hóa đơn hàng loạt', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BulkInvoiceDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề
    expect(find.text('Tạo hóa đơn hàng loạt'), findsOneWidget);

    // 2. Kiểm tra các trường nhập liệu
    expect(find.text('Kỳ hóa đơn *'), findsOneWidget);
    expect(find.text('Hạn thanh toán *'), findsOneWidget);
    expect(find.text('Phí quản lý (đ/m²)'), findsOneWidget);

    // 3. Kiểm tra nút bấm
    expect(find.text('Hủy'), findsOneWidget);
    expect(find.text('Tạo hóa đơn'), findsOneWidget);
  });
}
