import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/bulk_invoice_validation_model.dart';
import 'package:pka_home/data/models/vehicle_model.dart';

void main() {
  test('ValidApartmentBillingItem đọc đúng estimated_total từ cả estimated_total và total_amount', () {
    final item1 = ValidApartmentBillingItem.fromJson({
      'apartment_id': 'apt-1',
      'apartment_code': 'A0101',
      'area': 70.0,
      'electric_usage': 100,
      'water_usage': 10,
      'total_amount': 1500000,
    });
    expect(item1.estimatedTotal, 1500000.0);

    final item2 = ValidApartmentBillingItem.fromJson({
      'apartment_id': 'apt-2',
      'apartment_code': 'A0102',
      'area': 80.0,
      'electric_usage': 120,
      'water_usage': 12,
      'estimated_total': 1800000,
    });
    expect(item2.estimatedTotal, 1800000.0);
  });

  test('VehicleModel xử lý chuẩn trạng thái cancelled', () {
    final v = VehicleModel(
      id: 'v-1',
      apartmentId: 'apt-1',
      vehicleType: 'motorbike',
      licensePlate: '29A-12345',
      status: 'cancelled',
      createdAt: DateTime.now(),
    );
    expect(v.isCancelled, isTrue);
    expect(v.statusDisplayName, 'Đã hủy');
  });
}
