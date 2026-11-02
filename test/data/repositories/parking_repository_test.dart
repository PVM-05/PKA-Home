import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/visitor_parking_ticket_model.dart';
import 'package:pka_home/data/repositories/parking_repository.dart';

void main() {
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

    test('assignSlot and releaseSlot toggle slot availability', () async {
      final slots = await repo.fetchSlots();
      final availableSlot = slots.firstWhere((s) => s.isAvailable);

      // Gán ô đỗ
      final assignRes = await repo.assignSlot(
        slotId: availableSlot.id,
        vehicleId: 'veh-99',
        apartmentId: 'apt-99',
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
