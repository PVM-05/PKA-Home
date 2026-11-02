import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/providers/resident_lifecycle_provider.dart';
import 'package:pka_home/data/repositories/resident_lifecycle_repository.dart';
import 'package:pka_home/features/resident/widgets/accept_invitation_dialog.dart';

class FakeAcceptRepo extends ResidentLifecycleRepository {
  @override
  Future<Map<String, dynamic>> acceptInvitation(String inviteCode) async {
    if (inviteCode == 'PKAA0110X') {
      return {
        'success': true,
        'message': 'Kích hoạt gia nhập căn hộ thành công!',
        'apartment_code': 'A0110',
        'role': 'member',
      };
    }
    return {
      'success': false,
      'message': 'Mã mời không tồn tại hoặc đã hết hạn.',
    };
  }
}

void main() {
  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        residentLifecycleRepositoryProvider.overrideWithValue(FakeAcceptRepo()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: AcceptInvitationDialog(),
        ),
      ),
    );
  }

  testWidgets('AcceptInvitationDialog nhap ma moi va kich hoat thanh cong', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Gia Nhập Căn Hộ Qua Mã Mời'), findsOneWidget);
    expect(find.text('Kích hoạt vào căn hộ'), findsOneWidget);

    // Nhap ma hop le
    final input = find.byType(TextField);
    await tester.enterText(input, 'PKAA0110X');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kích hoạt vào căn hộ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kích hoạt gia nhập căn hộ thành công!'), findsOneWidget);
  });
}
