import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/validators.dart';

void main() {
  group('validators Unit Tests', () {
    group('validateApartmentCode', () {
      test('trả về null với mã căn hộ hợp lệ chuẩn A0110', () {
        expect(validateApartmentCode('A0110'), isNull);
        expect(validateApartmentCode('b0512'), isNull);
      });

      test('báo lỗi khi mã căn hộ rỗng', () {
        expect(validateApartmentCode(''), isNotNull);
        expect(validateApartmentCode(null), isNotNull);
        expect(validateApartmentCode('   '), isNotNull);
      });

      test('báo lỗi khi sai định dạng hoặc thiếu số tầng/phòng', () {
        expect(validateApartmentCode('A101'), isNotNull);
        expect(validateApartmentCode('101A'), isNotNull);
        expect(validateApartmentCode('A0001'), contains('Số tầng'));
        expect(validateApartmentCode('A0100'), contains('Số phòng'));
      });
    });

    group('validateArea', () {
      test('hợp lệ với diện tích dương', () {
        expect(validateArea('55.5'), isNull);
        expect(validateArea('120'), isNull);
      });

      test('báo lỗi với số âm hoặc bằng 0', () {
        expect(validateArea('0'), isNotNull);
        expect(validateArea('-10'), isNotNull);
      });

      test('báo lỗi khi vượt quá 500 m2', () {
        expect(validateArea('501'), isNotNull);
      });
    });

    group('validatePhoneOptional', () {
      test('cho phép để trống', () {
        expect(validatePhoneOptional(null), isNull);
        expect(validatePhoneOptional(''), isNull);
        expect(validatePhoneOptional('   '), isNull);
      });

      test('hợp lệ với số điện thoại 10 số bắt đầu bằng 0', () {
        expect(validatePhoneOptional('0987654321'), isNull);
        expect(validatePhoneOptional('0123456789'), isNull);
      });

      test('báo lỗi với số không đủ 10 số hoặc không bắt đầu bằng 0', () {
        expect(validatePhoneOptional('1234567890'), isNotNull);
        expect(validatePhoneOptional('098765432'), isNotNull);
        expect(validatePhoneOptional('09876543210'), isNotNull);
        expect(validatePhoneOptional('09876abcde'), isNotNull);
      });
    });

    group('validateNonNegativeNumber', () {
      test('cho phép 0 và số dương', () {
        expect(validateNonNegativeNumber('0'), isNull);
        expect(validateNonNegativeNumber('0.0'), isNull);
        expect(validateNonNegativeNumber('150.5'), isNull);
      });

      test('chặn số âm', () {
        expect(validateNonNegativeNumber('-1'), contains('không được là số âm'));
        expect(validateNonNegativeNumber('-0.1'), contains('không được là số âm'));
      });

      test('xử lý chuỗi rỗng theo isRequired', () {
        expect(validateNonNegativeNumber('', 'Điện', false), isNull);
        expect(validateNonNegativeNumber('', 'Điện', true), contains('không được để trống'));
      });

      test('báo lỗi khi không phải định dạng số', () {
        expect(validateNonNegativeNumber('abc', 'Điện'), contains('phải là số hợp lệ'));
      });
    });

    group('validatePositiveNumber', () {
      test('cho phép số dương', () {
        expect(validatePositiveNumber('3500'), isNull);
        expect(validatePositiveNumber('0.5'), isNull);
      });

      test('chặn 0 và số âm', () {
        expect(validatePositiveNumber('0'), contains('phải lớn hơn 0'));
        expect(validatePositiveNumber('-500'), contains('phải lớn hơn 0'));
      });
    });

    group('validateNonNegativeInt', () {
      test('cho phép 0 và số nguyên dương', () {
        expect(validateNonNegativeInt('0'), isNull);
        expect(validateNonNegativeInt('2'), isNull);
      });

      test('chặn số âm hoặc số thực', () {
        expect(validateNonNegativeInt('-1'), contains('không được là số âm'));
        expect(validateNonNegativeInt('1.5'), contains('phải là số nguyên hợp lệ'));
      });
    });

    group('validateInvoicePeriod', () {
      test('hợp lệ với định dạng MM/yyyy chuẩn', () {
        expect(validateInvoicePeriod('01/2026'), isNull);
        expect(validateInvoicePeriod('09/2026'), isNull);
        expect(validateInvoicePeriod('12/2025'), isNull);
      });

      test('báo lỗi khi để trống hoặc null', () {
        expect(validateInvoicePeriod(null), 'Vui lòng nhập kỳ hóa đơn');
        expect(validateInvoicePeriod(''), 'Vui lòng nhập kỳ hóa đơn');
        expect(validateInvoicePeriod('   '), 'Vui lòng nhập kỳ hóa đơn');
      });

      test('báo lỗi khi sai định dạng tháng (1 chữ số, > 12, = 00)', () {
        expect(validateInvoicePeriod('9/2026'), 'Định dạng kỳ phải là MM/yyyy (VD: 09/2026)');
        expect(validateInvoicePeriod('00/2026'), 'Định dạng kỳ phải là MM/yyyy (VD: 09/2026)');
        expect(validateInvoicePeriod('13/2026'), 'Định dạng kỳ phải là MM/yyyy (VD: 09/2026)');
      });

      test('báo lỗi khi sai định dạng năm hoặc có ký tự lạ', () {
        expect(validateInvoicePeriod('09/26'), 'Định dạng kỳ phải là MM/yyyy (VD: 09/2026)');
        expect(validateInvoicePeriod('09-2026'), 'Định dạng kỳ phải là MM/yyyy (VD: 09/2026)');
        expect(validateInvoicePeriod('09/2026a'), 'Định dạng kỳ phải là MM/yyyy (VD: 09/2026)');
        expect(validateInvoicePeriod('abc/2026'), 'Định dạng kỳ phải là MM/yyyy (VD: 09/2026)');
      });
    });
  });
}
