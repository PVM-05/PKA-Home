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

  /// Lấy tổng số lượng xe máy và ô tô của căn hộ (phục vụ tự động tính phí hóa đơn)
  Future<Map<String, int>> getVehicleCounts(String apartmentId) async {
    final response = await _client
        .from('vehicles')
        .select('vehicle_type')
        .eq('apartment_id', apartmentId);

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

  /// Đăng ký phương tiện mới cho căn hộ
  Future<VehicleModel> registerVehicle({
    required String apartmentId,
    required String plateNumber,
    required String vehicleType,
    required String userId,
  }) async {
    final cleanPlate = plateNumber.trim().toUpperCase();

    // 1. Kiểm tra giới hạn 2 xe máy ở tầng repository trước (Client/Repo check)
    if (vehicleType == 'motorbike') {
      final existingMotorbikes = await _client
          .from('vehicles')
          .select('id')
          .eq('apartment_id', apartmentId)
          .eq('vehicle_type', 'motorbike');

      if ((existingMotorbikes as List).length >= 2) {
        throw Exception('Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.');
      }
    }

    final response = await _client
        .from('vehicles')
        .insert({
          'apartment_id': apartmentId,
          'plate_number': cleanPlate,
          'vehicle_type': vehicleType,
          'registered_by': userId,
        })
        .select()
        .single();

    return VehicleModel.fromJson(response);
  }

  /// Hủy đăng ký / Xóa phương tiện
  Future<void> deleteVehicle(String vehicleId) async {
    await _client.from('vehicles').delete().eq('id', vehicleId);
  }
}
