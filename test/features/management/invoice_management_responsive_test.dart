import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/apartment_model.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/management_provider.dart';
import 'package:vivona/data/providers/role_delegation_provider.dart';
import 'package:vivona/features/management/screens/invoice_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testAdmin = UserModel(
    id: 'admin-1',
    fullName: 'Trưởng BQL PKA',
    role: 'admin',
  );

  final mockInvoices = [
    InvoiceModel(
      id: 'inv-1',
      apartmentId: 'apt-1',
      period: '11/2026',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      totalAmount: 15500000,
      status: 'pending_confirmation',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      apartment: ApartmentModel(
        id: 'apt-1',
        code: 'A0110',
        buildingCode: 'A',
        floorNumber: 1,
        area: 75.0,
        isEmpty: false,
      ),
    ),
    InvoiceModel(
      id: 'inv-2',
      apartmentId: 'apt-2',
      period: '11/2026',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      totalAmount: 23400000,
      status: 'unpaid',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      apartment: ApartmentModel(
        id: 'apt-2',
        code: 'A0210',
        buildingCode: 'A',
        floorNumber: 2,
        area: 85.0,
        isEmpty: false,
      ),
    ),
    InvoiceModel(
      id: 'inv-3',
      apartmentId: 'apt-3',
      period: '11/2026',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      totalAmount: 8900000,
      status: 'paid',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      apartment: ApartmentModel(
        id: 'apt-3',
        code: 'B0502',
        buildingCode: 'B',
        floorNumber: 5,
        area: 60.0,
        isEmpty: false,
      ),
    ),
  ];

  Widget buildTestApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        invoicesProvider.overrideWith((ref) async => mockInvoices),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const InvoiceManagementScreen(),
        ),
      ),
    );
  }

  group('InvoiceManagementScreen Responsive & Impeccable Tests', () {
    testWidgets('renders desktop enterprise workstation at 1200dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1200, height: 800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Hóa đơn'), findsOneWidget);
      expect(find.textContaining('A0110'), findsWidgets);
    });

    testWidgets('renders narrow mobile 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 640));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Hóa đơn'), findsOneWidget);
      expect(find.textContaining('A0110'), findsWidgets);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Hóa đơn'), findsOneWidget);
    });
  });
}
