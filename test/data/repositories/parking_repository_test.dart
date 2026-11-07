import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/models/visitor_parking_ticket_model.dart';
import 'package:pka_home/data/repositories/parking_repository.dart';

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

  group('ParkingRepository Offline Fallback Engine Tests', () {
    late ParkingRepository repo;

    setUp(() {
      repo = ParkingRepository();
    });

    test('fetchSlots returns non-empty mock parking slots when offline or unconfigured', () async {
      final slots = await repo.fetchSlots();
      expect(slots.isNotEmpty, isTrue);
      expect(slots.any((s) => s.isCar), isTrue);
      expect(slots.any((s) => s.isMotorcycle), isTrue);
      expect(slots.any((s) => s.isAvailable), isTrue);
    });

    test('fetchCapacityStats returns accurate capacity data', () async {
      final stats = await repo.fetchCapacityStats();
      expect(stats.carTotal, greaterThan(0));
      expect(stats.motoTotal, greaterThan(0));
      expect(stats.carOccupancyRate, inInclusiveRange(0.0, 100.0));
    });

    test('createVisitorTicket successfully generates a ticket with valid code and QR payload', () async {
      final res = await repo.createVisitorTicket(
        licensePlate: '30H-888.88',
        vehicleType: 'car',
        note: 'Khách lên thăm phòng A0205',
      );

      expect(res['success'], isTrue);
      expect(res['ticket'], isNotNull);
      final ticket = res['ticket'] as VisitorParkingTicketModel;
      expect(ticket.licensePlate, '30H-888.88');
      expect(ticket.isCar, isTrue);
      expect(ticket.ticketCode.startsWith('TKT-'), isTrue);
      expect(ticket.qrPayload.contains('30H-888.88'), isTrue);
    });

    test('calculateVisitorFee and checkoutVisitorTicket compute fee and complete ticket', () async {
      // 1. Tạo vé xe
      final createRes = await repo.createVisitorTicket(
        licensePlate: '29K1-777.77',
        vehicleType: 'motorcycle',
      );
      final ticket = createRes['ticket'] as VisitorParkingTicketModel;

      // 2. Tính phí
      final feeRes = await repo.calculateVisitorFee(ticket.id);
      expect(feeRes['success'], isTrue);
      expect(feeRes['fee_amount'], greaterThanOrEqualTo(5000));

      // 3. Checkout
      final checkoutRes = await repo.checkoutVisitorTicket(
        ticketId: ticket.id,
        paymentMethod: 'vietqr',
      );
      expect(checkoutRes['success'], isTrue);
      expect(checkoutRes['payment_method'], 'vietqr');
    });

    test('fetchAvailableCarSlots chỉ trả về các ô đỗ ô tô còn trống', () async {
      final carSlots = await repo.fetchAvailableCarSlots();
      expect(carSlots.isNotEmpty, isTrue);
      expect(carSlots.every((s) => s.isCar && s.isAvailable), isTrue);
    });

    test('assignSlot and releaseSlot toggle slot availability', () async {
      final slots = await repo.fetchSlots();
      final availableSlot = slots.firstWhere((s) => s.isAvailable && s.isCar);

      // Gán ô đỗ
      final assignRes = await repo.assignSlot(
        slotId: availableSlot.id,
        vehicleId: 'veh-99',
        apartmentId: 'apt-99',
        slotNumber: availableSlot.slotNumber,
        licensePlate: '30A-111.22',
        apartmentCode: 'A0303',
      );
      expect(assignRes['success'], isTrue);

      // Giải phóng ô đỗ
      final releaseRes = await repo.releaseSlot(availableSlot.id);
      expect(releaseRes['success'], isTrue);
    });
  });
}
