import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/link_request_provider.dart';
import 'package:pka_home/features/resident/screens/link_request_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResidentLinkNotifier extends StateNotifier<ResidentLinkStatus>
    implements ResidentLinkNotifier {
  bool cancelCalled = false;
  String? cancelledReqId;

  FakeResidentLinkNotifier(super.initialStatus);

  @override
  Future<void> cancelPendingRequest([String? reqId]) async {
    cancelCalled = true;
    cancelledReqId = reqId;
    state = ResidentLinkStatus(status: LinkStatus.none);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('LinkRequestScreen hien thi nut Huy yeu cau nay khi o trang thai pending va hoan tat huy', (tester) async {
    final residentUser = UserModel(
      id: 'res-user-1',
      fullName: 'Cư dân Test',
      phone: '0909999999',
      role: 'resident',
    );

    final fakeNotifier = FakeResidentLinkNotifier(
      ResidentLinkStatus(
        status: LinkStatus.pending,
        requestId: 'req-link-1',
        apartmentCode: 'A0110',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(residentUser)),
          residentLinkProvider.overrideWith((ref) => fakeNotifier),
          availableApartmentsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: LinkRequestScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Xác nhận đang ở màn hình pending
    expect(find.text('Đang chờ phê duyệt'), findsOneWidget);

    // Nút Hủy yêu cầu này phải xuất hiện
    expect(find.text('Hủy yêu cầu này'), findsOneWidget);

    // Tap vào nút Hủy yêu cầu này
    await tester.tap(find.text('Hủy yêu cầu này'));
    await tester.pumpAndSettle();

    // Dialog xác nhận xuất hiện
    expect(find.text('Hủy Yêu Cầu Liên Kết'), findsOneWidget);
    expect(find.text('Xác nhận hủy'), findsOneWidget);

    // Tap vào nút Xác nhận hủy
    await tester.tap(find.text('Xác nhận hủy'));
    await tester.pumpAndSettle();

    // Xác nhận đã gọi cancelPendingRequest với đúng requestId
    expect(fakeNotifier.cancelCalled, isTrue);
    expect(fakeNotifier.cancelledReqId, equals('req-link-1'));

    // Giao diện đã quay về trạng thái form liên kết
    expect(find.text('Liên kết căn hộ'), findsWidgets);
  });
}
