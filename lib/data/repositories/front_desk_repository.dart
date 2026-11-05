import '../../core/utils/guard_helper.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/security/visitor_pass_token_service.dart';
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

  // ─── OFFLINE FALLBACK ENGINE ───
  static final List<VisitorPassModel> _mockPasses = [
    VisitorPassModel(
      id: 'vp-mock-01',
      passCode: 'VP-202611-00001',
      apartmentId: 'apt-01',
      apartmentCode: 'A0110',
      hostUserId: 'usr-01',
      visitorName: 'Nguyễn Văn Nam',
      visitorPhone: '0912345678',
      licensePlate: '30A-888.99',
      vehicleType: 'car',
      visitorCount: 2,
      expectedArrival: DateTime.now().add(const Duration(hours: 1)),
      expectedDeparture: DateTime.now().add(const Duration(hours: 4)),
      purpose: 'visit',
      qrPayload: 'PKAPASS:VP-202611-00001:abcd1111',
      status: 'pending',
      note: 'Bạn thân đến thăm nhà',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    VisitorPassModel(
      id: 'vp-mock-02',
      passCode: 'VP-202611-00002',
      apartmentId: 'apt-02',
      apartmentCode: 'A0205',
      hostUserId: 'usr-02',
      visitorName: 'Trần Minh Tuấn (Thợ mộc)',
      visitorPhone: '0909123456',
      vehicleType: 'motorcycle',
      licensePlate: '29V1-456.78',
      visitorCount: 1,
      expectedArrival: DateTime.now().subtract(const Duration(hours: 1)),
      purpose: 'repair',
      qrPayload: 'PKAPASS:VP-202611-00002:abcd2222',
      status: 'checked_in',
      checkInAt: DateTime.now().subtract(const Duration(minutes: 50)),
      checkInGuardId: 'usr-guard-01',
      note: 'Bảo hành tủ bếp chung cư',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  static final List<ParcelModel> _mockParcels = [
    ParcelModel(
      id: 'pcl-mock-01',
      parcelCode: 'PCL-202611-00001',
      apartmentId: 'apt-01',
      apartmentCode: 'A0110',
      recipientName: 'Chị Mai',
      carrier: 'SPX',
      trackingNumber: 'SPXVN88990011',
      description: 'Hộp giày thể thao',
      shelfLocation: 'Kệ A1',
      pickupPin: '582914',
      status: 'arrived',
      arrivedAt: DateTime.now().subtract(const Duration(hours: 5)),
      receivedStaffId: 'usr-staff-01',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    ParcelModel(
      id: 'pcl-mock-02',
      parcelCode: 'PCL-202611-00002',
      apartmentId: 'apt-02',
      apartmentCode: 'A0205',
      recipientName: 'Anh Bình',
      carrier: 'GHTK',
      trackingNumber: 'GHTK22334455',
      description: 'Thùng hoa quả sấy',
      shelfLocation: 'Kệ B2',
      pickupPin: '123456',
      status: 'arrived',
      arrivedAt: DateTime.now().subtract(
        const Duration(days: 4),
      ), // Tồn lâu ngày
      receivedStaffId: 'usr-staff-01',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  // ─── 1. VISITOR PASSES APIS ───
  Future<List<VisitorPassModel>> fetchVisitorPasses({
    String? status,
    String? apartmentId,
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
      mockFallback: () {
        var result = List<VisitorPassModel>.from(_mockPasses);
        if (status != null && status.isNotEmpty) {
          result = result.where((p) => p.status == status).toList();
        }
        if (apartmentId != null && apartmentId.isNotEmpty) {
          result = result.where((p) => p.apartmentId == apartmentId).toList();
        }
        return result;
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
      mockFallback: () {
        final id = 'vp-${DateTime.now().millisecondsSinceEpoch}';
        final code =
            'VP-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${(_mockPasses.length + 1).toString().padLeft(5, '0')}';
        final effectiveDeparture = expectedDeparture ?? expectedArrival.add(const Duration(hours: 24));
        final signedQr = VisitorPassTokenService.generateSignedQrPayload(
          passCode: code,
          issuedAt: DateTime.now(),
          expiresAt: effectiveDeparture,
        );
        final pass = VisitorPassModel(
          id: id,
          passCode: code,
          apartmentId: apartmentId,
          apartmentCode: 'A0110',
          hostUserId: hostUserId,
          visitorName: visitorName,
          visitorPhone: visitorPhone,
          licensePlate: licensePlate,
          vehicleType: vehicleType,
          visitorCount: visitorCount,
          expectedArrival: expectedArrival,
          expectedDeparture: expectedDeparture,
          purpose: purpose,
          qrPayload: signedQr,
          status: 'pending',
          note: note,
          createdAt: DateTime.now(),
        );
        _mockPasses.insert(0, pass);
        return pass;
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
      mockFallback: () {
        final idx = _mockPasses.indexWhere(
          (p) => p.passCode.toUpperCase() == passCode.trim().toUpperCase(),
        );
        if (idx == -1) {
          return {
            'success': false,
            'message': 'Không tìm thấy vé khách với mã đã quét.',
          };
        }
        final target = _mockPasses[idx];
        if (target.status == 'checked_in') {
          return {
            'success': false,
            'message':
                'Cảnh báo bảo mật: Vé khách này đã được check-in vào tòa nhà trước đó (Chống quét lặp lại).',
          };
        }

        final updated = target.copyWith(
          status: 'checked_in',
          checkInAt: DateTime.now(),
          checkInGuardId: guardId,
        );
        _mockPasses[idx] = updated;

        return {
          'success': true,
          'message': 'Check-in thành công. Chào mừng khách viếng thăm!',
          'pass_code': target.passCode,
          'visitor_name': target.visitorName,
        };
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
      mockFallback: () {
        final idx = _mockPasses.indexWhere(
          (p) => p.passCode.toUpperCase() == passCode.trim().toUpperCase(),
        );
        if (idx == -1) {
          return {
            'success': false,
            'message': 'Không tìm thấy vé khách với mã đã quét.',
          };
        }
        final target = _mockPasses[idx];
        if (target.status == 'checked_out') {
          return {
            'success': false,
            'message': 'Khách này đã check-out rời tòa nhà rồi.',
          };
        }

        final updated = target.copyWith(
          status: 'checked_out',
          checkOutAt: DateTime.now(),
          checkOutGuardId: guardId,
        );
        _mockPasses[idx] = updated;

        return {
          'success': true,
          'message': 'Check-out hoàn tất. Khách đã rời khỏi tòa nhà.',
          'pass_code': target.passCode,
          'visitor_name': target.visitorName,
        };
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
      mockFallback: () {
        var result = List<ParcelModel>.from(_mockParcels);
        if (status != null && status.isNotEmpty) {
          result = result.where((p) => p.status == status).toList();
        }
        if (apartmentId != null && apartmentId.isNotEmpty) {
          result = result.where((p) => p.apartmentId == apartmentId).toList();
        }
        return result;
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
      mockFallback: () {
        final id = 'pcl-${DateTime.now().millisecondsSinceEpoch}';
        final code =
            'PCL-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${(_mockParcels.length + 1).toString().padLeft(5, '0')}';
        final pin = (100000 + Random().nextInt(900000)).toString();

        final parcel = ParcelModel(
          id: id,
          parcelCode: code,
          apartmentId: apartmentId,
          apartmentCode: 'A0110',
          recipientName: recipientName,
          carrier: carrier,
          trackingNumber: trackingNumber,
          description: description,
          shelfLocation: shelfLocation,
          imageUrl: imageUrl,
          pickupPin: pin,
          status: 'arrived',
          arrivedAt: DateTime.now(),
          receivedStaffId: staffId,
          createdAt: DateTime.now(),
        );
        _mockParcels.insert(0, parcel);
        return parcel;
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
      mockFallback: () {
        final idx = _mockParcels.indexWhere((p) => p.id == parcelId);
        if (idx == -1) {
          return {
            'success': false,
            'message': 'Không tìm thấy kiện hàng yêu cầu.',
          };
        }
        final target = _mockParcels[idx];
        if (target.status == 'collected') {
          return {
            'success': false,
            'message': 'Kiện hàng này đã được bàn giao trước đó.',
          };
        }

        if (pickupPin.trim() != target.pickupPin) {
          return {
            'success': false,
            'message': 'Mã PIN lấy hàng không chính xác!',
          };
        }

        final updated = target.copyWith(
          status: 'collected',
          collectedAt: DateTime.now(),
          handoverStaffId: staffId,
          collectedBy: collectedBy,
        );
        _mockParcels[idx] = updated;

        return {
          'success': true,
          'message': 'Bàn giao bưu kiện cho cư dân thành công.',
          'parcel_code': target.parcelCode,
          'tracking_number': target.trackingNumber,
        };
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
      mockFallback: () {
        final pendingPcls = _mockParcels
            .where((p) => p.status == 'arrived')
            .length;
        final overduePcls = _mockParcels
            .where((p) => p.isOverdueStorage)
            .length;
        final expectedVsts = _mockPasses
            .where((p) => p.status != 'cancelled')
            .length;
        final inVsts = _mockPasses
            .where((p) => p.status == 'checked_in')
            .length;

        return FrontDeskStatsModel(
          expectedVisitorsToday: expectedVsts,
          visitorsInBuilding: inVsts,
          pendingParcels: pendingPcls,
          overdueParcels: overduePcls,
        );
      },
    );
  }
}
