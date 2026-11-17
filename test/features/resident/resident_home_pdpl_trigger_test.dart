import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/data/models/issue_model.dart';
import 'package:vivona/data/models/announcement_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/resident_invoice_provider.dart';
import 'package:vivona/data/providers/resident_issue_provider.dart';
import 'package:vivona/data/providers/announcement_provider.dart';
import 'package:vivona/data/providers/link_request_provider.dart';
import 'package:vivona/data/providers/notification_provider.dart';
import 'package:vivona/data/providers/resident_apartment_provider.dart';
import 'package:vivona/core/widgets/pdpl_consent_dialog.dart';
import 'package:vivona/features/resident/screens/resident_home_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResidentLinkNotifier extends StateNotifier<ResidentLinkStatus>
    implements ResidentLinkNotifier {
  FakeResidentLinkNotifier()
      : super(ResidentLinkStatus(status: LinkStatus.linked));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    id: 'user-pdpl-home-1',
    fullName: 'Trần Văn Cư Dân',
    phone: '0909888999',
    role: 'resident',
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
        residentInvoiceProvider.overrideWith((ref) => <InvoiceModel>[]),
        residentIssueProvider.overrideWith((ref) => <IssueModel>[]),
        announcementsStreamProvider.overrideWith(
          (ref) => Stream.value(<AnnouncementModel>[]),
        ),
        unreadNotificationsCountProvider.overrideWith((ref) => 0),
        residentApartmentsProvider.overrideWith((ref) => []),
      ],
      child: const MaterialApp(
        home: ResidentHomeScreen(),
      ),
    );
  }

  group('ResidentHomeScreen PDPL Consent Trigger Tests', () {
    testWidgets(
        'Tự động hiển thị PdplConsentDialog khi mở app lần đầu nếu chưa đồng ý',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Kiểm tra dialog PDPL tự động xuất hiện
      expect(find.text('Bảo Vệ Dữ Liệu Cá Nhân'), findsOneWidget);
      expect(
        find.text('Căn cứ Luật 91/2025/QH15 & NĐ 356/2025/NĐ-CP'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsOneWidget);

      // Chấp thuận và xác nhận
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Xác nhận và Đồng ý'));
      await tester.pumpAndSettle();

      // Dialog đã đóng và trạng thái đã được lưu
      expect(find.text('Bảo Vệ Dữ Liệu Cá Nhân'), findsNothing);
      expect(await PdplConsentManager.hasConsented(), isTrue);
    });

    testWidgets('Không hiển thị dialog nếu cư dân đã chấp thuận trước đó',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        PdplConsentManager.kConsentKey: true,
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Không hiển thị dialog PDPL
      expect(find.text('Bảo Vệ Dữ Liệu Cá Nhân'), findsNothing);
    });
  });
}

