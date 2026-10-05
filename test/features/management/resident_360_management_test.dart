import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/resident_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/features/management/widgets/resident_360_detail_sheet.dart';

void main() {
  testWidgets('Resident360DetailSheet hiển thị thông tin cư dân và nút khóa/mở khóa tài khoản', (tester) async {
    final resident = ResidentModel(
      id: 'res-1',
      fullName: 'Nguyễn Văn A',
      phone: '0912345678',
      role: 'resident',
      isLocked: false,
      apartment: ApartmentModel(
        id: 'apt-1',
        code: 'A0101',
        buildingCode: 'A',
        floorNumber: 1,
        area: 75.0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Resident360DetailSheet(resident: resident),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra thông tin cư dân
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Căn hộ: A0101 • Cư dân'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);

    // 2. Kiểm tra nút Khóa tài khoản
    expect(find.text('Khóa tài khoản'), findsOneWidget);

    // 3. Kiểm tra các Tabs
    expect(find.text('Phương tiện'), findsOneWidget);
    expect(find.text('Hóa đơn'), findsOneWidget);
    expect(find.text('Dịch vụ'), findsOneWidget);
  });
}
