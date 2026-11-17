import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/data/models/apartment_model.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/management_provider.dart';
import 'package:vivona/data/providers/vehicle_provider.dart';
import 'package:vivona/data/providers/fee_schedule_provider.dart';
import 'package:vivona/data/providers/invoice_items_provider.dart';
import 'package:vivona/data/repositories/vehicle_repository.dart';
import 'package:vivona/features/management/screens/create_invoice_screen.dart';
import 'package:vivona/features/management/screens/edit_invoice_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeVehicleRepository implements VehicleRepository {
  @override
  Future<Map<String, int>> getVehicleCounts(String apartmentId) async => {
        'motorbike': 2,
        'car': 1,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testAdmin = UserModel(
    id: 'admin_test_1',
    fullName: 'Quản trị viên PKA',
    role: 'management',
    phone: '0901234567',
  );

  final List<ApartmentModel> testApartments = [
    ApartmentModel(
      id: 'apt_1',
      code: 'A0101',
      buildingCode: 'A',
      floorNumber: 1,
      area: 68.5,
      isEmpty: false,
    ),
    ApartmentModel(
      id: 'apt_2',
      code: 'B0205',
      buildingCode: 'B',
      floorNumber: 2,
      area: 85.0,
      isEmpty: false,
    ),
  ];

  final testRates = <String, double>{
    'management': 16500.0,
    'electricity': 3500.0,
    'water': 18000.0,
    'parking_motorcycle': 100000.0,
    'parking_car': 1200000.0,
  };

  final testInvoice = InvoiceModel(
    id: 'inv_test_1',
    apartmentId: 'apt_1',
    period: '11/2026',
    dueDate: DateTime.now().add(const Duration(days: 5)),
    totalAmount: 3250000,
    status: 'unpaid',
    createdAt: DateTime.now(),
    apartment: testApartments.first,
  );

  final testRawItems = <Map<String, dynamic>>[
    {
      'id': 'item_1',
      'fee_type': 'Phí quản lý',
      'unit_price': 16500.0,
      'quantity': 68.5,
      'subtotal': 1130250.0,
    },
    {
      'id': 'item_2',
      'fee_type': 'Tiền điện',
      'unit_price': 3500.0,
      'quantity': 250.0,
      'subtotal': 875000.0,
    },
    {
      'id': 'item_3',
      'fee_type': 'Phí gửi xe máy',
      'unit_price': 100000.0,
      'quantity': 2.0,
      'subtotal': 200000.0,
    },
  ];

  group('CreateInvoiceScreen & EditInvoiceScreen Responsive Impeccable Tests', () {
    testWidgets(
      'CreateInvoiceScreen renders safely on Mobile 320x600 with Text Scale 1.3x without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 600 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
              apartmentsProvider.overrideWith((ref) => Future.value(testApartments)),
              feeScheduleMapProvider.overrideWith((ref) => Future.value(testRates)),
              vehicleRepositoryProvider.overrideWithValue(FakeVehicleRepository()),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: const CreateInvoiceScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Lập hóa đơn mới'), findsOneWidget);
        expect(find.text('Thông tin chung'), findsOneWidget);
        expect(find.text('TỔNG CỘNG'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CreateInvoiceScreen renders Split-Screen workstation on Desktop 1200x900',
      (tester) async {
        tester.view.physicalSize = const Size(1200 * 2, 900 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
              apartmentsProvider.overrideWith((ref) => Future.value(testApartments)),
              feeScheduleMapProvider.overrideWith((ref) => Future.value(testRates)),
              vehicleRepositoryProvider.overrideWithValue(FakeVehicleRepository()),
            ],
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: Size(1200, 900)),
                child: CreateInvoiceScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Lập hóa đơn mới'), findsOneWidget);
        expect(find.text('Thông tin chung'), findsOneWidget);
        expect(find.text('TỔNG CỘNG'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'EditInvoiceScreen renders safely on Mobile 320x600 with Text Scale 1.3x without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 600 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
              invoiceDetailProvider(testInvoice.id).overrideWith(
                (ref) => Future.value(testRawItems),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: EditInvoiceScreen(invoice: testInvoice),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Sửa Hóa đơn 11/2026'), findsOneWidget);
        expect(find.text('Thông tin chung'), findsOneWidget);
        expect(find.text('Chi tiết các khoản phí'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'EditInvoiceScreen renders Split-Screen workstation on Desktop 1200x900',
      (tester) async {
        tester.view.physicalSize = const Size(1200 * 2, 900 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
              invoiceDetailProvider(testInvoice.id).overrideWith(
                (ref) => Future.value(testRawItems),
              ),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(size: Size(1200, 900)),
                child: EditInvoiceScreen(invoice: testInvoice),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Sửa Hóa đơn 11/2026'), findsOneWidget);
        expect(find.text('Thông tin chung'), findsOneWidget);
        expect(find.text('Chi tiết các khoản phí'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
