import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/auth_repository.dart';
import 'package:pka_home/features/auth/screens/forgot_password_screen.dart';
import 'package:pka_home/features/auth/screens/verify_otp_screen.dart';
import 'package:pka_home/features/auth/screens/reset_password_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockUser extends Mock implements User {}
class MockAuthResponse extends Mock implements AuthResponse {}

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  Widget buildTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('ForgotPasswordScreen Tests', () {
    testWidgets('renders all essential elements', (tester) async {
      await tester.pumpWidget(buildTestWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Khôi phục mật khẩu'), findsOneWidget);
      expect(find.text('Thư điện tử'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Gửi mã xác thực'), findsOneWidget);
      expect(find.text('Quay lại đăng nhập'), findsOneWidget);
    });

    testWidgets('shows validation error when email is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác thực'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập địa chỉ thư điện tử'), findsOneWidget);
      verifyNever(() => mockAuthRepository.sendPasswordResetOtp(any()));
    });

    testWidgets('shows validation error when email format is invalid', (tester) async {
      await tester.pumpWidget(buildTestWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'invalid-email');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác thực'));
      await tester.pumpAndSettle();

      expect(find.text('Định dạng thư điện tử không hợp lệ'), findsOneWidget);
      verifyNever(() => mockAuthRepository.sendPasswordResetOtp(any()));
    });

    testWidgets('calls sendPasswordResetOtp and shows neutral message on valid email', (tester) async {
      when(() => mockAuthRepository.sendPasswordResetOtp('resident@pka.vn'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'resident@pka.vn');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác thực'));
      await tester.pump(); // Start async call
      await tester.pump(const Duration(milliseconds: 100)); // Finish async call

      verify(() => mockAuthRepository.sendPasswordResetOtp('resident@pka.vn')).called(1);
      expect(find.textContaining('Nếu địa chỉ thư điện tử này tồn tại'), findsOneWidget);
    });

    testWidgets('shows error banner when rate limit 429 occurs', (tester) async {
      when(() => mockAuthRepository.sendPasswordResetOtp('rate@pka.vn'))
          .thenThrow(Exception('Bạn đã gửi yêu cầu quá nhiều lần. Vui lòng chờ ít phút.'));

      await tester.pumpWidget(buildTestWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'rate@pka.vn');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác thực'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('quá nhiều lần'), findsOneWidget);
    });
  });

  group('VerifyOtpScreen Tests', () {
    testWidgets('renders email target and countdown elements', (tester) async {
      await tester.pumpWidget(buildTestWidget(const VerifyOtpScreen(email: 'resident@pka.vn')));
      await tester.pump();

      expect(find.text('Xác nhận mã OTP'), findsOneWidget);
      expect(find.text('resident@pka.vn'), findsOneWidget);
      expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('resend button becomes active after 60s and can be pressed', (tester) async {
      when(() => mockAuthRepository.sendPasswordResetOtp('resident@pka.vn'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(const VerifyOtpScreen(email: 'resident@pka.vn')));
      await tester.pump();

      // Fast forward timer 61 seconds
      await tester.pump(const Duration(seconds: 61));

      expect(find.text('Gửi lại mã'), findsOneWidget);
      await tester.tap(find.text('Gửi lại mã'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => mockAuthRepository.sendPasswordResetOtp('resident@pka.vn')).called(1);
    });

    testWidgets('calls verifyPasswordResetOtp when 6 digits are typed', (tester) async {
      when(() => mockAuthRepository.verifyPasswordResetOtp(
            email: 'resident@pka.vn',
            token: '123456',
          )).thenAnswer((_) async => MockAuthResponse());

      await tester.pumpWidget(buildTestWidget(const VerifyOtpScreen(email: 'resident@pka.vn')));
      await tester.pump();

      // Enter digits across the 6 boxes
      final textFields = find.byType(TextField);
      for (var i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '${i + 1}');
        await tester.pump();
      }

      verify(() => mockAuthRepository.verifyPasswordResetOtp(
            email: 'resident@pka.vn',
            token: '123456',
          )).called(1);
    });
  });

  group('ResetPasswordScreen Tests', () {
    testWidgets('renders expired session warning when currentUser is null', (tester) async {
      when(() => mockAuthRepository.currentUser).thenReturn(null);

      await tester.pumpWidget(buildTestWidget(const ResetPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Phiên xác thực đã hết hạn'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Gửi lại yêu cầu khôi phục'), findsOneWidget);
    });

    testWidgets('renders new password inputs when currentUser is present', (tester) async {
      when(() => mockAuthRepository.currentUser).thenReturn(MockUser());

      await tester.pumpWidget(buildTestWidget(const ResetPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Tạo mật khẩu mới'), findsOneWidget);
      expect(find.text('Mật khẩu mới'), findsOneWidget);
      expect(find.text('Xác nhận mật khẩu mới'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Lưu mật khẩu mới'), findsOneWidget);
    });

    testWidgets('shows validation errors for short password or mismatched confirmation', (tester) async {
      when(() => mockAuthRepository.currentUser).thenReturn(MockUser());

      await tester.pumpWidget(buildTestWidget(const ResetPasswordScreen()));
      await tester.pumpAndSettle();

      // Case 1: Empty
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập mật khẩu mới'), findsOneWidget);

      // Case 2: Short (<6 chars)
      final inputs = find.byType(TextField);
      await tester.enterText(inputs.at(0), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);

      // Case 3: Letters only (no numbers)
      await tester.enterText(inputs.at(0), 'abcdef');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu phải bao gồm cả chữ cái và chữ số'), findsOneWidget);

      // Case 4: Mismatched confirmation
      await tester.enterText(inputs.at(0), 'Pass1234');
      await tester.enterText(inputs.at(1), 'Diff1234');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận mật khẩu không khớp'), findsOneWidget);
    });

    testWidgets('calls updatePassword and logout when submission is valid', (tester) async {
      when(() => mockAuthRepository.currentUser).thenReturn(MockUser());
      when(() => mockAuthRepository.updatePassword('Password123'))
          .thenAnswer((_) async {});
      when(() => mockAuthRepository.logout()).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(const ResetPasswordScreen()));
      await tester.pumpAndSettle();

      final inputs = find.byType(TextField);
      await tester.enterText(inputs.at(0), 'Password123');
      await tester.enterText(inputs.at(1), 'Password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu mật khẩu mới'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => mockAuthRepository.updatePassword('Password123')).called(1);
      verify(() => mockAuthRepository.logout()).called(1);
    });
  });
}
