import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/pdpl_consent_dialog.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/resident_apartment_provider.dart';
import 'package:vivona/data/services/data_privacy_service.dart';
import 'package:vivona/features/resident/screens/resident_profile_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDataPrivacyService extends Mock implements DataPrivacyService {}

void main() {
  final testUser = UserModel(
    id: 'user-pdpl-test-1',
    fullName: 'Lê Văn Cư Dân',
    phone: '0912345678',
    role: 'resident',
  );

  Widget createWidget({required MockDataPrivacyService privacyService}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        residentApartmentsProvider.overrideWith((ref) => Future.value([])),
        dataPrivacyServiceProvider.overrideWithValue(privacyService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ResidentProfileScreen(),
      ),
    );
  }

  group('ResidentProfileScreen PDPL Features Tests', () {
    late MockDataPrivacyService mockPrivacyService;

    setUp(() {
      mockPrivacyService = MockDataPrivacyService();
    });

    testWidgets('Hiển thị mục Quyền riêng tư & Dữ liệu và mở chính sách bảo mật', (tester) async {
      await tester.pumpWidget(createWidget(privacyService: mockPrivacyService));
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề mục PDPL
      expect(find.text('Quyền riêng tư & Dữ liệu cá nhân'), findsOneWidget);
      expect(find.text('Chính sách quyền riêng tư'), findsOneWidget);
      expect(find.text('Thỏa thuận xử lý dữ liệu'), findsOneWidget);
      expect(find.text('Xuất sao kê dữ liệu cá nhân'), findsOneWidget);
      expect(find.text('Yêu cầu xóa / đóng băng dữ liệu'), findsOneWidget);

      // Cuộn tới và bấm vào Chính sách quyền riêng tư
      await tester.ensureVisible(find.text('Chính sách quyền riêng tư'));
      await tester.tap(find.text('Chính sách quyền riêng tư'));
      await tester.pumpAndSettle();

      // Kiểm tra sheet mở ra
      expect(find.text('Chính Sách Bảo Mật Dữ Liệu'), findsOneWidget);
      expect(find.text('Tôn Chỉ & Phạm Vi Áp Dụng'), findsOneWidget);
    });

    testWidgets('Mở hộp thoại Thỏa thuận xử lý dữ liệu ở chế độ xem lại', (tester) async {
      await tester.pumpWidget(createWidget(privacyService: mockPrivacyService));
      await tester.pumpAndSettle();

      // Cuộn tới và bấm vào Thỏa thuận xử lý dữ liệu
      await tester.ensureVisible(find.text('Thỏa thuận xử lý dữ liệu'));
      await tester.tap(find.text('Thỏa thuận xử lý dữ liệu'));
      await tester.pumpAndSettle();

      // Kiểm tra dialog mở ra với tiêu đề và nút Đóng (Review mode)
      expect(find.byType(PdplConsentDialog), findsOneWidget);
      expect(find.text('Bảo Vệ Dữ Liệu Cá Nhân'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);

      // Bấm đóng dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Bảo Vệ Dữ Liệu Cá Nhân'), findsNothing);
    });

    testWidgets('Mở hộp thoại Yêu cầu xóa/đóng băng dữ liệu', (tester) async {
      await tester.pumpWidget(createWidget(privacyService: mockPrivacyService));
      await tester.pumpAndSettle();

      // Cuộn tới mục Yêu cầu xóa / đóng băng dữ liệu
      await tester.ensureVisible(find.text('Yêu cầu xóa / đóng băng dữ liệu'));
      await tester.tap(find.text('Yêu cầu xóa / đóng băng dữ liệu'));
      await tester.pumpAndSettle();

      expect(find.text('Yêu Cầu Đóng Băng Dữ Liệu'), findsOneWidget);
      expect(find.textContaining('Điều 16 & 17 Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Gửi yêu cầu'), findsOneWidget);
    });
  });
}
