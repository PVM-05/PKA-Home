import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/resident_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/models/issue_model.dart';
import 'package:pka_home/data/models/announcement_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/data/providers/resident_issue_provider.dart';
import 'package:pka_home/data/providers/announcement_provider.dart';
import 'package:pka_home/data/providers/link_request_provider.dart';
import 'package:pka_home/data/providers/notification_provider.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';
import 'package:pka_home/features/management/screens/management_home_screen.dart';
import 'package:pka_home/features/management/screens/resident_management_screen.dart';
import 'package:pka_home/features/management/screens/invoice_management_screen.dart';
import 'package:pka_home/features/resident/screens/resident_home_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResidentLinkNotifier extends StateNotifier<ResidentLinkStatus> implements ResidentLinkNotifier {
  FakeResidentLinkNotifier() : super(ResidentLinkStatus(status: LinkStatus.linked));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testAdmin = UserModel(
    id: 'admin-1',
    fullName: 'Ban Quản Trị',
    role: 'admin',
  );

  final testResidentUser = UserModel(
    id: 'res-user-1',
    fullName: 'Nguyễn Văn Cư Dân',
    role: 'resident',
  );

  final mockApartment = ApartmentModel(
    id: 'apt-1',
    code: 'A0110',
    buildingCode: 'A',
    floorNumber: 1,
    area: 75.0,
    isEmpty: false,
  );

  final mockInvoice = InvoiceModel(
    id: 'inv-1',
    apartmentId: 'apt-1',
    period: '10/2026',
    dueDate: DateTime.now().add(const Duration(days: 3)),
    totalAmount: 1850000,
    status: 'pending_confirmation',
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    apartment: mockApartment,
  );

  final mockResident = ResidentModel(
    id: 'res-1',
    fullName: 'Nguyễn Văn Cư Dân',
    email: 'cudan@example.com',
    phone: '0901234567',
    role: 'resident',
    isActive: true,
    isLocked: false,
    apartment: mockApartment,
  );

  List<Override> commonAdminOverrides() => [
    authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
    activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
    pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(3)),
    pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(1)),
    pendingIssuesCountProvider.overrideWith((ref) => Stream.value(2)),
    allIssuesProvider.overrideWith((ref) async => []),
    totalResidentsProvider.overrideWith((ref) => Stream.value(356)),
    apartmentsStreamProvider.overrideWith((ref) => Stream.value([
      {'id': 'apt-1', 'code': 'A0110', 'is_empty': false, 'area': 75.0}
    ])),
    financialStatsProvider.overrideWith((ref) => Stream.value(FinancialStats(
      paidTotal: 82500000.0,
      unpaidTotal: 18000000.0,
      paidCount: 230,
      unpaidCount: 50,
    ))),
    monthlyRevenueTrendProvider.overrideWith((ref) => Stream.value([])),
    paymentTransactionsProvider.overrideWith((ref) => []),
    invoicesProvider.overrideWith((ref) async => [mockInvoice]),
    residentsProvider.overrideWith((ref) async => [mockResident]),
    apartmentsProvider.overrideWith((ref) async => [mockApartment]),
  ];

  List<Override> commonResidentOverrides() => [
    authProvider.overrideWith((ref) => FakeAuthNotifier(testResidentUser)),
    residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
    residentInvoiceProvider.overrideWith((ref) => [mockInvoice]),
    residentIssueProvider.overrideWith((ref) => <IssueModel>[]),
    announcementsStreamProvider.overrideWith((ref) => Stream.value(<AnnouncementModel>[])),
    unreadNotificationsCountProvider.overrideWith((ref) => 1),
    residentApartmentsProvider.overrideWith((ref) => [
      {
        'id': 'rel-1',
        'apartment_id': 'apt-1',
        'relation_role': 'owner',
        'apartments': {
          'id': 'apt-1',
          'code': 'A0110',
          'area': 75.0,
        }
      }
    ]),
  ];

  group('B1: Kiểm tra tính co giãn Responsive & Trợ năng trên màn hình 360dp', () {
    testWidgets('1. ManagementHomeScreen không tràn lỗi trên màn hình 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: commonAdminOverrides(),
          child: const MaterialApp(
            home: ManagementHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ban Quản Lý'), findsOneWidget);
      expect(find.text('Thao tác nhanh'), findsOneWidget);
    });

    testWidgets('2. ResidentManagementScreen không tràn lỗi trên màn hình 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: commonAdminOverrides(),
          child: const MaterialApp(
            home: ResidentManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Hiển thị 1/1 người dùng'), findsOneWidget);
      expect(find.text('Bộ lọc'), findsOneWidget);
    });

    testWidgets('3. InvoiceManagementScreen không tràn lỗi trên màn hình 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: commonAdminOverrides(),
          child: const MaterialApp(
            home: InvoiceManagementScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Quản lý Hóa đơn'), findsOneWidget);
      expect(find.text('Tất cả (1)'), findsOneWidget);
    });

    testWidgets('4. ResidentHomeScreen không tràn lỗi trên màn hình 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: commonResidentOverrides(),
          child: const MaterialApp(
            home: ResidentHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Xin chào,'), findsOneWidget);
      expect(find.text('Tổng quan hóa đơn'), findsOneWidget);
      expect(find.text('Dịch vụ & Tiện ích'), findsOneWidget);
    });
  });
}
