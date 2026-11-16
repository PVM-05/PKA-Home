import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/widgets/app_empty_state.dart';
import 'package:pka_home/core/widgets/app_skeleton_shimmer.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/data/providers/invoice_items_provider.dart';
import 'package:pka_home/features/management/screens/invoice_management_screen.dart';
import 'package:pka_home/features/management/screens/management_invoice_detail_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('InvoiceManagementScreen & Detail A11y & Shimmer Tests', () {
    final testManager = UserModel(
      id: 'mgr-001',
      fullName: 'Kế toán trưởng',
      role: 'management',
    );

    final dummyInvoice = InvoiceModel(
      id: 'inv-detail-001',
      apartmentId: 'apt-001',
      period: '11/2026',
      dueDate: DateTime.parse('2026-11-25'),
      totalAmount: 1500000,
      status: 'unpaid',
      createdAt: DateTime.parse('2026-11-01'),
    );

    testWidgets('hiển thị AppEmptyState khi lọc hóa đơn không có kết quả', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(testManager)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            invoicesProvider.overrideWith((ref) async => [dummyInvoice]),
          ],
          child: const MaterialApp(
            home: InvoiceManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Nhập từ khóa tìm kiếm không khớp căn hộ nào để kích hoạt filter empty
      await tester.enterText(find.byType(TextField), 'CAN_HO_KHONG_CO_THUC_9999');
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
    });

    testWidgets('ManagementInvoiceDetailScreen: hiển thị AppSkeletonShimmer khi đang tải dữ liệu', (tester) async {
      final completer = Completer<List<Map<String, dynamic>>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceDetailProvider('inv-detail-001').overrideWith(
              (ref) => completer.future,
            ),
          ],
          child: MaterialApp(
            home: ManagementInvoiceDetailScreen(invoice: dummyInvoice),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(AppSkeletonShimmer), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('ManagementInvoiceDetailScreen: có Semantics trợ năng số tiền tiếng Việt chuẩn', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceDetailProvider('inv-detail-001').overrideWith(
              (ref) async => [
                {
                  'fee_type': 'management',
                  'unit_price': 1500000,
                  'quantity': 1,
                  'subtotal': 1500000,
                }
              ],
            ),
          ],
          child: MaterialApp(
            home: ManagementInvoiceDetailScreen(invoice: dummyInvoice),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('Một triệu năm trăm nghìn đồng chẵn'),
      );

      expect(semanticsFinder, findsOneWidget);
    });
  });
}
