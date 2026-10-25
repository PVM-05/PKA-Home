import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:pka_home/features/resident/widgets/equipment_interruption_banner.dart';

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
  final testUser = UserModel(
    id: 'user-res-1',
    fullName: 'Nguyễn Văn A',
    phone: '0901234567',
    role: 'resident',
  );

  final testInvoice = InvoiceModel(
    id: 'inv-1',
    apartmentId: 'apt-1',
    period: '10/2026',
    dueDate: DateTime(2026, 10, 25),
    totalAmount: 1800000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 10, 1),
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
        residentInvoiceProvider.overrideWith((ref) => [testInvoice]),
        residentIssueProvider.overrideWith((ref) => <IssueModel>[]),
        announcementsStreamProvider.overrideWith((ref) => Stream.value(<AnnouncementModel>[])),
        unreadNotificationsCountProvider.overrideWith((ref) => 0),
        residentApartmentsProvider.overrideWith((ref) => []),
      ],
      child: const MaterialApp(
        home: ResidentHomeScreen(),
      ),
    );
  }

  testWidgets('U1: ResidentHomeScreen satisfies 5-tier vertical hierarchy', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 01 Đầu trang
    expect(find.text('Xin chào,'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);

    // 02 Ưu tiên: Hóa đơn
    final invoiceTitleFinder = find.text('Tổng quan hóa đơn');
    expect(invoiceTitleFinder, findsOneWidget);

    // 03 Cần quan tâm: Cảnh báo gián đoạn dịch vụ
    final interruptionFinder = find.byType(EquipmentInterruptionBanner);
    expect(interruptionFinder, findsOneWidget);

    // 04 Thao tác: 4 nút (Thanh toán, Báo sự cố, Hotline, Cẩm nang)
    final quickPayFinder = find.text('Thanh toán');
    final quickReportFinder = find.text('Báo sự cố');
    expect(quickPayFinder, findsOneWidget);
    expect(quickReportFinder, findsOneWidget);

    // 05 Dịch vụ: Dịch vụ & Tiện ích
    final servicesTitleFinder = find.text('Dịch vụ & Tiện ích');
    expect(servicesTitleFinder, findsOneWidget);

    // Check vertical order (dy position):
    // Header is on top
    // Invoice (Tier 2) must be above Interruption (Tier 3)
    final dyInvoice = tester.getTopLeft(invoiceTitleFinder).dy;
    final dyInterruption = tester.getTopLeft(interruptionFinder).dy;
    final dyQuickActions = tester.getTopLeft(quickPayFinder).dy;
    final dyServices = tester.getTopLeft(servicesTitleFinder).dy;

    expect(dyInvoice, lessThan(dyInterruption), reason: 'Tier 2 (Invoice) must be placed above Tier 3 (Interruption)');
    expect(dyInterruption, lessThan(dyQuickActions), reason: 'Tier 3 (Interruption) must be placed above Tier 4 (Quick Actions)');
    expect(dyQuickActions, lessThan(dyServices), reason: 'Tier 4 (Quick Actions) must be placed above Tier 5 (Services)');
  });
}
