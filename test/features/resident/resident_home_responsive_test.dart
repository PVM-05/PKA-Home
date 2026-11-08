import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/models/issue_model.dart';
import 'package:pka_home/data/models/announcement_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/data/providers/resident_issue_provider.dart';
import 'package:pka_home/data/providers/announcement_provider.dart';
import 'package:pka_home/data/providers/link_request_provider.dart';
import 'package:pka_home/data/providers/notification_provider.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';
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
  final testResident = UserModel(
    id: 'user-res-1',
    fullName: 'Trần Cư Dân',
    phone: '0912345678',
    role: 'resident',
  );

  final testUnpaidInvoice = InvoiceModel(
    id: 'inv-unpaid-1',
    apartmentId: 'apt-1',
    period: '11/2026',
    dueDate: DateTime(2026, 11, 25),
    totalAmount: 3250000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 11, 1),
  );

  Widget buildTestApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
    List<InvoiceModel> invoices = const [],
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testResident)),
        residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
        residentInvoiceProvider.overrideWith((ref) => invoices),
        residentIssueProvider.overrideWith((ref) => <IssueModel>[]),
        announcementsStreamProvider.overrideWith((ref) => Stream.value(<AnnouncementModel>[])),
        unreadNotificationsCountProvider.overrideWith((ref) => 0),
        residentApartmentsProvider.overrideWith((ref) => []),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const ResidentHomeScreen(),
        ),
      ),
    );
  }

  group('ResidentHomeScreen Impeccable & Anti-Overflow Tests', () {
    testWidgets('renders tablet/desktop width 1200dp cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 1200,
        height: 900,
        invoices: [testUnpaidInvoice],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Tổng quan hóa đơn'), findsOneWidget);
      expect(find.text('THANH TOÁN NGAY'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with unpaid invoice without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 320,
        height: 640,
        invoices: [testUnpaidInvoice],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Tổng quan hóa đơn'), findsOneWidget);
      expect(find.text('THANH TOÁN NGAY'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with large text scale 1.3x without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
        invoices: [testUnpaidInvoice],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Tổng quan hóa đơn'), findsOneWidget);
    });

    testWidgets('renders mobile with all paid invoices cleanly', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 360,
        height: 640,
        invoices: [],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Đã thanh toán đầy đủ các kỳ phí'), findsOneWidget);
      expect(find.text('XEM HÓA ĐƠN'), findsOneWidget);
    });
  });
}
