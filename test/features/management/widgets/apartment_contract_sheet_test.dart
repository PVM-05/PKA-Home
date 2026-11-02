import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/providers/resident_lifecycle_provider.dart';
import 'package:pka_home/data/repositories/resident_lifecycle_repository.dart';
import 'package:pka_home/features/management/widgets/apartment_contract_sheet.dart';

class FakeLifecycleRepo extends ResidentLifecycleRepository {
  final List<ResidentLeaseContractModel> contracts;
  FakeLifecycleRepo(this.contracts);

  @override
  Future<List<ResidentLeaseContractModel>> fetchApartmentContracts(String apartmentId) async {
    return contracts;
  }

  @override
  Future<Map<String, dynamic>> terminateResidentStay({
    required String userId,
    required String apartmentId,
    DateTime? terminationDate,
    String? note,
  }) async {
    return {'success': true, 'message': 'Đã kết thúc lưu trú'};
  }
}

void main() {
  final now = DateTime(2026, 10, 30);
  final mockContract = ResidentLeaseContractModel(
    id: 'c-01',
    userId: 'u-01',
    apartmentId: 'apt-01',
    fullName: 'Nguyen Thi Mai',
    phone: '0988776655',
    relationRole: 'tenant',
    status: 'active',
    startDate: now,
    depositAmount: 8000000,
    contractNumber: 'HD-A0110-2026',
    createdAt: now,
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        residentLifecycleRepositoryProvider.overrideWithValue(FakeLifecycleRepo([mockContract])),
        apartmentContractsProvider('apt-01').overrideWith((ref) => Future.value([mockContract])),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ApartmentContractSheet(
            apartmentId: 'apt-01',
            apartmentCode: 'A0110',
          ),
        ),
      ),
    );
  }

  testWidgets('ApartmentContractSheet hien thi thong tin hop dong va tien coc', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Hợp Đồng & Lưu Trú Căn Hộ A0110'), findsOneWidget);
    expect(find.text('Nguyen Thi Mai'), findsOneWidget);
    expect(find.text('Người thuê'), findsOneWidget);
    expect(find.text('Đang lưu trú'), findsOneWidget);
    expect(find.textContaining('8.000.000'), findsOneWidget);
    expect(find.text('Kết thúc lưu trú'), findsOneWidget);
  });
}
