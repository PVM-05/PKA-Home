import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/front_desk_repository.dart';

void main() {
  group('Quy trình Tích hợp Khách Viếng Thăm & Bưu Kiện Lễ Tân (D6)', () {
    late FrontDeskRepository repository;

    setUp(() {
      repository = FrontDeskRepository();
    });

    test('Toan ven quy trinh Don khach QR va Giao nhan buu kien PIN', () async {
      const apartmentId = 'apt-integration-001';
      const hostUserId = 'usr-resident-001';
      const staffId = 'staff-reception-001';

      // 1. Cư dân đăng ký đón khách
      final newPass = await repository.createVisitorPass(
        apartmentId: apartmentId,
        hostUserId: hostUserId,
        visitorName: 'Nguyễn Văn Khách',
        visitorPhone: '0988777666',
        licensePlate: '29A-888.99',
        vehicleType: 'car',
        expectedArrival: DateTime.now().add(const Duration(hours: 1)),
        expectedDeparture: DateTime.now().add(const Duration(hours: 4)),
        purpose: 'visit',
        note: 'Gặp gỡ bàn giao hợp đồng',
      );

      expect(newPass.apartmentId, equals(apartmentId));
      expect(newPass.visitorName, equals('Nguyễn Văn Khách'));
      expect(newPass.passCode, startsWith('VP-'));
      expect(newPass.status, equals('pending'));
      expect(newPass.qrPayload, contains(newPass.passCode));

      // Cư dân truy vấn danh sách vé khách của căn hộ
      final residentPasses = await repository.fetchVisitorPasses(apartmentId: apartmentId);
      expect(residentPasses.any((p) => p.id == newPass.id), isTrue);

      // 2. Ban Quản Lý lễ tân quét mã vé và Check-in
      final checkInResult = await repository.checkInVisitor(
        passCode: newPass.passCode,
        guardId: staffId,
      );
      expect(checkInResult['success'], isTrue);

      final passesAfterCheckIn = await repository.fetchVisitorPasses(apartmentId: apartmentId);
      final checkedInPass = passesAfterCheckIn.firstWhere((p) => p.id == newPass.id);
      expect(checkedInPass.status, equals('checked_in'));
      expect(checkedInPass.checkInAt, isNotNull);

      // BQL kiểm tra check-out
      final checkOutResult = await repository.checkOutVisitor(
        passCode: newPass.passCode,
        guardId: staffId,
      );
      expect(checkOutResult['success'], isTrue);

      final passesAfterCheckOut = await repository.fetchVisitorPasses(apartmentId: apartmentId);
      final checkedOutPass = passesAfterCheckOut.firstWhere((p) => p.id == newPass.id);
      expect(checkedOutPass.status, equals('checked_out'));
      expect(checkedOutPass.checkOutAt, isNotNull);

      // 3. Lễ tân tiếp nhận bưu kiện từ Shipper giao đến căn hộ
      final newParcel = await repository.receiveParcel(
        apartmentId: apartmentId,
        recipientName: 'Trần Cư Dân',
        carrier: 'SPX',
        trackingNumber: 'SPXVN99887766',
        shelfLocation: 'Kệ B2 - Ô 05',
        staffId: staffId,
        description: 'Kiện hàng đồ điện tử dễ vỡ',
      );

      expect(newParcel.apartmentId, equals(apartmentId));
      expect(newParcel.carrier, equals('SPX'));
      expect(newParcel.pickupPin.length, equals(6));
      expect(newParcel.status, equals('arrived'));
      expect(newParcel.shelfLocation, equals('Kệ B2 - Ô 05'));

      // 4. Cư dân truy vấn danh sách bưu kiện của căn hộ
      final residentParcels = await repository.fetchParcels(apartmentId: apartmentId);
      final myParcel = residentParcels.firstWhere((p) => p.id == newParcel.id);
      expect(myParcel.pickupPin, equals(newParcel.pickupPin));
      expect(myParcel.shelfLocation, equals('Kệ B2 - Ô 05'));

      // 5. Cư dân ra quầy đọc sai mã PIN -> Bàn giao thất bại
      final failedResult = await repository.collectParcel(
        parcelId: newParcel.id,
        pickupPin: '000000',
        staffId: staffId,
      );
      expect(failedResult['success'], isFalse);
      expect(failedResult['message'], contains('không chính xác'));

      // Cư dân đọc đúng mã PIN -> Bàn giao thành công
      final successResult = await repository.collectParcel(
        parcelId: newParcel.id,
        pickupPin: myParcel.pickupPin,
        staffId: staffId,
        collectedBy: 'Trần Cư Dân (Chính chủ)',
      );
      expect(successResult['success'], isTrue);

      final parcelsAfterCollect = await repository.fetchParcels(apartmentId: apartmentId);
      final collectedParcel = parcelsAfterCollect.firstWhere((p) => p.id == newParcel.id);
      expect(collectedParcel.status, equals('collected'));
      expect(collectedParcel.collectedAt, isNotNull);
      expect(collectedParcel.collectedBy, equals('Trần Cư Dân (Chính chủ)'));
    });
  });
}
