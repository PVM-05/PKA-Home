import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/features/management/screens/invoice_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testAdmin = UserModel(
    id: 'admin-1',
    fullName: 'Trưởng BQL',
    role: 'admin',
  );

  final mockInvoices = [
    InvoiceModel(
      id: 'inv-1',
      apartmentId: 'apt-1',
      period: '10/2026',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      totalAmount: 1500000,
      status: 'pending_confirmation',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      apartment: ApartmentModel(id: 'apt-1', code: 'A0101', buildingCode: 'A', floorNumber: 1, area: 70.0, isEmpty: false),
    ),
    InvoiceModel(
      id: 'inv-2',
      apartmentId: 'apt-2',
      period: '10/2026',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      totalAmount: 2000000,
      status: 'unpaid',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      apartment: ApartmentModel(id: 'apt-2', code: 'A0102', buildingCode: 'A', floorNumber: 1, area: 65.0, isEmpty: false),
    ),
    InvoiceModel(
      id: 'inv-3',
      apartmentId: 'apt-3',
      period: '10/2026',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      totalAmount: 1200000,
      status: 'unpaid',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      apartment: ApartmentModel(id: 'apt-3', code: 'B0201', buildingCode: 'B', floorNumber: 2, area: 55.0, isEmpty: false),
    ),
    InvoiceModel(
      id: 'inv-4',
      apartmentId: 'apt-4',
      period: '10/2026',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      totalAmount: 900000,
      status: 'paid',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      apartment: ApartmentModel(id: 'apt-4', code: 'B0202', buildingCode: 'B', floorNumber: 2, area: 50.0, isEmpty: false),
    ),
  ];

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        invoicesProvider.overrideWith((ref) => Future.value(mockInvoices)),
      ],
      child: const MaterialApp(
        home: InvoiceManagementScreen(),
      ),
    );
  }

  testWidgets('InvoiceManagementScreen displays filter chips with exact counts and pending confirmation highlight', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify filter chips have exact counts
    expect(find.text('Tất cả (4)'), findsOneWidget);
    expect(find.text('Chờ xác nhận (1)'), findsOneWidget);
    expect(find.text('Đang nợ (2)'), findsOneWidget);
    expect(find.text('Đã thanh toán (1)'), findsOneWidget);

    // Verify pending confirmation card contains highlight / badge
    expect(find.text('Căn hộ A0101'), findsOneWidget);
    expect(find.text('Chờ xác nhận'), findsWidgets);

    // Tap 'Chờ xác nhận (1)' filter
    await tester.tap(find.text('Chờ xác nhận (1)'));
    await tester.pumpAndSettle();

    // Now only A0101 should be visible, others filtered out
    expect(find.text('Căn hộ A0101'), findsOneWidget);
    expect(find.text('Căn hộ A0102'), findsNothing);
    expect(find.text('Căn hộ B0201'), findsNothing);
    expect(find.text('Căn hộ B0202'), findsNothing);

    // Verify AppBar contains action menu / overflow button
    expect(find.byType(PopupMenuButton<String>), findsWidgets);
  });
}
