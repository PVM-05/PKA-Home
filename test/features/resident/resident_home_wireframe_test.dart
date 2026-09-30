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
    period: '09/2026',
    dueDate: DateTime(2026, 9, 25),
    totalAmount: 1500000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 9, 1),
  );

  Widget createWidgetUnderTest({List<InvoiceModel> invoices = const []}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
        residentInvoiceProvider.overrideWith((ref) => invoices),
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

  testWidgets('ResidentHomeScreen hiển thị số lượng hóa đơn chưa thanh toán và nút THANH TOÁN NGAY', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(invoices: [testInvoice]));
    await tester.pumpAndSettle();

    // 1. Phải có tiêu đề Tổng quan hóa đơn
    expect(find.textContaining('Tổng quan hóa đơn'), findsOneWidget);

    // 2. Phải có dòng số lượng hóa đơn chưa thanh toán theo Wireframe
    expect(find.textContaining('1 hóa đơn chưa thanh toán'), findsOneWidget);

    // 3. Phải có nút THANH TOÁN NGAY
    final payBtn = find.text('THANH TOÁN NGAY');
    expect(payBtn, findsOneWidget);

    // 4. Bấm THANH TOÁN NGAY chuyển sang tab Hóa đơn (NavigationBar index 1)
    await tester.ensureVisible(payBtn);
    await tester.pumpAndSettle();
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);
  });

  testWidgets('ResidentHomeScreen hiển thị nút Đăng xuất nhanh và mở dialog xác nhận', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Phải có nút Logout trên AppBar
    final logoutBtn = find.byTooltip('Đăng xuất');
    expect(logoutBtn, findsOneWidget);

    // Bấm nút Logout hiển thị Dialog xác nhận
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    expect(find.text('Bạn có chắc chắn muốn đăng xuất không?'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Đăng xuất'), findsOneWidget);
  });
}
