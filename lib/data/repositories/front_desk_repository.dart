import '../../core/utils/guard_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/visitor_pass_model.dart';
import '../models/parcel_model.dart';
import '../models/front_desk_stats_model.dart';

class FrontDeskRepository {
  final SupabaseClient? _client;

  FrontDeskRepository([this._client]);

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      if (SupabaseConfig.isConfigured) {
        return SupabaseConfig.client;
      }
    } catch (_) {}
    return null;
  }

  // ─── 1. VISITOR PASSES APIS ───
  Future<List<VisitorPassModel>> fetchVisitorPasses({
    String? apartmentId,
    String? status,
  }) async {
    return FailClosedGuard.guard(
      operation: 'fetchVisitorPasses',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        var query = client
            .from('visitor_access_passes')
            .select('*, apartments(code, building_code)');
        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        if (apartmentId != null && apartmentId.isNotEmpty) {
          query = query.eq('apartment_id', apartmentId);
        }
        final res = await query.order('expected_arrival', ascending: false);
        return (res as List)
            .map((j) => VisitorPassModel.fromJson(j as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<VisitorPassModel> createVisitorPass({
    required String apartmentId,
    required String hostUserId,
    required String visitorName,
    String? visitorPhone,
    String? licensePlate,
    String vehicleType = 'none',
    int visitorCount = 1,
    required DateTime expectedArrival,
    DateTime? expectedDeparture,
    String purpose = 'visit',
    String? note,
  }) async {
    return FailClosedGuard.guard(
      operation: 'createVisitorPass',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final payload = {
          'apartment_id': apartmentId,
          'host_user_id': hostUserId,
          'visitor_name': visitorName,
          'visitor_phone': visitorPhone,
          'license_plate': licensePlate,
          'vehicle_type': vehicleType,
          'visitor_count': visitorCount,
          'expected_arrival': expectedArrival.toIso8601String(),
          'expected_departure': expectedDeparture?.toIso8601String(),
          'purpose': purpose,
          'note': note,
        };
        final res = await client
            .from('visitor_access_passes')
            .insert(payload)
            .select('*, apartments(code, building_code)')
            .single();
        return VisitorPassModel.fromJson(res);
      },
    );
  }

  Future<Map<String, dynamic>> checkInVisitor({
    required String passCode,
    String? guardId,
    String? qrPayload,
  }) async {
    return FailClosedGuard.guard(
      operation: 'checkInVisitor',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final params = <String, dynamic>{
          'p_pass_code': passCode,
        };
        if (guardId != null && guardId.isNotEmpty) {
          params['p_guard_id'] = guardId;
        }
        if (qrPayload != null && qrPayload.isNotEmpty) {
          params['p_qr_payload'] = qrPayload;
        }
        final res = await client.rpc(
          'check_in_visitor_pass',
          params: params,
        );
        return Map<String, dynamic>.from(res as Map);
      },
    );
  }

  Future<Map<String, dynamic>> checkOutVisitor({
    required String passCode,
    String? guardId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'checkOutVisitor',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final params = <String, dynamic>{
          'p_pass_code': passCode,
        };
        if (guardId != null && guardId.isNotEmpty) {
          params['p_guard_id'] = guardId;
        }
        final res = await client.rpc(
          'check_out_visitor_pass',
          params: params,
        );
        return Map<String, dynamic>.from(res as Map);
      },
    );
  }

  // ─── 2. PARCEL HUB APIS ───
  Future<List<ParcelModel>> fetchParcels({
    String? status,
    String? apartmentId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'fetchParcels',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        var query = client
            .from('parcels')
            .select('*, apartments(code, building_code)');
        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        if (apartmentId != null && apartmentId.isNotEmpty) {
          query = query.eq('apartment_id', apartmentId);
        }
        final res = await query.order('arrived_at', ascending: false);
        return (res as List)
            .map((j) => ParcelModel.fromJson(j as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ParcelModel> receiveParcel({
    required String apartmentId,
    String? recipientName,
    String carrier = 'SPX',
    String? trackingNumber,
    String? description,
    String shelfLocation = 'Kệ chung',
    String? imageUrl,
    required String staffId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'receiveParcel',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final payload = {
          'apartment_id': apartmentId,
          'recipient_name': recipientName,
          'carrier': carrier,
          'tracking_number': trackingNumber,
          'description': description,
          'shelf_location': shelfLocation,
          'image_url': imageUrl,
          'received_staff_id': staffId,
        };
        final res = await client
            .from('parcels')
            .insert(payload)
            .select('*, apartments(code, building_code)')
            .single();
        return ParcelModel.fromJson(res);
      },
    );
  }

  Future<Map<String, dynamic>> collectParcel({
    required String parcelId,
    required String pickupPin,
    String? staffId,
    String collectedBy = 'Cư dân',
  }) async {
    return FailClosedGuard.guard(
      operation: 'collectParcel',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final params = <String, dynamic>{
          'p_parcel_id': parcelId,
          'p_pickup_pin': pickupPin,
          'p_collected_by': collectedBy,
        };
        if (staffId != null && staffId.isNotEmpty) {
          params['p_staff_id'] = staffId;
        }
        final res = await client.rpc(
          'collect_parcel',
          params: params,
        );
        return Map<String, dynamic>.from(res as Map);
      },
    );
  }

  // ─── 3. FRONT DESK STATS API ───
  Future<FrontDeskStatsModel> fetchFrontDeskStats({String? buildingId}) async {
    return FailClosedGuard.guard(
      operation: 'fetchFrontDeskStats',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final params = <String, dynamic>{};
        if (buildingId != null) {
          params['p_building_id'] = buildingId;
        }
        final res = await client.rpc('get_front_desk_stats', params: params);
        return FrontDeskStatsModel.fromJson(
          Map<String, dynamic>.from(res as Map),
        );
      },
    );
  }
}
