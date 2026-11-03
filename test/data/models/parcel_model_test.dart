import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/parcel_model.dart';

void main() {
  group('ParcelModel Tests', () {
    final now = DateTime(2026, 11, 3, 10, 0);

    final sampleJson = {
      'id': 'pcl-01',
      'parcel_code': 'PCL-202611-00001',
      'apartment_id': 'apt-01',
      'recipient_name': 'Chị Lan',
      'carrier': 'SPX',
      'tracking_number': 'SPXVN0123456789',
      'description': 'Gói hàng quần áo trẻ em',
      'shelf_location': 'Kệ A1',
      'image_url': 'https://example.com/parcel.jpg',
      'pickup_pin': '582914',
      'status': 'arrived',
      'arrived_at': now.subtract(const Duration(days: 4)).toIso8601String(),
      'created_at': now.subtract(const Duration(days: 4)).toIso8601String(),
      'apartments': {
        'code': 'A0110',
        'building_code': 'A',
      },
    };

    test('fromJson parses data correctly and calculates days in storage', () {
      final model = ParcelModel.fromJson(sampleJson);

      expect(model.id, 'pcl-01');
      expect(model.parcelCode, 'PCL-202611-00001');
      expect(model.apartmentId, 'apt-01');
      expect(model.apartmentCode, 'A0110');
      expect(model.recipientName, 'Chị Lan');
      expect(model.carrier, 'SPX');
      expect(model.carrierDisplayName, 'Shopee Xpress (SPX)');
      expect(model.trackingNumber, 'SPXVN0123456789');
      expect(model.description, 'Gói hàng quần áo trẻ em');
      expect(model.shelfLocation, 'Kệ A1');
      expect(model.pickupPin, '582914');
      expect(model.status, 'arrived');
      expect(model.statusDisplayName, 'Chờ nhận tại kệ');
      expect(model.isOverdueStorage, isTrue); // > 3 ngày
    });

    test('toJson serializes correctly', () {
      final model = ParcelModel.fromJson(sampleJson);
      final json = model.toJson();

      expect(json['id'], 'pcl-01');
      expect(json['parcel_code'], 'PCL-202611-00001');
      expect(json['pickup_pin'], '582914');
      expect(json['carrier'], 'SPX');
    });

    test('copyWith updates fields correctly', () {
      final model = ParcelModel.fromJson(sampleJson);
      final updated = model.copyWith(
        status: 'collected',
        collectedAt: now,
        collectedBy: 'Chị Lan trực tiếp nhận',
      );

      expect(updated.status, 'collected');
      expect(updated.statusDisplayName, 'Đã nhận hàng');
      expect(updated.collectedBy, 'Chị Lan trực tiếp nhận');
    });
  });
}

