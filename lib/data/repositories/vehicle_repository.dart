import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/app_logger.dart';
import '../models/vehicle_model.dart';

class VehicleRepository {
  final SupabaseClient _client;

  VehicleRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

  /// Tải ảnh Giấy đăng ký xe (Cà vẹt) lên Supabase Storage bucket vehicle-docs
  Future<String> uploadRegistrationImage(String apartmentId, String userId, File imageFile) async {
    final fileExt = imageFile.path.split('.').last;
    final fileName = '$apartmentId/${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _client.storage.from('vehicle-docs').upload(fileName, imageFile);
    return fileName;
  }

  /// Tạo Signed URL bảo mật có thời hạn cho ảnh Giấy đăng ký xe trong bucket private `vehicle-docs`
  Future<String> getSignedRegistrationImageUrl(
    String? urlOrPath, {
    int expiresInSeconds = 3600,
  }) async {
    if (urlOrPath == null || urlOrPath.trim().isEmpty) return '';
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    try {
      return await _client.storage
          .from('vehicle-docs')
          .createSignedUrl(urlOrPath, expiresInSeconds);
    } catch (_) {
      return '';
    }
  }

  /// Trích xuất hoặc lấy URL ảnh đăng ký xe (tương thích ngược; ưu tiên [getSignedRegistrationImageUrl] cho private bucket)
  String getRegistrationImageUrl(String? urlOrPath) {
    if (urlOrPath == null || urlOrPath.trim().isEmpty) return '';
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    try {
      return _client.storage.from('vehicle-docs').getPublicUrl(urlOrPath);
    } catch (_) {
      return urlOrPath;
    }
  }

  /// Lấy danh sách phương tiện đã đăng ký của căn hộ
  Future<List<VehicleModel>> getVehiclesByApartment(String apartmentId) async {
    final response = await _client
        .from('vehicles')
        .select()
        .eq('apartment_id', apartmentId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => VehicleModel.fromJson(json)).toList();
  }

  /// Lắng nghe thay đổi danh sách xe của căn hộ theo thời gian thực
  Stream<List<VehicleModel>> streamVehiclesByApartment(String apartmentId) {
    return _client
        .from('vehicles')
        .stream(primaryKey: ['id'])
        .eq('apartment_id', apartmentId)
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => VehicleModel.fromJson(json)).toList());
  }

  /// Lấy tổng số lượng xe máy và ô tô ĐÃ PHÊ DUYỆT của căn hộ (phục vụ tự động tính phí hóa đơn)
  Future<Map<String, int>> getVehicleCounts(String apartmentId) async {
    final response = await _client
        .from('vehicles')
        .select('vehicle_type')
        .eq('apartment_id', apartmentId)
        .eq('status', 'approved');

    int motorbikes = 0;
    int cars = 0;

    for (var row in response as List) {
      final type = row['vehicle_type'] as String?;
      if (type == 'motorbike') {
        motorbikes++;
      } else if (type == 'car') {
        cars++;
      }
    }

    return {
      'motorbike': motorbikes,
      'car': cars,
    };
  }

  /// Lấy số lượng xe máy ĐANG HOẠT ĐỘNG (pending hoặc approved) để kiểm tra hạn mức 2 xe máy
  Future<int> getActiveMotorbikeCount(String apartmentId) async {
    final response = await _client
        .from('vehicles')
        .select('id')
        .eq('apartment_id', apartmentId)
        .eq('vehicle_type', 'motorbike')
        .inFilter('status', ['pending', 'approved']);

    return (response as List).length;
  }

  /// Đăng ký phương tiện mới cho căn hộ
  Future<VehicleModel> registerVehicle({
    required String apartmentId,
    required String plateNumber,
    required String vehicleType,
    required String userId,
    String? brandModel,
    String? registrationImageUrl,
  }) async {
    final cleanPlate = plateNumber.trim().toUpperCase();

    // 1. Kiểm tra giới hạn 2 xe máy ở tầng repository (chỉ đếm xe active: pending hoặc approved)
    if (vehicleType == 'motorbike') {
      final activeCount = await getActiveMotorbikeCount(apartmentId);
      if (activeCount >= 2) {
        throw Exception('Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.');
      }
    }

    final data = <String, dynamic>{
      'apartment_id': apartmentId,
      'plate_number': cleanPlate,
      'license_plate': cleanPlate,
      'vehicle_type': vehicleType,
      'brand_model': brandModel?.trim(),
      'registered_by': userId,
      'user_id': userId,
      'status': 'pending',
    };
    if (registrationImageUrl != null && registrationImageUrl.trim().isNotEmpty) {
      data['registration_image_url'] = registrationImageUrl.trim();
    }

    final response = await _client
        .from('vehicles')
        .insert(data)
        .select()
        .single();

    return VehicleModel.fromJson(response);
  }

  /// Hủy đăng ký / Xóa phương tiện
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      final vehicle = await _client
          .from('vehicles')
          .select('parking_slot_id')
          .eq('id', vehicleId)
          .maybeSingle();
      final slotId = vehicle?['parking_slot_id'] as String?;
      if (slotId != null && slotId.isNotEmpty) {
        await _client.from('parking_slots').update({
          'status': 'available',
          'apartment_id': null,
          'license_plate': null,
          'assigned_date': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', slotId);
      }
    } catch (e) {
      AppLogger.w('Không thể giải phóng ô đỗ khi xóa xe $vehicleId: $e');
    }

    await _client.from('vehicles').delete().eq('id', vehicleId);
  }

  /// Lấy toàn bộ danh sách phương tiện (Dành cho Ban Quản Lý)
  Future<List<VehicleModel>> getAllVehicles({String? status}) async {
    var query = _client.from('vehicles').select();
    if (status != null) {
      query = query.eq('status', status);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((json) => VehicleModel.fromJson(json)).toList();
  }

  /// Cập nhật trạng thái phê duyệt phương tiện
  Future<void> updateVehicleStatus(String vehicleId, String status, {String? reason}) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == 'approved') {
      updates['rejection_reason'] = null;
    } else if (reason != null && reason.trim().isNotEmpty) {
      updates['rejection_reason'] = reason.trim();
    }
    await _client.from('vehicles').update(updates).eq('id', vehicleId);
  }

  /// Phê duyệt cấp thẻ gửi xe cho phương tiện, hỗ trợ gán ô đỗ hầm cho ô tô
  Future<void> approveVehicle(
    String vehicleId, {
    String? parkingSlotId,
    String? parkingSlotNumber,
    String? approvedBy,
  }) async {
    final updates = <String, dynamic>{
      'status': 'approved',
      'rejection_reason': null,
      'approved_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (parkingSlotId != null && parkingSlotId.trim().isNotEmpty) {
      updates['parking_slot_id'] = parkingSlotId.trim();
    }
    if (parkingSlotNumber != null && parkingSlotNumber.trim().isNotEmpty) {
      updates['parking_slot_number'] = parkingSlotNumber.trim();
    }
    if (approvedBy != null && approvedBy.trim().isNotEmpty) {
      updates['approved_by'] = approvedBy.trim();
    }

    await _client.from('vehicles').update(updates).eq('id', vehicleId);

    // Nếu gán parking slot, cập nhật parking_slots thành occupied và gán license_plate / apartment_id
    if (parkingSlotId != null && parkingSlotId.trim().isNotEmpty) {
      try {
        final vehicleRes = await _client
            .from('vehicles')
            .select('license_plate, apartment_id')
            .eq('id', vehicleId)
            .maybeSingle();
        final plate = vehicleRes?['license_plate'] as String?;
        final aptId = vehicleRes?['apartment_id'] as String?;

        await _client.from('parking_slots').update({
          'status': 'occupied',
          'license_plate': plate,
          'apartment_id': aptId,
          'assigned_date': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', parkingSlotId);
      } catch (e) {
        AppLogger.w('Không thể cập nhật trạng thái occupied cho parking_slot $parkingSlotId: $e');
      }
    }
  }

  /// Từ chối đăng ký phương tiện kèm lý do, tự động giải phóng ô đỗ nếu đã từng được gán
  Future<void> rejectVehicle(String vehicleId, {String? reason}) async {
    try {
      final vehicle = await _client
          .from('vehicles')
          .select('parking_slot_id')
          .eq('id', vehicleId)
          .maybeSingle();
      final slotId = vehicle?['parking_slot_id'] as String?;
      if (slotId != null && slotId.isNotEmpty) {
        await _client.from('parking_slots').update({
          'status': 'available',
          'apartment_id': null,
          'license_plate': null,
          'assigned_date': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', slotId);
      }
    } catch (e) {
      AppLogger.w('Không thể giải phóng parking_slot khi từ chối xe $vehicleId: $e');
    }

    final updates = <String, dynamic>{
      'status': 'rejected',
      'rejection_reason': (reason != null && reason.trim().isNotEmpty) ? reason.trim() : null,
      'parking_slot_id': null,
      'parking_slot_number': null,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _client.from('vehicles').update(updates).eq('id', vehicleId);
  }

  /// Cư dân chỉnh sửa thông tin phương tiện đang chờ duyệt (pending)
  Future<void> updatePendingVehicle({
    required String vehicleId,
    required String licensePlate,
    required String vehicleType,
    String? brandModel,
  }) async {
    final response = await _client.rpc('update_pending_vehicle', params: {
      'p_vehicle_id': vehicleId,
      'p_license_plate': licensePlate,
      'p_vehicle_type': vehicleType,
      'p_brand_model': brandModel,
    });
    final resMap = response as Map<String, dynamic>;
    if (resMap['success'] != true) {
      throw Exception(resMap['message'] ?? 'Không thể cập nhật phương tiện.');
    }
  }

  /// Cư dân hủy đăng ký phương tiện đang chờ duyệt (pending)
  Future<void> cancelPendingVehicle(String vehicleId) async {
    final response = await _client.rpc('cancel_pending_vehicle', params: {
      'p_vehicle_id': vehicleId,
    });
    final resMap = response as Map<String, dynamic>;
    if (resMap['success'] != true) {
      throw Exception(resMap['message'] ?? 'Không thể hủy phương tiện.');
    }
  }
}

