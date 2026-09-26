import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/issue_model.dart';

void main() {
  group('VehicleModel Tests', () {
    test('Khởi tạo và parse JSON xe máy chính xác', () {
      final json = {
        'id': 'v-1',
        'apartment_id': 'apt-101',
        'plate_number': '29A-123.45',
        'vehicle_type': 'motorbike',
        'registered_by': 'user-1',
        'created_at': '2026-09-20T10:00:00Z',
      };

      final vehicle = VehicleModel.fromJson(json);

      expect(vehicle.id, 'v-1');
      expect(vehicle.apartmentId, 'apt-101');
      expect(vehicle.plateNumber, '29A-123.45');
      expect(vehicle.isMotorbike, true);
      expect(vehicle.isCar, false);
      expect(vehicle.vehicleTypeName, 'Xe máy');

      final outputJson = vehicle.toJson();
      expect(outputJson['plate_number'], '29A-123.45');
      expect(outputJson['vehicle_type'], 'motorbike');
    });

    test('Khởi tạo và parse JSON ô tô chính xác', () {
      final json = {
        'id': 'v-2',
        'apartment_id': 'apt-101',
        'plate_number': '30E-999.99',
        'vehicle_type': 'car',
        'created_at': '2026-09-20T11:00:00Z',
      };

      final vehicle = VehicleModel.fromJson(json);

      expect(vehicle.isCar, true);
      expect(vehicle.isMotorbike, false);
      expect(vehicle.vehicleTypeName, 'Ô tô');
    });
  });

  group('AmenityBookingModel Tests', () {
    test('Parse JSON booking và join relations chính xác', () {
      final json = {
        'id': 'book-1',
        'amenity_id': 'amenity-pool',
        'apartment_id': 'apt-101',
        'booked_by': 'user-1',
        'booking_date': '2026-09-21',
        'time_slot': '07:30 - 09:00',
        'status': 'confirmed',
        'created_at': '2026-09-20T08:00:00Z',
        'building_amenities': {'name': 'Hồ bơi vô cực'},
        'apartments': {'code': 'A0110'},
        'users': {'full_name': 'Nguyễn Văn A'},
      };

      final booking = AmenityBookingModel.fromJson(json);

      expect(booking.id, 'book-1');
      expect(booking.amenityName, 'Hồ bơi vô cực');
      expect(booking.apartmentCode, 'A0110');
      expect(booking.bookerName, 'Nguyễn Văn A');
      expect(booking.timeSlot, '07:30 - 09:00');
      expect(booking.isConfirmed, true);
      expect(booking.isCancelled, false);

      final outJson = booking.toJson();
      expect(outJson['booking_date'], '2026-09-21');
      expect(outJson['time_slot'], '07:30 - 09:00');
      expect(outJson['status'], 'confirmed');
    });
  });

  group('IssueModel Before/After Resolution Proof Tests', () {
    test('Phân tách chính xác ảnh báo cáo (Trước) và ảnh nghiệm thu (Sau)', () {
      final json = {
        'id': 'issue-1',
        'apartment_id': 'apt-1',
        'reporter_id': 'user-1',
        'description': 'Hỏng bóng đèn hành lang',
        'status': 'resolved',
        'priority': 'medium',
        'created_at': '2026-09-19T08:00:00Z',
        'issue_images': [
          {'image_url': 'https://storage/before_lamp_broken.jpg', 'image_role': 'report'},
          {'image_url': 'https://storage/after_lamp_fixed.jpg', 'image_role': 'resolution_proof'},
        ],
      };

      final issue = IssueModel.fromJson(json);

      expect(issue.imageUrls.length, 2);
      expect(issue.reportImages, ['https://storage/before_lamp_broken.jpg']);
      expect(issue.resolutionProofImages, ['https://storage/after_lamp_fixed.jpg']);
    });

    test('Tương thích ngược khi không có image_role trong JSON cũ', () {
      final json = {
        'id': 'issue-2',
        'apartment_id': 'apt-1',
        'reporter_id': 'user-1',
        'description': 'Nước rỉ van khóa',
        'status': 'pending',
        'priority': 'high',
        'created_at': '2026-09-19T08:00:00Z',
        'issue_images': [
          {'image_url': 'https://storage/leak1.jpg'},
        ],
      };

      final issue = IssueModel.fromJson(json);

      expect(issue.reportImages, ['https://storage/leak1.jpg']);
      expect(issue.resolutionProofImages, isEmpty);
    });
  });
}
