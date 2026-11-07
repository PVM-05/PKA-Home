import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockStorageFileApi extends Mock implements StorageFileApi {}
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

class FakeTransformBuilder<T> extends Fake implements PostgrestTransformBuilder<T> {
  final T _val;
  FakeTransformBuilder(this._val);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_val).then(onValue, onError: onError);
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    Map<String, dynamic>? item;
    if (_val is List && (_val as List).isNotEmpty) {
      item = (_val as List).first as Map<String, dynamic>?;
    } else if (_val is Map<String, dynamic>) {
      item = _val as Map<String, dynamic>;
    }
    return FakeTransformBuilder<Map<String, dynamic>?>(item);
  }
}

class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _val;
  FakeFilterBuilder(this._val);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([String columns = '*']) =>
      FakeTransformBuilder<List<Map<String, dynamic>>>(_val as List<Map<String, dynamic>>);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_val).then(onValue, onError: onError);
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    Map<String, dynamic>? item;
    if (_val is List && (_val as List).isNotEmpty) {
      item = (_val as List).first as Map<String, dynamic>?;
    } else if (_val is Map<String, dynamic>) {
      item = _val as Map<String, dynamic>;
    }
    return FakeTransformBuilder<Map<String, dynamic>?>(item);
  }
}

class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _val;
  FakeQueryBuilder(this._val);

  @override
  PostgrestFilterBuilder update(Map values, {String? defaultToNull}) => FakeFilterBuilder(_val);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) =>
      FakeFilterBuilder<List<Map<String, dynamic>>>(_val is List<Map<String, dynamic>> ? _val : [_val as Map<String, dynamic>]);
}

void main() {
  group('VehicleModel & VehicleRepository Unit Tests', () {
    late MockSupabaseClient mockClient;
    late MockSupabaseStorageClient mockStorage;
    late MockStorageFileApi mockStorageFileApi;
    late VehicleRepository repository;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockStorage = MockSupabaseStorageClient();
      mockStorageFileApi = MockStorageFileApi();
      when(() => mockClient.storage).thenReturn(mockStorage);
      when(() => mockStorage.from('vehicle-docs')).thenReturn(mockStorageFileApi);
      repository = VehicleRepository(mockClient);
    });

    test('VehicleModel parse đúng các trường registrationImageUrl, parkingSlotId, parkingSlotNumber', () {
      final json = {
        'id': 'veh-001',
        'apartment_id': 'apt-001',
        'user_id': 'usr-001',
        'vehicle_type': 'car',
        'license_plate': '30A-999.88',
        'brand_model': 'Mazda CX-5',
        'status': 'approved',
        'registration_image_url': 'apt-001/usr-001/cavat_123.jpg',
        'parking_slot_id': 'slot-b1-05',
        'parking_slot_number': 'P-B1-05',
        'approved_at': '2026-11-07T12:00:00Z',
        'approved_by': 'usr-admin-01',
        'created_at': '2026-11-07T10:00:00Z',
      };

      final model = VehicleModel.fromJson(json);

      expect(model.id, 'veh-001');
      expect(model.registrationImageUrl, 'apt-001/usr-001/cavat_123.jpg');
      expect(model.parkingSlotId, 'slot-b1-05');
      expect(model.parkingSlotNumber, 'P-B1-05');
      expect(model.approvedAt, isNotNull);
      expect(model.approvedBy, 'usr-admin-01');
      expect(model.hasRegistrationImage, isTrue);
      expect(model.hasAssignedSlot, isTrue);

      final outJson = model.toJson();
      expect(outJson['registration_image_url'], 'apt-001/usr-001/cavat_123.jpg');
      expect(outJson['parking_slot_id'], 'slot-b1-05');
      expect(outJson['parking_slot_number'], 'P-B1-05');
    });

    test('VehicleModel copyWith hỗ trợ cập nhật ảnh đăng ký và vị trí ô đỗ', () {
      final model = VehicleModel(
        id: 'veh-002',
        apartmentId: 'apt-001',
        vehicleType: 'car',
        licensePlate: '30E-123.45',
        createdAt: DateTime.now(),
      );

      expect(model.hasRegistrationImage, isFalse);
      expect(model.hasAssignedSlot, isFalse);

      final updated = model.copyWith(
        registrationImageUrl: 'apt-001/cavat.png',
        parkingSlotId: 'slot-b1-01',
        parkingSlotNumber: 'P-B1-01',
        status: 'approved',
      );

      expect(updated.hasRegistrationImage, isTrue);
      expect(updated.hasAssignedSlot, isTrue);
      expect(updated.parkingSlotNumber, 'P-B1-01');
      expect(updated.status, 'approved');
    });

    test('VehicleRepository.getRegistrationImageUrl trả đúng URL trực tiếp hoặc public URL', () {
      expect(repository.getRegistrationImageUrl(null), '');
      expect(repository.getRegistrationImageUrl(''), '');
      expect(
        repository.getRegistrationImageUrl('https://supabase.co/storage/v1/object/public/vehicle-docs/cavat.jpg'),
        'https://supabase.co/storage/v1/object/public/vehicle-docs/cavat.jpg',
      );

      when(() => mockStorageFileApi.getPublicUrl('apt-001/cavat.jpg'))
          .thenReturn('https://mocked.supabase.co/vehicle-docs/apt-001/cavat.jpg');
      expect(
        repository.getRegistrationImageUrl('apt-001/cavat.jpg'),
        'https://mocked.supabase.co/vehicle-docs/apt-001/cavat.jpg',
      );
    });

    test('VehicleRepository.approveVehicle hỗ trợ gán parkingSlotId và parkingSlotNumber', () async {
      when(() => mockClient.from('vehicles')).thenAnswer((_) => FakeQueryBuilder({
        'id': 'veh-001',
        'license_plate': '30A-999.88',
        'apartment_id': 'apt-001',
      }));
      when(() => mockClient.from('parking_slots')).thenAnswer((_) => FakeQueryBuilder({}));

      await repository.approveVehicle(
        'veh-001',
        parkingSlotId: 'slot-01',
        parkingSlotNumber: 'P-B1-01',
        approvedBy: 'admin-01',
      );

      verify(() => mockClient.from('vehicles')).called(greaterThanOrEqualTo(1));
      verify(() => mockClient.from('parking_slots')).called(greaterThanOrEqualTo(1));
    });

    test('VehicleRepository.rejectVehicle giải phóng parking slot nếu xe đã có ô đỗ', () async {
      when(() => mockClient.from('vehicles')).thenAnswer((_) => FakeQueryBuilder({
        'id': 'veh-001',
        'parking_slot_id': 'slot-01',
      }));
      when(() => mockClient.from('parking_slots')).thenAnswer((_) => FakeQueryBuilder({}));

      await repository.rejectVehicle('veh-001', reason: 'Ảnh cà vẹt mờ không rõ số khung');

      verify(() => mockClient.from('vehicles')).called(greaterThanOrEqualTo(1));
      verify(() => mockClient.from('parking_slots')).called(greaterThanOrEqualTo(1));
    });
  });
}
