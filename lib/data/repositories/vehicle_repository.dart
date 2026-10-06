import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/vehicle_model.dart';

class VehicleRepository {
  final SupabaseClient _client;

  VehicleRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

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
        .neq('status', 'rejected');

    return (response as List).length;
  }

  /// Đăng ký phương tiện mới cho căn hộ
  Future<VehicleModel> registerVehicle({
    required String apartmentId,
    required String plateNumber,
    required String vehicleType,
    required String userId,
    String? brandModel,
  }) async {
    final cleanPlate = plateNumber.trim().toUpperCase();

    // 1. Kiểm tra giới hạn 2 xe máy ở tầng repository (chỉ đếm xe active: pending hoặc approved)
    if (vehicleType == 'motorbike') {
      final activeCount = await getActiveMotorbikeCount(apartmentId);
      if (activeCount >= 2) {
        throw Exception('Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.');
      }
    }

    final response = await _client
        .from('vehicles')
        .insert({
          'apartment_id': apartmentId,
          'plate_number': cleanPlate,
          'license_plate': cleanPlate,
          'vehicle_type': vehicleType,
          'brand_model': brandModel?.trim(),
          'registered_by': userId,
          'user_id': userId,
          'status': 'pending',
        })
        .select()
        .single();

    return VehicleModel.fromJson(response);
  }

  /// Hủy đăng ký / Xóa phương tiện
  Future<void> deleteVehicle(String vehicleId) async {
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
    if (reason != null && reason.trim().isNotEmpty) {
      updates['rejection_reason'] = reason.trim();
    }
    await _client.from('vehicles').update(updates).eq('id', vehicleId);
  }

  /// Phê duyệt cấp thẻ gửi xe cho phương tiện
  Future<void> approveVehicle(String vehicleId) async {
    await updateVehicleStatus(vehicleId, 'approved');
  }

  /// Từ chối đăng ký phương tiện kèm lý do
  Future<void> rejectVehicle(String vehicleId, {String? reason}) async {
    await updateVehicleStatus(vehicleId, 'rejected', reason: reason);
  }
}
