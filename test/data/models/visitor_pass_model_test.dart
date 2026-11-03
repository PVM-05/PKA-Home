import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/visitor_pass_model.dart';

void main() {
  group('VisitorPassModel Tests', () {
    final now = DateTime(2026, 11, 3, 14, 0);

    final sampleJson = {
      'id': 'vp-01',
      'pass_code': 'VP-202611-00001',
      'apartment_id': 'apt-01',
      'host_user_id': 'usr-01',
      'visitor_name': 'Nguyễn Văn Nam',
      'visitor_phone': '0912345678',
      'license_plate': '30A-888.99',
      'vehicle_type': 'car',
      'visitor_count': 2,
      'expected_arrival': now.toIso8601String(),
      'expected_departure': now.add(const Duration(hours: 3)).toIso8601String(),
      'purpose': 'visit',
      'qr_payload': 'PKAPASS:VP-202611-00001:abcd1234',
      'status': 'pending',
      'note': 'Bạn học đại học đến chơi',
      'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'apartments': {
        'code': 'A0110',
        'building_code': 'A',
      },
    };

    test('fromJson parses data correctly', () {
      final model = VisitorPassModel.fromJson(sampleJson);

      expect(model.id, 'vp-01');
      expect(model.passCode, 'VP-202611-00001');
      expect(model.apartmentId, 'apt-01');
      expect(model.apartmentCode, 'A0110');
      expect(model.visitorName, 'Nguyễn Văn Nam');
      expect(model.visitorPhone, '0912345678');
      expect(model.licensePlate, '30A-888.99');
      expect(model.vehicleType, 'car');
      expect(model.vehicleDisplayName, 'Ô tô (30A-888.99)');
      expect(model.visitorCount, 2);
      expect(model.purpose, 'visit');
      expect(model.purposeDisplayName, 'Thăm hỏi bạn bè / người thân');
      expect(model.status, 'pending');
      expect(model.statusDisplayName, 'Chờ đến');
      expect(model.note, 'Bạn học đại học đến chơi');
    });

    test('toJson serializes correctly', () {
      final model = VisitorPassModel.fromJson(sampleJson);
      final json = model.toJson();

      expect(json['id'], 'vp-01');
      expect(json['pass_code'], 'VP-202611-00001');
      expect(json['visitor_name'], 'Nguyễn Văn Nam');
      expect(json['status'], 'pending');
    });

    test('copyWith updates fields correctly', () {
      final model = VisitorPassModel.fromJson(sampleJson);
      final updated = model.copyWith(
        status: 'checked_in',
        checkInAt: now,
      );

      expect(updated.status, 'checked_in');
      expect(updated.statusDisplayName, 'Đang trong tòa nhà');
      expect(updated.checkInAt, now);
      expect(updated.passCode, model.passCode);
    });
  });
}

