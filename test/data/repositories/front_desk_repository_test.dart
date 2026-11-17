import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/utils/guard_helper.dart';
import 'package:vivona/data/repositories/front_desk_repository.dart';

void main() {
  group('FrontDeskRepository Fail-Closed Tests', () {
    late FrontDeskRepository repository;

    setUp(() {
      repository = FrontDeskRepository(null);
    });

    test('1. fetchVisitorPasses ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchVisitorPasses(),
        throwsA(isA<AppException>()),
      );
    });

    test('2. createVisitorPass ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.createVisitorPass(
          apartmentId: 'apt-01',
          hostUserId: 'usr-01',
          visitorName: 'Lê Hoàng Nam',
          expectedArrival: DateTime.now().add(const Duration(hours: 2)),
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('3. checkInVisitor ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.checkInVisitor(passCode: 'VP-202611-00001'),
        throwsA(isA<AppException>()),
      );
    });

    test('4. checkOutVisitor ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.checkOutVisitor(passCode: 'VP-202611-00001'),
        throwsA(isA<AppException>()),
      );
    });

    test('5. fetchParcels ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchParcels(),
        throwsA(isA<AppException>()),
      );
    });

    test('6. receiveParcel ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.receiveParcel(
          apartmentId: 'apt-01',
          staffId: 'staff-01',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('7. collectParcel ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.collectParcel(
          parcelId: 'pcl-01',
          pickupPin: '123456',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('8. fetchFrontDeskStats ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchFrontDeskStats(),
        throwsA(isA<AppException>()),
      );
    });
  });
}
