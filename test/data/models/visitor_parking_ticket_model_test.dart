import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/visitor_parking_ticket_model.dart';

void main() {
  group('VisitorParkingTicketModel Tests', () {
    test('fromJson and toJson should work correctly', () {
      final now = DateTime(2026, 11, 2, 8, 30);
      final json = {
        'id': 'tkt-01',
        'building_id': 'b-01',
        'ticket_code': 'TKT-202611-0001',
        'license_plate': '30E-123.45',
        'vehicle_type': 'car',
        'check_in_at': now.toIso8601String(),
        'check_out_at': now.add(const Duration(hours: 3)).toIso8601String(),
        'status': 'in_parking',
        'hourly_rate': 25000,
        'total_hours': 3,
        'fee_amount': 40000,
        'payment_status': 'unpaid',
        'payment_method': 'vietqr',
        'qr_payload': 'PKAPARKING:TKT-202611-0001',
        'note': 'Khách căn hộ A0101',
        'created_at': now.toIso8601String(),
      };

      final ticket = VisitorParkingTicketModel.fromJson(json);

      expect(ticket.id, 'tkt-01');
      expect(ticket.ticketCode, 'TKT-202611-0001');
      expect(ticket.licensePlate, '30E-123.45');
      expect(ticket.isCar, isTrue);
      expect(ticket.isInParking, isTrue);
      expect(ticket.isPaid, isFalse);
      expect(ticket.feeFormatted, '40.000 đ');
      expect(ticket.displayStatus, 'Đang gửi');
      expect(ticket.displayVehicleType, 'Ô tô');

      final output = ticket.toJson();
      expect(output['ticket_code'], 'TKT-202611-0001');
      expect(output['fee_amount'], 40000.0);
    });

    test('copyWith updates ticket status upon payment', () {
      final ticket = VisitorParkingTicketModel(
        id: 'tkt-02',
        ticketCode: 'TKT-202611-0002',
        licensePlate: '29V1-999.99',
        vehicleType: 'motorcycle',
        checkInAt: DateTime.now(),
        qrPayload: 'PKAPARKING:TKT-202611-0002',
        createdAt: DateTime.now(),
      );

      final paidTicket = ticket.copyWith(
        status: 'completed',
        paymentStatus: 'paid',
        feeAmount: 8000,
      );

      expect(paidTicket.isPaid, isTrue);
      expect(paidTicket.isInParking, isFalse);
      expect(paidTicket.feeAmount, 8000);
      expect(paidTicket.feeFormatted, '8.000 đ');
    });
  });
}

