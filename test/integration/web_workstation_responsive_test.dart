import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/accounting_workstation_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/features/management/screens/management_home_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026, 10, 30);
  final adminUser = UserModel(
    id: 'admin-1',
    fullName: 'Trưởng Ban Quản Lý',
    phone: '0901234567',
    role: 'admin',
  );

  final mockInvoices = [
    InvoiceModel(
      id: 'inv-1',
      apartmentId: 'apt-1',
      period: '2026-10',
      dueDate: now.add(const Duration(days: 5)),
      totalAmount: 1500000,
      status: 'unpaid',
      createdAt: now,
      paymentCode: 'INV202610A0110',
      apartment: ApartmentModel(
        id: 'apt-1',
        code: 'a0110',
        buildingCode: 'A',
        floorNumber: 1,
      ),
    ),
  ];

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        accountingWorkstationRawInvoicesProvider.overrideWith((ref) => Future.value(mockInvoices)),
        financialStatsProvider.overrideWith((ref) => Stream.value(FinancialStats(
          paidTotal: 5000000.0,
          unpaidTotal: 1000000.0,
          paidCount: 5,
          unpaidCount: 1,
        ))),
        monthlyRevenueTrendProvider.overrideWith((ref) => Stream.value([])),
        pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(0)),
        pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(0)),
        pendingIssuesCountProvider.overrideWith((ref) => Stream.value(0)),
        rawIssuesStreamProvider.overrideWith((ref) => const Stream.empty()),
        allIssuesProvider.overrideWith((ref) async => []),
        totalResidentsProvider.overrideWith((ref) => Stream.value(10)),
        apartmentsStreamProvider.overrideWith((ref) => Stream.value([])),
        residentsProvider.overrideWith((ref) async => []),
        apartmentsProvider.overrideWith((ref) async => []),
        invoicesProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(
        home: ManagementHomeScreen(),
      ),
    );
  }

  testWidgets('Mobile view (<900dp) renders BottomNavigationBar and no sidebar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Phai co NavigationBar o duoi
    expect(find.byType(NavigationBar), findsOneWidget);
    // Khong duoc co sidebar PKA HOME header ben trai
    expect(find.text('PKA HOME'), findsNothing);
  });

  testWidgets('Desktop view (>=900dp) renders Sidebar and allows navigation to Accounting Workstation', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Khong duoc co NavigationBar o duoi
    expect(find.byType(NavigationBar), findsNothing);
    // Phai co Sidebar co dinh ben trai voi tieu de PKA HOME
    expect(find.text('PKA HOME'), findsOneWidget);

    // Chon tab "Đối soát" tren sidebar
    final workstationItem = find.text('Đối soát');
    expect(workstationItem, findsOneWidget);
    await tester.tap(workstationItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Màn hình trạm làm việc kế toán hiển thị
    expect(find.text('Bàn Làm Việc Kế Toán & Đối Soát'), findsOneWidget);
    expect(find.text('Tổng Phát Hành'), findsOneWidget);
    expect(find.text('A0110'), findsOneWidget);
  });
}
