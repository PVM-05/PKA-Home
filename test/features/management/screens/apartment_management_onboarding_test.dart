import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/apartment_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/batch_import_provider.dart';
import 'package:vivona/data/providers/management_provider.dart';
import 'package:vivona/data/providers/role_delegation_provider.dart';
import 'package:vivona/data/repositories/batch_import_repository.dart';
import 'package:vivona/features/management/screens/apartment_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBatchImportRepository extends BatchImportRepository {
  @override
  Future<Set<String>> fetchExistingApartmentCodes(String buildingId) async {
    return {'A0110'};
  }
}

void main() {
  final managerUser = UserModel(
    id: 'manager-1',
    fullName: 'Ban Quản Lý',
    phone: '0901234567',
    role: 'management',
  );

  group('ApartmentManagementScreen Onboarding & Template Tests', () {
    testWidgets('displays empty state onboarding buttons when apartment list is empty', (tester) async {
      final fakeRepo = FakeBatchImportRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(managerUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            apartmentsProvider.overrideWith((ref) async => <ApartmentModel>[]),
            batchImportRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ApartmentManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề và thông điệp khởi tạo hạ tầng rỗng
      expect(find.text('Chưa có dữ liệu căn hộ trong hệ thống'), findsOneWidget);
      expect(
        find.textContaining('Hạ tầng tòa nhà đang trống'),
        findsOneWidget,
      );

      // Kiểm tra sự hiện diện của 2 nút onboarding
      expect(find.text('Tải mẫu Excel/CSV'), findsOneWidget);
      expect(find.text('Nhập từ Excel/CSV'), findsOneWidget);

      // Kiểm tra nút tải file mẫu trên AppBar và nút nhập
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(find.byIcon(Icons.upload_file), findsNWidgets(2));
    });

    testWidgets('tapping download template button in empty state opens modal sheet', (tester) async {
      final fakeRepo = FakeBatchImportRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(managerUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            apartmentsProvider.overrideWith((ref) async => <ApartmentModel>[]),
            batchImportRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ApartmentManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm vào nút "Tải mẫu Excel/CSV"
      await tester.tap(find.text('Tải mẫu Excel/CSV'));
      await tester.pumpAndSettle();

      // Kiểm tra hiển thị BottomSheet với 2 lựa chọn Excel và CSV
      expect(find.text('Chọn định dạng file mẫu'), findsOneWidget);
      expect(find.text('File mẫu Excel (.xlsx)'), findsOneWidget);
      expect(find.text('File mẫu CSV (.csv)'), findsOneWidget);
    });
  });
}
