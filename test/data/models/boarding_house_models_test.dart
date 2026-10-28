import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/building_model.dart';

void main() {
  group('Boarding House Models Tests', () {
    test('ApartmentModel correctly deserializes and serializes boarding house fields', () {
      final json = {
        'id': 'apt-bh-01',
        'code': 'P101',
        'building_id': 'b-bh-01',
        'block': 'CS01',
        'floor': 1,
        'area': 25.5,
        'rent_price': 3800000,
        'deposit_amount': 3800000,
        'max_occupants': 3,
        'has_own_electric_meter': true,
        'has_own_water_meter': false,
        'contract_start_date': '2026-09-01',
        'contract_end_date': '2027-08-31',
        'is_empty': false,
      };

      final apt = ApartmentModel.fromJson(json);

      expect(apt.id, 'apt-bh-01');
      expect(apt.code, 'P101');
      expect(apt.buildingCode, 'CS01');
      expect(apt.floorNumber, 1);
      expect(apt.area, 25.5);
      expect(apt.rentPrice, 3800000.0);
      expect(apt.depositAmount, 3800000.0);
      expect(apt.maxOccupants, 3);
      expect(apt.hasOwnElectricMeter, isTrue);
      expect(apt.hasOwnWaterMeter, isFalse);
      expect(apt.contractStartDate, '2026-09-01');
      expect(apt.contractEndDate, '2027-08-31');
      expect(apt.isEmpty, isFalse);

      final serialized = apt.toJson();
      expect(serialized['rent_price'], 3800000.0);
      expect(serialized['deposit_amount'], 3800000.0);
      expect(serialized['max_occupants'], 3);
      expect(serialized['has_own_electric_meter'], isTrue);
      expect(serialized['has_own_water_meter'], isFalse);
      expect(serialized['contract_start_date'], '2026-09-01');
      expect(serialized['contract_end_date'], '2027-08-31');
    });

    test('ApartmentModel gracefully handles short or flexible room codes without crashing', () {
      final jsonShort = {
        'id': 'apt-short',
        'code': '1',
      };
      final aptShort = ApartmentModel.fromJson(jsonShort);
      expect(aptShort.code, '1');
      expect(aptShort.buildingCode, '1');
      expect(aptShort.floorNumber, 1);

      final jsonCustom = {
        'id': 'apt-custom',
        'code': 'Phòng 10',
        'floor': 2,
        'block': 'Dãy A',
      };
      final aptCustom = ApartmentModel.fromJson(jsonCustom);
      expect(aptCustom.code, 'Phòng 10');
      expect(aptCustom.buildingCode, 'Dãy A');
      expect(aptCustom.floorNumber, 2);
    });

    test('BuildingModel correctly identifies boarding_house propertyType', () {
      final json = {
        'id': 'b-bh-01',
        'organization_id': 'org-01',
        'name': 'Nhà trọ Kim Mã',
        'code': 'TRO_KM',
        'property_type': 'boarding_house',
      };

      final building = BuildingModel.fromJson(json);

      expect(building.propertyType, 'boarding_house');
      expect(building.isBoardingHouse, isTrue);

      final jsonApt = {
        'id': 'b-apt-01',
        'organization_id': 'org-01',
        'name': 'PKA Landmark',
        'code': 'PKAL',
      };
      final buildingApt = BuildingModel.fromJson(jsonApt);
      expect(buildingApt.propertyType, 'apartment');
      expect(buildingApt.isBoardingHouse, isFalse);
    });
  });
}
