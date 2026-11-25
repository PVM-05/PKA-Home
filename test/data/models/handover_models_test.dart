import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/apartment_asset_model.dart';
import 'package:vivona/data/models/apartment_handover_model.dart';
import 'package:vivona/data/models/handover_item_model.dart';

void main() {
  group('Handover Models Tests', () {
    test('ApartmentAssetModel serialization and getters', () {
      final json = {
        'id': 'asset-01',
        'apartment_id': 'apt-01',
        'building_id': 'bld-01',
        'room_area': 'living_room',
        'name': 'Điều hòa Daikin 1.5HP',
        'asset_code': 'AC-01',
        'quantity': 1,
        'condition': 'good',
        'replacement_price': 8500000.0,
        'note': 'Hoạt động tốt',
        'created_at': '2026-11-07T10:00:00Z',
      };

      final model = ApartmentAssetModel.fromJson(json);
      expect(model.id, 'asset-01');
      expect(model.roomAreaDisplayName, 'Phòng khách');
      expect(model.conditionDisplayName, 'Tốt');
      expect(model.isDamaged, isFalse);

      final damagedModel = model.copyWith(condition: 'damaged');
      expect(damagedModel.isDamaged, isTrue);
      expect(damagedModel.conditionDisplayName, 'Hư hỏng');

      final serialized = model.toJson();
      expect(serialized['name'], 'Điều hòa Daikin 1.5HP');
      expect(serialized['room_area'], 'living_room');
    });

    test('HandoverItemModel serialization and getters', () {
      final json = {
        'id': 'item-01',
        'handover_id': 'ho-01',
        'asset_id': 'asset-01',
        'item_name': 'Tủ lạnh Panasonic',
        'room_area': 'kitchen',
        'quantity': 1,
        'condition': 'damaged',
        'repair_cost': 500000.0,
        'note': 'Hỏng gioăng cao su cánh tủ',
        'photos': ['handover-docs/photos/ho-01/p1.jpg'],
      };

      final item = HandoverItemModel.fromJson(json);
      expect(item.id, 'item-01');
      expect(item.roomAreaDisplayName, 'Nhà bếp');
      expect(item.conditionDisplayName, 'Hư hỏng');
      expect(item.hasPhotos, isTrue);
      expect(item.hasDamage, isTrue);
      expect(item.repairCost, 500000.0);

      final serialized = item.toJson();
      expect(serialized['repair_cost'], 500000.0);
      expect(serialized['photos'], contains('handover-docs/photos/ho-01/p1.jpg'));
    });

    test('ApartmentHandoverModel serialization, calculation and status getters', () {
      final json = {
        'id': 'ho-01',
        'apartment_id': 'apt-01',
        'building_id': 'bld-01',
        'resident_id': 'res-01',
        'contract_id': 'ctr-01',
        'handover_type': 'move_out',
        'report_code': 'HO-202611-00001',
        'handover_date': '2026-11-07',
        'conducted_by': 'staff-01',
        'initial_electricity_reading': 1520.5,
        'initial_water_reading': 85.0,
        'deposit_held': 10000000.0,
        'total_deduction': 1500000.0,
        'deposit_refund': 8500000.0,
        'status': 'pending_resident',
        'staff_signature_url': 'signatures/staff.png',
        'resident_signature_url': null,
        'resident_notes': null,
        'staff_notes': 'Kiểm tra trả phòng',
        'pdf_url': null,
        'lookup_code': 'HK-ABCD1234EF',
      };

      final handover = ApartmentHandoverModel.fromJson(json);
      expect(handover.reportCode, 'HO-202611-00001');
      expect(handover.isMoveIn, isFalse);
      expect(handover.isPendingResident, isTrue);
      expect(handover.isConfirmed, isFalse);
      expect(handover.handoverTypeDisplayName, 'Trả nhà');
      expect(handover.statusDisplayName, 'Chờ cư dân ký');
      expect(handover.depositRefundCalculated, 8500000.0);

      final confirmedHandover = handover.copyWith(status: 'confirmed');
      expect(confirmedHandover.isConfirmed, isTrue);
      expect(confirmedHandover.statusDisplayName, 'Đã xác nhận');
    });
  });
}

