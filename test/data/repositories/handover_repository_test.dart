import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/guard_helper.dart';
import 'package:pka_home/data/models/apartment_handover_model.dart';
import 'package:pka_home/data/repositories/handover_repository.dart';

void main() {
  group('HandoverRepository Fail-Closed Tests', () {
    late HandoverRepository repository;

    setUp(() {
      repository = HandoverRepository(null);
    });

    test('1. fetchAssetsByApartment ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchAssetsByApartment('apt-01'),
        throwsA(isA<AppException>()),
      );
    });

    test('2. fetchHandoversByBuilding ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchHandoversByBuilding('bld-01'),
        throwsA(isA<AppException>()),
      );
    });

    test('3. fetchHandoverDetail ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchHandoverDetail('ho-01'),
        throwsA(isA<AppException>()),
      );
    });

    test('4. createHandover ném AppException khi không có kết nối Supabase', () async {
      final newHandover = ApartmentHandoverModel(
        id: 'ho-test-99',
        apartmentId: 'apt-01',
        buildingId: 'bld-01',
        residentId: 'res-01',
        contractId: 'ctr-01',
        handoverType: 'move_in',
        reportCode: 'HO-202611-00099',
        handoverDate: DateTime.now(),
        conductedBy: 'staff-01',
        initialElectricityReading: 1200.0,
        initialWaterReading: 50.0,
        depositHeld: 5000000.0,
        totalDeduction: 0,
        depositRefund: 5000000.0,
        status: 'draft',
        lookupCode: 'HK-TEST01',
        apartmentCode: 'A0110',
        residentName: 'Nguyễn Văn An',
        staffName: 'Trần Kỹ Thuật',
      );

      expect(
        () => repository.createHandover(newHandover, []),
        throwsA(isA<AppException>()),
      );
    });

    test('5. signByStaff ném AppException khi không có kết nối Supabase', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      expect(
        () => repository.signByStaff('ho-01', fakeBytes),
        throwsA(isA<AppException>()),
      );
    });

    test('6. signByResident ném AppException khi không có kết nối Supabase', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      expect(
        () => repository.signByResident('ho-01', fakeBytes),
        throwsA(isA<AppException>()),
      );
    });
  });
}
