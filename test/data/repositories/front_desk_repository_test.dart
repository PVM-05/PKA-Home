import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/front_desk_repository.dart';

void main() {
  group('FrontDeskRepository Tests (Offline Fallback Engine)', () {
    late FrontDeskRepository repository;

    setUp(() {
      repository = FrontDeskRepository(null); // Offline mode
    });

    test('1. fetchVisitorPasses tra ve danh sach mau', () async {
      final list = await repository.fetchVisitorPasses();
      expect(list.isNotEmpty, isTrue);
      expect(list.first.passCode, startsWith('VP-'));
    });

    test('2. createVisitorPass them moi ve khach', () async {
      final now = DateTime.now();
      final newPass = await repository.createVisitorPass(
        apartmentId: 'apt-01',
        hostUserId: 'usr-01',
        visitorName: 'Lê Hoàng Nam',
        visitorPhone: '0988776655',
        licensePlate: '29A-123.45',
        vehicleType: 'car',
        visitorCount: 2,
        expectedArrival: now.add(const Duration(hours: 2)),
        purpose: 'visit',
        note: 'Đến ăn trưa cuối tuần',
      );

      expect(newPass.passCode, startsWith('VP-'));
      expect(newPass.visitorName, 'Lê Hoàng Nam');
      expect(newPass.status, 'pending');
      expect(newPass.qrPayload, startsWith('PKAPASS'));

      // Kiểm tra danh sách cập nhật
      final all = await repository.fetchVisitorPasses();
      expect(all.any((p) => p.id == newPass.id), isTrue);
    });

    test('3. checkInVisitor chuyen trang thai checked_in', () async {
      final list = await repository.fetchVisitorPasses();
      final pendingPass = list.firstWhere((p) => p.status == 'pending');

      final result = await repository.checkInVisitor(
        passCode: pendingPass.passCode,
        guardId: 'usr-guard-01',
      );

      expect(result['success'], isTrue);

      final updated = await repository.fetchVisitorPasses();
      final target = updated.firstWhere((p) => p.passCode == pendingPass.passCode);
      expect(target.status, 'checked_in');
      expect(target.checkInAt, isNotNull);
    });

    test('4. checkOutVisitor chuyen trang thai checked_out', () async {
      final list = await repository.fetchVisitorPasses();
      final inPass = list.firstWhere((p) => p.status == 'checked_in');

      final result = await repository.checkOutVisitor(
        passCode: inPass.passCode,
        guardId: 'usr-guard-01',
      );

      expect(result['success'], isTrue);

      final updated = await repository.fetchVisitorPasses();
      final target = updated.firstWhere((p) => p.passCode == inPass.passCode);
      expect(target.status, 'checked_out');
      expect(target.checkOutAt, isNotNull);
    });

    test('5. fetchParcels tra ve danh sach buu kien', () async {
      final parcels = await repository.fetchParcels();
      expect(parcels.isNotEmpty, isTrue);
      expect(parcels.first.parcelCode, startsWith('PCL-'));
    });

    test('6. receiveParcel tiep nhan buu kien va sinh ma PIN 6 so', () async {
      final newParcel = await repository.receiveParcel(
        apartmentId: 'apt-01',
        recipientName: 'Anh Minh',
        carrier: 'GHTK',
        trackingNumber: 'GHTKVN998877',
        description: 'Tài liệu hợp đồng',
        shelfLocation: 'Kệ B2',
        staffId: 'usr-staff-01',
      );

      expect(newParcel.parcelCode, startsWith('PCL-'));
      expect(newParcel.pickupPin.length, 6);
      expect(newParcel.status, 'arrived');

      final all = await repository.fetchParcels();
      expect(all.any((p) => p.id == newParcel.id), isTrue);
    });

    test('7. collectParcel xac thuc PIN va ban giao', () async {
      final parcels = await repository.fetchParcels();
      final pending = parcels.firstWhere((p) => p.status == 'arrived');

      // Thử sai PIN
      final wrongRes = await repository.collectParcel(
        parcelId: pending.id,
        pickupPin: '000000',
        staffId: 'usr-staff-01',
      );
      expect(wrongRes['success'], isFalse);

      // Đúng PIN
      final rightRes = await repository.collectParcel(
        parcelId: pending.id,
        pickupPin: pending.pickupPin,
        staffId: 'usr-staff-01',
        collectedBy: 'Chủ hộ',
      );
      expect(rightRes['success'], isTrue);

      final updated = await repository.fetchParcels();
      final collected = updated.firstWhere((p) => p.id == pending.id);
      expect(collected.status, 'collected');
      expect(collected.collectedAt, isNotNull);
    });

    test('8. fetchFrontDeskStats tra ve so lieu thong ke', () async {
      final stats = await repository.fetchFrontDeskStats();
      expect(stats.expectedVisitorsToday >= 0, isTrue);
      expect(stats.pendingParcels >= 0, isTrue);
    });
  });
}

