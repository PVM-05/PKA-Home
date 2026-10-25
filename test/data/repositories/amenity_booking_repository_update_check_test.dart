import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakeTransformBuilder<T> extends Fake implements PostgrestTransformBuilder<T> {
  final T _val;
  FakeTransformBuilder(this._val);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_val).then(onValue, onError: onError);
  }
}

class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _val;
  FakeFilterBuilder(this._val);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([String columns = '*']) =>
      FakeTransformBuilder<List<Map<String, dynamic>>>(_val as List<Map<String, dynamic>>);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_val).then(onValue, onError: onError);
  }
}

class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _val;
  FakeQueryBuilder(this._val);

  @override
  PostgrestFilterBuilder update(Map values, {String? defaultToNull}) => FakeFilterBuilder(_val);
}

void main() {
  late MockSupabaseClient mockClient;
  late AmenityBookingRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    repository = AmenityBookingRepository(mockClient);
  });

  group('AmenityBookingRepository - Rà soát cập nhật và thông báo lỗi (SYS-03, UI-01)', () {
    test('createBooking khi gặp mã 23503 phải ném thông báo chuẩn tiếng Việt về liên kết dữ liệu', () async {
      when(() => mockClient.rpc(any(), params: any(named: 'params'))).thenThrow(
        const PostgrestException(
          message: 'foreign key constraint violation',
          code: '23503',
        ),
      );

      expect(
        () => repository.createBooking(
          amenityId: 'amenity-001',
          apartmentId: 'apt-001',
          userId: 'user-001',
          date: DateTime(2026, 11, 20),
          timeSlot: '08:00 - 10:00',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Thông tin tiện ích hoặc căn hộ liên kết không tồn tại hoặc không hợp lệ.'),
          ),
        ),
      );
    });

    test('cancelBooking phải ném Exception khi không có bản ghi nào được cập nhật (0 rows affected)', () async {
      when(() => mockClient.from('amenity_bookings')).thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      expect(
        () => repository.cancelBooking('non-existent-id'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền hủy.'),
          ),
        ),
      );
    });

    test('updateDepositStatus phải ném Exception khi không có bản ghi nào được cập nhật', () async {
      when(() => mockClient.from('amenity_bookings')).thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      expect(
        () => repository.updateDepositStatus('non-existent-id', 'received'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền cập nhật tiền cọc.'),
          ),
        ),
      );
    });

    test('markBookingAttendance phải ném Exception khi không có bản ghi nào được cập nhật', () async {
      when(() => mockClient.from('amenity_bookings')).thenAnswer((_) => FakeQueryBuilder(<Map<String, dynamic>>[]));

      expect(
        () => repository.markBookingAttendance('non-existent-id', 'completed'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền cập nhật điểm danh.'),
          ),
        ),
      );
    });
  });
}
