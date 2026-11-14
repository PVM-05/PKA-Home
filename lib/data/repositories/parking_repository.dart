import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/guard_helper.dart';
import '../models/parking_slot_model.dart';
import '../models/parking_capacity_stats_model.dart';
import '../models/visitor_parking_ticket_model.dart';

class ParkingRepository {
  final SupabaseClient? _client;

  ParkingRepository([this._client]);

  SupabaseClient get _supabase {
    final c = _client;
    if (c != null) return c;
    if (SupabaseConfig.isConfigured) {
      return SupabaseConfig.client;
    }
    throw const AppException('Supabase chưa sẵn sàng');
  }

  /// 1. Lấy danh sách ô đỗ tầng hầm theo bộ lọc
  Future<List<ParkingSlotModel>> fetchSlots({
    String? buildingId,
    String? zone,
    String? slotType,
    String? status,
  }) async {
    return FailClosedGuard.guard(
      operation: 'fetchSlots',
      call: () async {
        var query = _supabase
            .from('parking_slots')
            .select(
              '*, vehicles:assigned_vehicle_id(license_plate), apartments:assigned_apartment_id(code)',
            );

        if (buildingId != null && buildingId.isNotEmpty) {
          query = query.eq('building_id', buildingId);
        }
        if (zone != null && zone.isNotEmpty && zone != 'all') {
          query = query.eq('zone', zone);
        }
        if (slotType != null && slotType.isNotEmpty && slotType != 'all') {
          query = query.eq('slot_type', slotType);
        }
        if (status != null && status.isNotEmpty && status != 'all') {
          query = query.eq('status', status);
        }

        final res = await query.order('slot_number');
        final data = res as List<dynamic>;
        return data
            .map(
              (json) => ParkingSlotModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      },
    );
  }

  /// 1b. Lấy danh sách các ô đỗ ô tô còn trống (phục vụ phê duyệt xe ô tô và gán ô đỗ)
  Future<List<ParkingSlotModel>> fetchAvailableCarSlots({
    String? buildingId,
    String? zone,
  }) async {
    return fetchSlots(
      buildingId: buildingId,
      zone: zone,
      slotType: 'car',
      status: 'available',
    );
  }

  /// 2. Lấy thống kê sức chứa bãi xe thời gian thực
  Future<ParkingCapacityStatsModel> fetchCapacityStats({
    String? buildingId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'fetchCapacityStats',
      call: () async {
        final res = await _supabase.rpc(
          'get_parking_capacity_stats',
          params: buildingId != null ? {'p_building_id': buildingId} : null,
        );
        if (res != null) {
          return ParkingCapacityStatsModel.fromJson(
            Map<String, dynamic>.from(res as Map),
          );
        }
        throw const AppException(
          'Không nhận được thống kê sức chứa bãi xe từ máy chủ',
        );
      },
    );
  }

  /// 3. Gán ô đỗ cho phương tiện / căn hộ (Sử dụng ID thật, an toàn ngoại khóa)
  Future<Map<String, dynamic>> assignSlot({
    required String slotId,
    required String vehicleId,
    required String apartmentId,
    String? slotNumber,
    String? licensePlate,
    String? apartmentCode,
  }) async {
    final bool isRealVehicle = vehicleId.isNotEmpty && !vehicleId.startsWith('veh-');
    final String? cleanVehicleId = isRealVehicle ? vehicleId : null;
    final bool isRealApartment = apartmentId.isNotEmpty && !apartmentId.startsWith('apt-');

    return FailClosedGuard.guard(
      operation: 'assignSlot',
      call: () async {
        String? targetSlotNumber = slotNumber;
        if (targetSlotNumber == null || targetSlotNumber.isEmpty) {
          final slotRes = await _supabase
              .from('parking_slots')
              .select('slot_number')
              .eq('id', slotId)
              .maybeSingle();
          targetSlotNumber = slotRes?['slot_number'] as String?;
        }

        final updateData = <String, dynamic>{
          'status': 'occupied',
          'license_plate': licensePlate,
          'apartment_code': apartmentCode,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (cleanVehicleId != null) {
          updateData['assigned_vehicle_id'] = cleanVehicleId;
        } else {
          updateData['assigned_vehicle_id'] = null;
        }

        if (isRealApartment) {
          updateData['assigned_apartment_id'] = apartmentId;
          updateData['apartment_id'] = apartmentId;
        }

        await _supabase
            .from('parking_slots')
            .update(updateData)
            .eq('id', slotId);

        if (cleanVehicleId != null) {
          await _supabase
              .from('vehicles')
              .update({
                'parking_slot_id': slotId,
                'parking_slot_number': targetSlotNumber,
              })
              .eq('id', cleanVehicleId);
        }

        return {'success': true, 'message': 'Đã gán ô đỗ thành công'};
      },
    );
  }

  /// 4. Giải phóng ô đỗ
  Future<Map<String, dynamic>> releaseSlot(String slotId) async {
    return FailClosedGuard.guard(
      operation: 'releaseSlot',
      call: () async {
        await _supabase
            .from('vehicles')
            .update({
              'parking_slot_id': null,
              'parking_slot_number': null,
            })
            .eq('parking_slot_id', slotId);

        await _supabase
            .from('parking_slots')
            .update({
              'assigned_vehicle_id': null,
              'assigned_apartment_id': null,
              'status': 'available',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', slotId);

        return {'success': true, 'message': 'Đã giải phóng ô đỗ'};
      },
    );
  }

  /// 5. Tạo vé xe vãng lai (Check-in xe vào)
  Future<Map<String, dynamic>> createVisitorTicket({
    required String licensePlate,
    required String vehicleType,
    String? buildingId,
    String? note,
  }) async {
    final now = DateTime.now();
    final codeSuffix = (now.millisecondsSinceEpoch % 100000).toString().padLeft(
      5,
      '0',
    );
    final ticketCode = 'TKT-${DateFormat('yyyyMM').format(now)}-$codeSuffix';
    final qrPayload = 'PKAPARKING:$ticketCode:$licensePlate';

    final ticket = VisitorParkingTicketModel(
      id: 'tkt-${now.millisecondsSinceEpoch}',
      buildingId: buildingId,
      ticketCode: ticketCode,
      licensePlate: licensePlate,
      vehicleType: vehicleType,
      checkInAt: now,
      status: 'in_parking',
      hourlyRate: vehicleType == 'car' ? 25000 : 5000,
      feeAmount: vehicleType == 'car' ? 25000 : 5000,
      qrPayload: qrPayload,
      note: note,
      createdAt: now,
    );

    return FailClosedGuard.guard(
      operation: 'createVisitorTicket',
      call: () async {
        final res = await _supabase
            .from('visitor_parking_tickets')
            .insert(ticket.toJson())
            .select()
            .single();
        return {
          'success': true,
          'message': 'Đã check-in xe thành công',
          'ticket': VisitorParkingTicketModel.fromJson(res),
        };
      },
    );
  }

  /// 6. Lấy danh sách các xe vãng lai đang đỗ trong bãi
  Future<List<VisitorParkingTicketModel>> fetchActiveVisitorTickets({
    String? buildingId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'fetchActiveVisitorTickets',
      call: () async {
        var query = _supabase
            .from('visitor_parking_tickets')
            .select()
            .eq('status', 'in_parking');

        if (buildingId != null && buildingId.isNotEmpty) {
          query = query.eq('building_id', buildingId);
        }

        final res = await query.order('check_in_at', ascending: false);
        final data = res as List<dynamic>;
        return data
            .map(
              (j) =>
                  VisitorParkingTicketModel.fromJson(j as Map<String, dynamic>),
            )
            .toList();
      },
    );
  }

  /// 7. Tính phí đỗ xe theo giờ
  Future<Map<String, dynamic>> calculateVisitorFee(String ticketId) async {
    return FailClosedGuard.guard(
      operation: 'calculateVisitorFee',
      call: () async {
        final res = await _supabase.rpc(
          'calculate_visitor_parking_fee',
          params: {'p_ticket_id': ticketId},
        );
        if (res != null) {
          return Map<String, dynamic>.from(res as Map);
        }
        throw const AppException('Không nhận được tính toán phí đỗ xe');
      },
    );
  }

  /// 8. Check-out và xác nhận thu tiền
  Future<Map<String, dynamic>> checkoutVisitorTicket({
    required String ticketId,
    String paymentMethod = 'vietqr',
  }) async {
    return FailClosedGuard.guard(
      operation: 'checkoutVisitorTicket',
      call: () async {
        final res = await _supabase.rpc(
          'checkout_visitor_ticket',
          params: {'p_ticket_id': ticketId, 'p_payment_method': paymentMethod},
        );
        if (res != null) {
          return Map<String, dynamic>.from(res as Map);
        }
        throw const AppException(
          'Không nhận được phản hồi check-out từ máy chủ',
        );
      },
    );
  }
}
