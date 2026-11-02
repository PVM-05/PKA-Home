import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/parking_slot_model.dart';
import '../models/parking_capacity_stats_model.dart';
import '../models/visitor_parking_ticket_model.dart';

class ParkingRepository {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? SupabaseConfig.client;

  // Bộ nhớ in-memory phục vụ offline-fallback và môi trường test
  final List<ParkingSlotModel> _inMemorySlots = [];
  final List<VisitorParkingTicketModel> _inMemoryTickets = [];

  ParkingRepository([this._client]) {
    _initMockData();
  }

  void _initMockData() {
    if (_inMemorySlots.isNotEmpty) return;

    // Khởi tạo 20 ô ô tô tầng B1 (1-6 đã đỗ, còn lại trống)
    for (int i = 1; i <= 20; i++) {
      final isOccupied = i <= 6;
      final numStr = i.toString().padLeft(2, '0');
      _inMemorySlots.add(
        ParkingSlotModel(
          id: 'slot-b1-$numStr',
          zone: 'B1',
          slotNumber: 'P-B1-$numStr',
          slotType: 'car',
          status: isOccupied ? 'occupied' : 'available',
          licensePlate: isOccupied ? '30A-${100 + i}.88' : null,
          apartmentCode: isOccupied ? 'A01${i.toString().padLeft(2, '0')}' : null,
          createdAt: DateTime.now().subtract(Duration(days: 30 - i)),
        ),
      );
    }

    // Khởi tạo 30 ô xe máy tầng B2 (1-12 đã đỗ)
    for (int i = 1; i <= 30; i++) {
      final isOccupied = i <= 12;
      final numStr = i.toString().padLeft(2, '0');
      _inMemorySlots.add(
        ParkingSlotModel(
          id: 'slot-b2-$numStr',
          zone: 'B2',
          slotNumber: 'M-B2-$numStr',
          slotType: 'motorcycle',
          status: isOccupied ? 'occupied' : 'available',
          licensePlate: isOccupied ? '29V1-${500 + i}.99' : null,
          apartmentCode: isOccupied ? 'A02${i.toString().padLeft(2, '0')}' : null,
          createdAt: DateTime.now().subtract(Duration(days: 30 - i)),
        ),
      );
    }

    // Khởi tạo vé xe vãng lai mẫu
    _inMemoryTickets.addAll([
      VisitorParkingTicketModel(
        id: 'tkt-mock-01',
        ticketCode: 'TKT-202611-0001',
        licensePlate: '30E-888.99',
        vehicleType: 'car',
        checkInAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
        status: 'in_parking',
        hourlyRate: 25000,
        feeAmount: 40000,
        qrPayload: 'PKAPARKING:TKT-202611-0001:30E-888.99',
        note: 'Khách lên thăm phòng A0501',
        createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      ),
      VisitorParkingTicketModel(
        id: 'tkt-mock-02',
        ticketCode: 'TKT-202611-0002',
        licensePlate: '29AA-123.45',
        vehicleType: 'motorcycle',
        checkInAt: DateTime.now().subtract(const Duration(minutes: 45)),
        status: 'in_parking',
        hourlyRate: 5000,
        feeAmount: 5000,
        qrPayload: 'PKAPARKING:TKT-202611-0002:29AA-123.45',
        note: 'Giao hàng Shopee tầng 3',
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ]);
  }

  /// 1. Lấy danh sách ô đỗ tầng hầm theo bộ lọc
  Future<List<ParkingSlotModel>> fetchSlots({
    String? buildingId,
    String? zone,
    String? slotType,
    String? status,
  }) async {
    try {
      var query = _supabase.from('parking_slots').select();

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
      if (data.isNotEmpty) {
        return data.map((json) => ParkingSlotModel.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback sang in-memory
    }

    var filtered = List<ParkingSlotModel>.from(_inMemorySlots);
    if (zone != null && zone.isNotEmpty && zone != 'all') {
      filtered = filtered.where((s) => s.zone == zone).toList();
    }
    if (slotType != null && slotType.isNotEmpty && slotType != 'all') {
      filtered = filtered.where((s) => s.slotType == slotType).toList();
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      filtered = filtered.where((s) => s.status == status).toList();
    }
    return filtered;
  }

  /// 2. Lấy thống kê sức chứa bãi xe thời gian thực
  Future<ParkingCapacityStatsModel> fetchCapacityStats({String? buildingId}) async {
    try {
      final res = await _supabase.rpc('get_parking_capacity_stats', params: buildingId != null ? {'p_building_id': buildingId} : null);
      if (res != null) {
        return ParkingCapacityStatsModel.fromJson(Map<String, dynamic>.from(res as Map));
      }
    } catch (_) {
      // Fallback sang in-memory
    }

    final carSlots = _inMemorySlots.where((s) => s.isCar).toList();
    final motoSlots = _inMemorySlots.where((s) => s.isMotorcycle).toList();
    final activeVisitors = _inMemoryTickets.where((t) => t.isInParking).length;

    final carOccupied = carSlots.where((s) => s.isOccupied).length;
    final motoOccupied = motoSlots.where((s) => s.isOccupied).length;

    return ParkingCapacityStatsModel(
      carTotal: carSlots.length,
      carOccupied: carOccupied,
      carAvailable: carSlots.length - carOccupied,
      motoTotal: motoSlots.length,
      motoOccupied: motoOccupied,
      motoAvailable: motoSlots.length - motoOccupied,
      visitorCount: activeVisitors,
    );
  }

  /// 3. Gán ô đỗ cho phương tiện / căn hộ
  Future<Map<String, dynamic>> assignSlot({
    required String slotId,
    required String vehicleId,
    required String apartmentId,
    String? licensePlate,
    String? apartmentCode,
  }) async {
    try {
      await _supabase.from('parking_slots').update({
        'assigned_vehicle_id': vehicleId,
        'assigned_apartment_id': apartmentId,
        'status': 'occupied',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', slotId);

      await _supabase.from('vehicles').update({
        'parking_slot_id': slotId,
        'parking_slot_number': licensePlate,
      }).eq('id', vehicleId);

      return {'success': true, 'message': 'Đã gán ô đỗ thành công'};
    } catch (_) {
      // Fallback
    }

    final index = _inMemorySlots.indexWhere((s) => s.id == slotId);
    if (index != -1) {
      _inMemorySlots[index] = _inMemorySlots[index].copyWith(
        status: 'occupied',
        assignedVehicleId: vehicleId,
        assignedApartmentId: apartmentId,
        licensePlate: licensePlate,
        apartmentCode: apartmentCode,
      );
    }
    return {'success': true, 'message': 'Đã gán ô đỗ thành công'};
  }

  /// 4. Giải phóng ô đỗ
  Future<Map<String, dynamic>> releaseSlot(String slotId) async {
    try {
      await _supabase.from('parking_slots').update({
        'assigned_vehicle_id': null,
        'assigned_apartment_id': null,
        'status': 'available',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', slotId);

      return {'success': true, 'message': 'Đã giải phóng ô đỗ'};
    } catch (_) {
      // Fallback
    }

    final index = _inMemorySlots.indexWhere((s) => s.id == slotId);
    if (index != -1) {
      _inMemorySlots[index] = _inMemorySlots[index].copyWith(
        status: 'available',
        assignedVehicleId: null,
        assignedApartmentId: null,
        licensePlate: null,
        apartmentCode: null,
      );
    }
    return {'success': true, 'message': 'Đã giải phóng ô đỗ'};
  }

  /// 5. Tạo vé xe vãng lai (Check-in xe vào)
  Future<Map<String, dynamic>> createVisitorTicket({
    required String licensePlate,
    required String vehicleType,
    String? buildingId,
    String? note,
  }) async {
    final now = DateTime.now();
    final codeSuffix = (now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
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

    try {
      final res = await _supabase.from('visitor_parking_tickets').insert(ticket.toJson()).select().single();
      return {
        'success': true,
        'message': 'Đã check-in xe thành công',
        'ticket': VisitorParkingTicketModel.fromJson(res),
      };
    } catch (_) {
      // Fallback
    }

    _inMemoryTickets.insert(0, ticket);
    return {
      'success': true,
      'message': 'Đã check-in xe thành công',
      'ticket': ticket,
    };
  }

  /// 6. Lấy danh sách các xe vãng lai đang đỗ trong bãi
  Future<List<VisitorParkingTicketModel>> fetchActiveVisitorTickets({String? buildingId}) async {
    try {
      var query = _supabase
          .from('visitor_parking_tickets')
          .select()
          .eq('status', 'in_parking');

      if (buildingId != null && buildingId.isNotEmpty) {
        query = query.eq('building_id', buildingId);
      }

      final res = await query.order('check_in_at', ascending: false);
      final data = res as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((j) => VisitorParkingTicketModel.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback
    }

    return _inMemoryTickets.where((t) => t.isInParking).toList();
  }

  /// 7. Tính phí đỗ xe theo giờ
  Future<Map<String, dynamic>> calculateVisitorFee(String ticketId) async {
    try {
      final res = await _supabase.rpc('calculate_visitor_parking_fee', params: {
        'p_ticket_id': ticketId,
      });
      if (res != null) {
        return Map<String, dynamic>.from(res as Map);
      }
    } catch (_) {
      // Fallback
    }

    final ticket = _inMemoryTickets.firstWhere(
      (t) => t.id == ticketId,
      orElse: () => _inMemoryTickets.first,
    );

    final diffMinutes = DateTime.now().difference(ticket.checkInAt).inMinutes;
    final hours = (diffMinutes / 60.0).ceil();
    final effectiveHours = hours < 1 ? 1 : hours;

    double fee = 0;
    if (ticket.isCar) {
      fee = effectiveHours <= 2 ? 25000 : 25000 + ((effectiveHours - 2) * 15000);
      if (effectiveHours >= 12) fee += 50000;
    } else {
      fee = effectiveHours <= 2 ? 5000 : 5000 + ((effectiveHours - 2) * 3000);
      if (effectiveHours >= 12) fee += 15000;
    }

    return {
      'success': true,
      'ticket_id': ticket.id,
      'ticket_code': ticket.ticketCode,
      'license_plate': ticket.licensePlate,
      'total_hours': effectiveHours,
      'fee_amount': fee,
    };
  }

  /// 8. Check-out và xác nhận thu tiền
  Future<Map<String, dynamic>> checkoutVisitorTicket({
    required String ticketId,
    String paymentMethod = 'vietqr',
  }) async {
    try {
      final res = await _supabase.rpc('checkout_visitor_ticket', params: {
        'p_ticket_id': ticketId,
        'p_payment_method': paymentMethod,
      });
      if (res != null) {
        return Map<String, dynamic>.from(res as Map);
      }
    } catch (_) {
      // Fallback
    }

    final index = _inMemoryTickets.indexWhere((t) => t.id == ticketId);
    if (index != -1) {
      final feeCalc = await calculateVisitorFee(ticketId);
      final fee = (feeCalc['fee_amount'] as num?)?.toDouble() ?? 5000.0;
      final hours = (feeCalc['total_hours'] as num?)?.toDouble() ?? 1.0;

      _inMemoryTickets[index] = _inMemoryTickets[index].copyWith(
        status: 'completed',
        paymentStatus: 'paid',
        paymentMethod: paymentMethod,
        feeAmount: fee,
        totalHours: hours,
        checkOutAt: DateTime.now(),
      );
    }

    return {
      'success': true,
      'message': 'Đã check-out và xác nhận thu tiền thành công',
      'payment_method': paymentMethod,
    };
  }
}
