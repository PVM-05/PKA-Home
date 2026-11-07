import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_asset_model.dart';
import 'package:pka_home/data/models/apartment_handover_model.dart';
import 'package:pka_home/data/models/handover_item_model.dart';
import 'package:pka_home/data/repositories/handover_repository.dart';

void main() {
  group('HandoverRepository Tests', () {
    late HandoverRepository repository;

    setUp(() {
      repository = HandoverRepository(null, true);
    });

    test('fetchAssetsByApartment returns assets list', () async {
      final assets = await repository.fetchAssetsByApartment('apt-01');
      expect(assets, isNotEmpty);
      expect(assets.first, isA<ApartmentAssetModel>());
      expect(assets.first.apartmentId, 'apt-01');
    });

    test('fetchHandoversByBuilding returns handovers list', () async {
      final handovers = await repository.fetchHandoversByBuilding('bld-01');
      expect(handovers, isNotEmpty);
      expect(handovers.first, isA<ApartmentHandoverModel>());
      expect(handovers.first.buildingId, 'bld-01');
    });

    test('fetchHandoverDetail returns handover with items', () async {
      final handover = await repository.fetchHandoverDetail('ho-01');
      expect(handover, isNotNull);
      expect(handover!.id, 'ho-01');
      expect(handover.items, isNotEmpty);
      expect(handover.items.first, isA<HandoverItemModel>());
    });

    test('createHandover saves new handover and items', () async {
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
        totalDeduction: 0.0,
        depositRefund: 5000000.0,
        status: 'draft',
        lookupCode: 'HK-TEST9999',
      );

      final items = [
        const HandoverItemModel(
          id: 'item-test-1',
          handoverId: 'ho-test-99',
          itemName: 'Khóa cửa vân tay',
          roomArea: 'living_room',
          condition: 'good',
        ),
      ];

      final created = await repository.createHandover(newHandover, items);
      expect(created.id, 'ho-test-99');
      expect(created.items.length, 1);
    });

    test('signByStaff updates staff signature and moves to pending_resident', () async {
      final dummySignature = Uint8List.fromList([1, 2, 3, 4]);
      final updated = await repository.signByStaff('ho-01', dummySignature, notes: 'Đã kiểm tra kỹ');
      expect(updated.staffSignatureUrl, isNotNull);
      expect(updated.isPendingResident, isTrue);
    });

    test('signByResident updates resident signature and moves to confirmed', () async {
      final dummySignature = Uint8List.fromList([5, 6, 7, 8]);
      final confirmed = await repository.signByResident('ho-01', dummySignature);
      expect(confirmed.residentSignatureUrl, isNotNull);
      expect(confirmed.isConfirmed, isTrue);
    });

    test('disputeByResident records dispute notes and moves to disputed', () async {
      final disputed = await repository.disputeByResident('ho-01', 'Bồn rửa bị rò rỉ nhưng chưa ghi nhận');
      expect(disputed.status, 'disputed');
      expect(disputed.residentNotes, contains('Bồn rửa bị rò rỉ'));
    });
  });
}
