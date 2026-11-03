import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _val;
  FakeFilterBuilder(this._val);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_val).then(onValue, onError: onError);
  }
}

void main() {
  late MockSupabaseClient mockClient;
  late AmenityBookingRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    repository = AmenityBookingRepository(mockClient);
  });

  group('AmenityBookingRepository.cancelBooking Fail-Closed Tests (OPS-FIX)', () {
    test('Hủy thành công khi RPC trả về success = true', () async {
      when(() => mockClient.rpc('cancel_amenity_booking', params: {
        'p_booking_id': 'bk-001',
      })).thenAnswer((_) => FakeFilterBuilder({
        'success': true,
        'booking_id': 'bk-001',
        'message': 'Hủy thành công',
      }));

      final result = await repository.cancelBooking('bk-001');
      expect(result['success'], isTrue);
      expect(result['booking_id'], 'bk-001');
      verify(() => mockClient.rpc('cancel_amenity_booking', params: {'p_booking_id': 'bk-001'})).called(1);
      verifyNever(() => mockClient.from(any()));
    });

    test('Ném ngoại lệ khi RPC trả về success = false', () async {
      when(() => mockClient.rpc('cancel_amenity_booking', params: {
        'p_booking_id': 'bk-002',
      })).thenAnswer((_) => FakeFilterBuilder({
        'success': false,
        'message': 'Đã quá hạn được phép hủy đặt chỗ',
      }));

      expect(
        () => repository.cancelBooking('bk-002'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Đã quá hạn được phép hủy đặt chỗ'),
          ),
        ),
      );
      verifyNever(() => mockClient.from(any()));
    });

    test('Tuân thủ Fail-Closed: Ném ngoại lệ khi RPC bị lỗi kết nối/PostgreSQL, KHÔNG gọi fallback update', () async {
      when(() => mockClient.rpc('cancel_amenity_booking', params: {
        'p_booking_id': 'bk-003',
      })).thenThrow(
        const PostgrestException(
          message: 'permission denied for function cancel_amenity_booking',
          code: '42501',
        ),
      );

      expect(
        () => repository.cancelBooking('bk-003'),
        throwsA(isA<Exception>()),
      );

      // Bắt buộc tuân thủ Fail-Closed: Tuyệt đối không được fallback sang from('amenity_bookings').update(...)
      verifyNever(() => mockClient.from('amenity_bookings'));
    });
  });
}
