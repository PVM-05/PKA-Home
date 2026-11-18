import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/providers/resident_activation_provider.dart';
import 'package:vivona/data/repositories/resident_activation_repository.dart';

class FakeResidentActivationRepository extends ResidentActivationRepository {
  @override
  Future<Map<String, dynamic>> verifyActivationCode({
    required String phone,
    required String activationCode,
  }) async {
    final cleanCode = activationCode.trim().toUpperCase();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (cleanCode.startsWith('ACT') || cleanCode.length >= 6) {
      return {
        'success': true,
        'message': 'Mã kích hoạt hợp lệ.',
        'full_name': 'Nguyễn Văn An',
        'apartment_code': 'A0110',
        'phone': cleanPhone,
        'activation_code': cleanCode,
        'otp_hint': '123456',
      };
    }
    return {
      'success': false,
      'message': 'Số điện thoại hoặc mã kích hoạt không chính xác.',
    };
  }

  @override
  Future<Map<String, dynamic>> verifyActivationOtp({
    required String phone,
    required String activationCode,
    required String otpCode,
  }) async {
    final cleanOtp = otpCode.trim();
    if (cleanOtp == '123456') {
      return {
        'success': true,
        'message': 'Xác thực OTP thành công.',
      };
    }
    return {
      'success': false,
      'message': 'Mã xác thực OTP không chính xác hoặc đã hết hạn.',
    };
  }

  @override
  Future<Map<String, dynamic>> completeActivation({
    required String phone,
    required String activationCode,
    required String otpCode,
    required String authUserId,
    String? email,
  }) async {
    return {
      'success': true,
      'message': 'Kích hoạt tài khoản thành công!',
      'apartment_code': 'A0110',
      'user_id': authUserId,
    };
  }
}

void main() {
  group('ResidentActivationNotifier State Machine Tests', () {
    late ResidentActivationRepository repository;
    late ResidentActivationNotifier notifier;

    setUp(() {
      repository = FakeResidentActivationRepository();
      notifier = ResidentActivationNotifier(repository);
    });

    test('initial state is enterCode and empty', () {
      expect(notifier.state.currentStep, ActivationStep.enterCode);
      expect(notifier.state.phone, isEmpty);
      expect(notifier.state.activationCode, isEmpty);
      expect(notifier.state.isLoading, isFalse);
    });

    test('submitActivationCode advances step to enterOtp on success', () async {
      final success = await notifier.submitActivationCode(
        phone: '0901234567',
        activationCode: 'ACT-123456',
      );

      expect(success, isTrue);
      expect(notifier.state.currentStep, ActivationStep.enterOtp);
      expect(notifier.state.phone, '0901234567');
      expect(notifier.state.activationCode, 'ACT-123456');
      expect(notifier.state.fullName, 'Nguyễn Văn An');
      expect(notifier.state.apartmentCode, 'A0110');
      expect(notifier.state.otpHint, '123456');
    });

    test('submitActivationCode rejects empty inputs', () async {
      final success = await notifier.submitActivationCode(
        phone: '',
        activationCode: '',
      );

      expect(success, isFalse);
      expect(notifier.state.currentStep, ActivationStep.enterCode);
      expect(notifier.state.errorMessage, contains('đầy đủ'));
    });

    test('submitOtp advances step to setPassword on correct code', () async {
      await notifier.submitActivationCode(
        phone: '0901234567',
        activationCode: 'ACT-123456',
      );

      final otpSuccess = await notifier.submitOtp('123456');
      expect(otpSuccess, isTrue);
      expect(notifier.state.currentStep, ActivationStep.setPassword);
      expect(notifier.state.otpCode, '123456');
    });

    test('submitOtp rejects short or wrong code', () async {
      await notifier.submitActivationCode(
        phone: '0901234567',
        activationCode: 'ACT-123456',
      );

      final shortOtp = await notifier.submitOtp('123');
      expect(shortOtp, isFalse);
      expect(notifier.state.errorMessage, contains('6 chữ số'));

      final wrongOtp = await notifier.submitOtp('999999');
      expect(wrongOtp, isFalse);
      expect(notifier.state.errorMessage, contains('không chính xác'));
    });

    test('completeActivation requires matching passwords and terms acceptance', () async {
      await notifier.submitActivationCode(
        phone: '0901234567',
        activationCode: 'ACT-123456',
      );
      await notifier.submitOtp('123456');

      // 1. Password quá ngắn
      var success = await notifier.completeActivation(
        password: '123',
        confirmPassword: '123',
      );
      expect(success, isFalse);
      expect(notifier.state.errorMessage, contains('tối thiểu từ 6 ký tự'));

      // 2. Mật khẩu không trùng
      success = await notifier.completeActivation(
        password: 'password123',
        confirmPassword: 'password999',
      );
      expect(success, isFalse);
      expect(notifier.state.errorMessage, contains('không trùng khớp'));

      // 3. Chưa đồng ý điều khoản
      notifier.setAgreedToTerms(false);
      success = await notifier.completeActivation(
        password: 'password123',
        confirmPassword: 'password123',
      );
      expect(success, isFalse);
      expect(notifier.state.errorMessage, contains('Quy chế chung cư'));

      // 4. Hợp lệ
      notifier.setAgreedToTerms(true);
      success = await notifier.completeActivation(
        password: 'password123',
        confirmPassword: 'password123',
      );
      expect(success, isTrue);
      expect(notifier.state.currentStep, ActivationStep.completed);
    });
  });
}

