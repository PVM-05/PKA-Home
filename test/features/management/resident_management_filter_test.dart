import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/resident_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/features/management/screens/resident_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testAdmin = UserModel(
    id: 'admin-1',
    fullName: 'Trưởng BQL',
    role: 'admin',
  );

  final mockResidents = [
    ResidentModel(
      id: 'res-1',
      fullName: 'Nguyễn Văn A',
      email: 'a@example.com',
      phone: '0901111111',
      role: 'resident',
      isActive: true,
      isLocked: false,
      apartment: ApartmentModel(id: 'apt-1', code: 'A0101', buildingCode: 'A', floorNumber: 1, area: 70.0, isEmpty: false),
    ),
    ResidentModel(
      id: 'res-2',
      fullName: 'Trần Thị B',
      email: 'b@example.com',
      phone: '0902222222',
      role: 'resident',
      isActive: false,
      isLocked: true,
      apartment: null,
    ),
    ResidentModel(
      id: 'res-3',
      fullName: 'Lê Văn C',
      email: 'c@example.com',
      phone: '0903333333',
      role: 'technician',
      isActive: true,
      isLocked: false,
      apartment: null,
    ),
  ];

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        residentsProvider.overrideWith((ref) async => mockResidents),
        apartmentsProvider.overrideWith((ref) async => []),
        pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const MaterialApp(
        home: ResidentManagementScreen(),
      ),
    );
  }

  testWidgets('A5: Hàng công cụ hiển thị số lượng và nút Bộ lọc mở Modal Bottom Sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Kiểm tra counter text và nút Bộ lọc
    expect(find.textContaining('Hiển thị 3/3 người dùng'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Bộ lọc'), findsOneWidget);

    // 2. Mở Modal Bottom Sheet lọc
    await tester.tap(find.widgetWithText(OutlinedButton, 'Bộ lọc'));
    await tester.pumpAndSettle();

    // 3. Kiểm tra các nhóm bộ lọc và nút Đặt lại / Áp dụng trong sheet
    expect(find.text('Bộ lọc người dùng'), findsOneWidget);
    expect(find.text('Vai trò'), findsOneWidget);
    expect(find.text('Trạng thái'), findsOneWidget);
    expect(find.text('Căn hộ'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Đặt lại'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Áp dụng'), findsOneWidget);

    // 4. Chọn vai trò "Kỹ thuật viên" và bấm Áp dụng
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kỹ thuật viên'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Áp dụng'));
    await tester.pumpAndSettle();

    // 5. Kết quả sau lọc: chỉ còn Lê Văn C (1/3)
    expect(find.textContaining('Hiển thị 1/3 người dùng'), findsOneWidget);
    expect(find.text('Lê Văn C'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsNothing);

    // 6. Active Chip hiển thị trên màn hình với nút xóa
    expect(find.text('Vai trò: Kỹ thuật viên'), findsOneWidget);

    // 7. Chạm nút xóa trên active chip để đặt lại
    final removeFilterIcon = find.descendant(
      of: find.widgetWithText(InputChip, 'Vai trò: Kỹ thuật viên'),
      matching: find.byIcon(Icons.cancel),
    );
    expect(removeFilterIcon, findsOneWidget);
    await tester.tap(removeFilterIcon);
    await tester.pumpAndSettle();

    // 8. Đã quay lại hiển thị 3/3 người dùng
    expect(find.textContaining('Hiển thị 3/3 người dùng'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
  });
}
