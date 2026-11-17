import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vivona/core/utils/guard_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivona/data/repositories/parking_repository.dart';

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
  PostgrestTransformBuilder<T> order(String column, {bool ascending = true, bool nullsFirst = false, String? referencedTable}) =>
      FakeTransformBuilder<T>(_val);

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

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) =>
      FakeFilterBuilder<List<Map<String, dynamic>>>(_val is List<Map<String, dynamic>> ? _val : [_val as Map<String, dynamic>]);
}

void main() {
  group('ParkingRepository Mocked Supabase Client Tests', () {
    late MockSupabaseClient mockClient;
    late ParkingRepository repo;

    setUp(() {
      mockClient = MockSupabaseClient();
      repo = ParkingRepository(mockClient);
    });

    test('fetchAvailableCarSlots trả về đúng danh sách ô đỗ ô tô còn trống từ máy chủ', () async {
      when(() => mockClient.from('parking_slots')).thenAnswer((_) => FakeQueryBuilder([
        {
          'id': 'slot-b1-05',
          'zone': 'B1',
          'slot_number': 'P-B1-05',
          'slot_type': 'car',
          'status': 'available',
          'created_at': '2026-11-07T12:00:00Z',
        }
      ]));

      final slots = await repo.fetchAvailableCarSlots();
      expect(slots.length, 1);
      expect(slots.first.slotNumber, 'P-B1-05');
      expect(slots.first.isCar, isTrue);
      expect(slots.first.isAvailable, isTrue);
    });
  });

  group('ParkingRepository Fail-Closed Tests', () {
    late ParkingRepository repo;

    setUp(() {
      repo = ParkingRepository(null);
    });

    test('fetchSlots ném AppException khi không có kết nối Supabase', () async {
      expect(() => repo.fetchSlots(), throwsA(isA<AppException>()));
    });

    test('fetchCapacityStats ném AppException khi không có kết nối Supabase', () async {
      expect(() => repo.fetchCapacityStats(), throwsA(isA<AppException>()));
    });

    test('createVisitorTicket ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repo.createVisitorTicket(licensePlate: '30H-888.88', vehicleType: 'car'),
        throwsA(isA<AppException>()),
      );
    });

    test('fetchActiveVisitorTickets ném AppException khi không có kết nối Supabase', () async {
      expect(() => repo.fetchActiveVisitorTickets(), throwsA(isA<AppException>()));
    });
  });
}
