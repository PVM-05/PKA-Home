import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/features/resident/screens/vehicle_management_screen.dart';

void main() {
  testWidgets('VehicleManagementScreen hiển thị nút Sửa và Hủy cho xe pending, ẩn nút Sửa cho xe approved', (tester) async {
    final pendingVehicle = VehicleModel(
      id: 'veh-pending-1',
      apartmentId: 'apt-1',
      vehicleType: 'motorbike',
      licensePlate: '29A-111.11',
      brandModel: 'Honda Wave',
      status: 'pending',
      createdAt: DateTime.now(),
    );

    final approvedVehicle = VehicleModel(
      id: 'veh-approved-1',
      apartmentId: 'apt-1',
      vehicleType: 'car',
      licensePlate: '30E-222.22',
      brandModel: 'Toyota Vios',
      status: 'approved',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          residentApartmentIdProvider.overrideWith((ref) => Future.value('apt-1')),
          apartmentVehiclesProvider('apt-1').overrideWith(
            (ref) => Stream.value([pendingVehicle, approvedVehicle]),
          ),
        ],
        child: const MaterialApp(
          home: VehicleManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Xác nhận hiển thị 2 xe
    expect(find.text('29A-111.11'), findsOneWidget);
    expect(find.text('30E-222.22'), findsOneWidget);

    // Nút Sửa (Icons.edit_outlined hoặc tooltip 'Sửa thông tin xe') phải xuất hiện cho xe pending
    expect(find.byTooltip('Sửa thông tin xe'), findsOneWidget);

    // Nút Hủy cho xe pending
    expect(find.byTooltip('Hủy đăng ký xe'), findsWidgets);
  });
}
