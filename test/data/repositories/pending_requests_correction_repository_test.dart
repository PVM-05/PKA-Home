import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/data/repositories/meter_reading_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final dynamic _result;
  FakePostgrestFilterBuilder(this._result);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) {
    return Future.value(_result).then(onValue, onError: onError);
  }
}

void main() {
  group('Repository Unit Tests: Sửa sai & Hủy yêu cầu chờ duyệt', () {
    late MockSupabaseClient mockClient;

    setUp(() {
      mockClient = MockSupabaseClient();
    });

    group('VehicleRepository', () {
      test('updatePendingVehicle gọi đúng RPC update_pending_vehicle và map tham số', () async {
        when(() => mockClient.rpc(
              'update_pending_vehicle',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': true, 'message': 'OK'}));

        final repo = VehicleRepository(mockClient);
        await repo.updatePendingVehicle(
          vehicleId: 'veh-123',
          licensePlate: '29A-12345',
          vehicleType: 'motorbike',
          brandModel: 'Honda Wave',
        );

        verify(() => mockClient.rpc('update_pending_vehicle', params: {
              'p_vehicle_id': 'veh-123',
              'p_license_plate': '29A-12345',
              'p_vehicle_type': 'motorbike',
              'p_brand_model': 'Honda Wave',
            })).called(1);
      });

      test('updatePendingVehicle ném Exception khi RPC trả về success = false', () async {
        when(() => mockClient.rpc(
              'update_pending_vehicle',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': false, 'message': 'Phương tiện không tồn tại'}));

        final repo = VehicleRepository(mockClient);
        expect(
          () => repo.updatePendingVehicle(
            vehicleId: 'veh-123',
            licensePlate: '29A-12345',
            vehicleType: 'motorbike',
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Phương tiện không tồn tại'))),
        );
      });

      test('cancelPendingVehicle gọi đúng RPC cancel_pending_vehicle', () async {
        when(() => mockClient.rpc(
              'cancel_pending_vehicle',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': true, 'message': 'OK'}));

        final repo = VehicleRepository(mockClient);
        await repo.cancelPendingVehicle('veh-123');

        verify(() => mockClient.rpc('cancel_pending_vehicle', params: {
              'p_vehicle_id': 'veh-123',
            })).called(1);
      });

      test('cancelPendingVehicle ném Exception khi RPC trả về success = false', () async {
        when(() => mockClient.rpc(
              'cancel_pending_vehicle',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': false, 'message': 'Không có quyền'}));

        final repo = VehicleRepository(mockClient);
        expect(
          () => repo.cancelPendingVehicle('veh-123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Không có quyền'))),
        );
      });
    });

    group('AmenityBookingRepository', () {
      test('rescheduleBooking gọi đúng RPC reschedule_amenity_booking với đúng định dạng tham số', () async {
        final targetDate = DateTime(2026, 11, 1);
        when(() => mockClient.rpc(
              'reschedule_amenity_booking',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({
              'success': true,
              'action': 'rescheduled_confirmed',
              'status': 'confirmed',
              'message': 'Đổi lịch thành công',
            }));

        final repo = AmenityBookingRepository(mockClient);
        final res = await repo.rescheduleBooking(
          bookingId: 'bk-123',
          newDate: targetDate,
          newTimeSlot: '08:00 - 10:00',
          newGuestsCount: 2,
          newNotes: 'Ghi chú',
        );

        verify(() => mockClient.rpc('reschedule_amenity_booking', params: {
              'p_booking_id': 'bk-123',
              'p_new_date': '2026-11-01',
              'p_new_time_slot': '08:00 - 10:00',
              'p_new_guests_count': 2,
              'p_new_notes': 'Ghi chú',
            })).called(1);

        expect(res['action'], 'rescheduled_confirmed');
        expect(res['status'], 'confirmed');
      });

      test('rescheduleBooking ném Exception khi RPC trả về success = false', () async {
        when(() => mockClient.rpc(
              'reschedule_amenity_booking',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': false, 'message': 'Khung giờ đã hết chỗ'}));

        final repo = AmenityBookingRepository(mockClient);
        expect(
          () => repo.rescheduleBooking(
            bookingId: 'bk-123',
            newDate: DateTime(2026, 11, 1),
            newTimeSlot: '08:00 - 10:00',
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Khung giờ đã hết chỗ'))),
        );
      });
    });

    group('MeterReadingRepository', () {
      test('updatePendingSubmission gọi đúng RPC update_pending_meter_reading', () async {
        when(() => mockClient.rpc(
              'update_pending_meter_reading',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': true, 'message': 'OK'}));

        final repo = MeterReadingRepository(mockClient);
        await repo.updatePendingSubmission(
          submissionId: 'sub-123',
          electricReading: 120.5,
          waterReading: 30.0,
          clearElectricImage: true,
        );

        verify(() => mockClient.rpc('update_pending_meter_reading', params: {
              'p_submission_id': 'sub-123',
              'p_electric_reading': 120.5,
              'p_water_reading': 30.0,
              'p_clear_electric_image': true,
              'p_clear_water_image': false,
            })).called(1);
      });

      test('updatePendingSubmission ném Exception khi RPC trả về success = false', () async {
        when(() => mockClient.rpc(
              'update_pending_meter_reading',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': false, 'message': 'Không thể cập nhật chỉ số'}));

        final repo = MeterReadingRepository(mockClient);
        expect(
          () => repo.updatePendingSubmission(
            submissionId: 'sub-123',
            electricReading: 120.5,
            waterReading: 30.0,
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Không thể cập nhật chỉ số'))),
        );
      });

      test('cancelPendingSubmission gọi đúng RPC cancel_pending_meter_reading', () async {
        when(() => mockClient.rpc(
              'cancel_pending_meter_reading',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': true, 'message': 'OK'}));

        final repo = MeterReadingRepository(mockClient);
        await repo.cancelPendingSubmission('sub-123');

        verify(() => mockClient.rpc('cancel_pending_meter_reading', params: {
              'p_submission_id': 'sub-123',
            })).called(1);
      });

      test('cancelPendingSubmission ném Exception khi RPC trả về success = false', () async {
        when(() => mockClient.rpc(
              'cancel_pending_meter_reading',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder({'success': false, 'message': 'Không tìm thấy phiếu'}));

        final repo = MeterReadingRepository(mockClient);
        expect(
          () => repo.cancelPendingSubmission('sub-123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Không tìm thấy phiếu'))),
        );
      });
    });
  });
}
