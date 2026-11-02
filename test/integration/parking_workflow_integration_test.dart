import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/visitor_parking_ticket_model.dart';
import 'package:pka_home/data/repositories/parking_repository.dart';

void main() {
  group('Parking Workflow Integration Test D2', () {
    late ParkingRepository repository;

    setUp(() {
      repository = ParkingRepository();
    });

    test('1. Luong check-in xe vang lai, tinh phi theo gio va check-out thanh toan', () async {
      // 1.1 Check-in xe máy vãng lai vào cổng
      final checkInResult = await repository.createVisitorTicket(
        licensePlate: '29V1-987.65',
        vehicleType: 'motorcycle',
        note: 'Khách lên căn A0205',
      );

      expect(checkInResult['success'], isTrue);
      final ticket = checkInResult['ticket'] as VisitorParkingTicketModel;
      expect(ticket.id, isNotEmpty);
      expect(ticket.ticketCode, startsWith('TKT-'));
      expect(ticket.licensePlate, equals('29V1-987.65'));
      expect(ticket.vehicleType, equals('motorcycle'));
      expect(ticket.isMotorcycle, isTrue);
      expect(ticket.status, equals('in_parking'));
      expect(ticket.qrPayload, contains('PKAPARKING:'));
      expect(ticket.qrPayload, contains('29V1-987.65'));

      // 1.2 Kiểm tra danh sách xe đang gửi
      final activeTickets = await repository.fetchActiveVisitorTickets();
      expect(activeTickets.any((t) => t.ticketCode == ticket.ticketCode), isTrue);

      // 1.3 Tính phí gửi xe thời gian thực
      final feeCalc = await repository.calculateVisitorFee(ticket.id);
      expect(feeCalc['success'], isTrue);
      expect(feeCalc['fee_amount'], greaterThan(0));

      // 1.4 Check-out và thanh toán qua VietQR
      final checkoutResult = await repository.checkoutVisitorTicket(
        ticketId: ticket.id,
        paymentMethod: 'vietqr',
      );

      expect(checkoutResult['success'], isTrue);
      expect(checkoutResult['payment_method'], equals('vietqr'));

      // Kiểm tra xe không còn nằm trong danh sách active
      final activeAfter = await repository.fetchActiveVisitorTickets();
      expect(activeAfter.any((t) => t.ticketCode == ticket.ticketCode), isFalse);
    });

    test('2. Luong gan o do cho can ho cu dan, cap nhat suc chua va giai phong o do', () async {
      // 2.1 Lấy danh sách ô đỗ ban đầu
      final initialSlots = await repository.fetchSlots();
      expect(initialSlots, isNotEmpty);

      final availableSlot = initialSlots.firstWhere((s) => s.isAvailable);
      expect(availableSlot.isAvailable, isTrue);

      // 2.2 Ban Quản Lý gán ô đỗ cố định cho căn hộ A0110 và biển số 30A-888.99
      final assignResult = await repository.assignSlot(
        slotId: availableSlot.id,
        vehicleId: 'veh-01',
        apartmentId: 'apt-01',
        apartmentCode: 'A0110',
        licensePlate: '30A-888.99',
      );
      expect(assignResult['success'], isTrue);

      // Lấy lại danh sách để kiểm tra ô đỗ đã được cập nhật
      final updatedSlots = await repository.fetchSlots();
      final assignedSlot = updatedSlots.firstWhere((s) => s.id == availableSlot.id);
      expect(assignedSlot.isOccupied, isTrue);
      expect(assignedSlot.apartmentCode, equals('A0110'));
      expect(assignedSlot.licensePlate, equals('30A-888.99'));

      // 2.3 Thống kê sức chứa tầng hầm thời gian thực
      final stats = await repository.fetchCapacityStats();
      expect(stats.carTotal + stats.motoTotal, greaterThan(0));
      expect(stats.carOccupied + stats.motoOccupied, greaterThan(0));

      // 2.4 Ban Quản Lý giải phóng ô đỗ khi cư dân trả phòng / chuyển xe
      final releaseResult = await repository.releaseSlot(availableSlot.id);
      expect(releaseResult['success'], isTrue);

      final finalSlots = await repository.fetchSlots();
      final releasedSlot = finalSlots.firstWhere((s) => s.id == availableSlot.id);
      expect(releasedSlot.isAvailable, isTrue);
      expect(releasedSlot.licensePlate, isNull);
      expect(releasedSlot.apartmentCode, isNull);
    });
  });
}
