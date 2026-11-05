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

final _testInvoiceStreamProvider = StateProvider<List<InvoiceModel>>((ref) => []);

void main() {
  final testUser = UserModel(
    id: 'user-switch-test',
    fullName: 'Cư dân Kiểm Thử',
    phone: '0988776655',
    role: 'resident',
  );

  final invoiceA = InvoiceModel(
    id: 'inv-aptA-1',
    apartmentId: 'apt-A',
    period: '08/2026',
    dueDate: DateTime(2026, 8, 25),
    totalAmount: 1200000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 8, 1),
  );

  final invoiceB1 = InvoiceModel(
    id: 'inv-aptB-1',
    apartmentId: 'apt-B',
    period: '09/2026',
    dueDate: DateTime(2026, 9, 25),
    totalAmount: 1800000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 9, 1),
  );

  final invoiceB2 = InvoiceModel(
    id: 'inv-aptB-2',
    apartmentId: 'apt-B',
    period: '10/2026',
    dueDate: DateTime(2026, 10, 25),
    totalAmount: 2100000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 10, 1),
  );

  testWidgets('Không spam SnackBar thông báo hóa đơn mới khi người dùng chuyển căn hộ', (tester) async {
    final aptNotifier = SelectedApartmentNotifier()..selectApartment('apt-A');

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
        selectedApartmentIdProvider.overrideWith((ref) => aptNotifier),
        _testInvoiceStreamProvider.overrideWith((ref) => [invoiceA]),
        residentInvoiceProvider.overrideWith((ref) => ref.watch(_testInvoiceStreamProvider)),
        residentIssueProvider.overrideWith((ref) => <IssueModel>[]),
        announcementsStreamProvider.overrideWith((ref) => Stream.value(<AnnouncementModel>[])),
        unreadNotificationsCountProvider.overrideWith((ref) => 0),
        residentApartmentsProvider.overrideWith((ref) => [
          {'apartment_id': 'apt-A', 'apartments': {'id': 'apt-A', 'code': 'a0101'}},
          {'apartment_id': 'apt-B', 'apartments': {'id': 'apt-B', 'code': 'b0202'}},
        ]),
      ],
    );

    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ResidentHomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ban đầu nạp căn hộ A không có snackbar spam
    expect(find.byType(SnackBar), findsNothing);

    // 2. Chuyển đổi sang căn hộ B
    aptNotifier.selectApartment('apt-B');
    container.read(_testInvoiceStreamProvider.notifier).state = [invoiceB1];
    await tester.pumpAndSettle();

    // Đổi căn hộ KHÔNG được coi là có hóa đơn mới -> KHÔNG hiện SnackBar
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Hóa đơn mới kỳ 09/2026'), findsNothing);

    // 3. Trong cùng căn hộ B, phát sinh hóa đơn mới kỳ 10/2026
    container.read(_testInvoiceStreamProvider.notifier).state = [invoiceB1, invoiceB2];
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 500));

    // Lúc này hóa đơn mới kỳ 10/2026 phát sinh trong cùng căn hộ B -> PHẢI hiện thông báo toast
    expect(find.textContaining('Hóa đơn mới kỳ 10/2026'), findsOneWidget);
  });
}
