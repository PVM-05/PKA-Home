import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/building_equipment_model.dart';
import '../models/equipment_maintenance_task_model.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return EquipmentRepository();
});

class EquipmentRepository {
  final SupabaseClient _client;

  EquipmentRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

  /// Lấy danh sách thiết bị tòa nhà kèm bộ lọc tùy chọn
  Future<List<BuildingEquipmentModel>> getEquipments({
    String? building,
    String? category,
    String? status,
  }) async {
    var query = _client.from('building_equipments').select();

    if (building != null && building != 'Tất cả' && building.isNotEmpty) {
      query = query.eq('building', building);
    }
    if (category != null && category != 'Tất cả' && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (status != null && status != 'Tất cả' && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final res = await query.order('code', ascending: true);
    return (res as List)
        .map((e) => BuildingEquipmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lấy chi tiết 1 thiết bị
  Future<BuildingEquipmentModel> getEquipmentById(String id) async {
    final res = await _client
        .from('building_equipments')
        .select()
        .eq('id', id)
        .single();
    return BuildingEquipmentModel.fromJson(res);
  }

  /// Tạo mới thiết bị
  Future<BuildingEquipmentModel> createEquipment(Map<String, dynamic> data) async {
    final res = await _client
        .from('building_equipments')
        .insert(data)
        .select()
        .single();
    return BuildingEquipmentModel.fromJson(res);
  }

  /// Cập nhật thông tin thiết bị
  Future<BuildingEquipmentModel> updateEquipment(
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client
        .from('building_equipments')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return BuildingEquipmentModel.fromJson(res);
  }

  /// Xóa thiết bị
  Future<void> deleteEquipment(String id) async {
    await _client.from('building_equipments').delete().eq('id', id);
  }

  /// Lấy danh sách phiếu bảo trì
  Future<List<EquipmentMaintenanceTaskModel>> getMaintenanceTasks({
    String? equipmentId,
    String? status,
    String? building,
  }) async {
    var query = _client.from('equipment_maintenance_tasks').select('''
      *,
      building_equipments (
        code,
        name,
        building
      ),
      users:technician_id (
        full_name
      )
    ''');

    if (equipmentId != null && equipmentId.isNotEmpty) {
      query = query.eq('equipment_id', equipmentId);
    }
    if (status != null && status != 'Tất cả' && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final res = await query.order('scheduled_start', ascending: false);
    var list = (res as List)
        .map((e) => EquipmentMaintenanceTaskModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Lọc theo tòa nhà nếu cần
    if (building != null && building != 'Tất cả' && building.isNotEmpty) {
      list = list.where((t) {
        final eqBuilding = (t.equipmentCode != null)
            ? (res.firstWhere((e) => e['id'] == t.id)['building_equipments']?['building'] as String?)
            : null;
        return eqBuilding == building || eqBuilding == 'Toàn khu';
      }).toList();
    }

    return list;
  }

  /// Tạo phiếu bảo trì mới
  Future<EquipmentMaintenanceTaskModel> createMaintenanceTask(
    Map<String, dynamic> data,
  ) async {
    final res = await _client
        .from('equipment_maintenance_tasks')
        .insert(data)
        .select('''
          *,
          building_equipments (
            code,
            name
          ),
          users:technician_id (
            full_name
          )
        ''')
        .single();
    return EquipmentMaintenanceTaskModel.fromJson(res);
  }

  /// Cập nhật trạng thái phiếu bảo trì (Bắt đầu, Hoàn thành, Hủy)
  Future<void> updateMaintenanceTaskStatus(
    String taskId,
    String status, {
    DateTime? actualStart,
    DateTime? actualEnd,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (actualStart != null) {
      updateData['actual_start'] = actualStart.toIso8601String();
    }
    if (actualEnd != null) {
      updateData['actual_end'] = actualEnd.toIso8601String();
    }

    await _client
        .from('equipment_maintenance_tasks')
        .update(updateData)
        .eq('id', taskId);
  }

  /// Lấy danh sách thiết bị đang bảo trì làm gián đoạn dịch vụ của 1 tòa nhà
  Future<List<EquipmentMaintenanceTaskModel>> getActiveServiceInterruptions({
    required String building,
  }) async {
    final res = await _client
        .from('equipment_maintenance_tasks')
        .select('''
          *,
          building_equipments!inner (
            code,
            name,
            building
          )
        ''')
        .eq('status', 'in_progress')
        .eq('affects_service', true);

    final list = (res as List)
        .map((e) => EquipmentMaintenanceTaskModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (building.isEmpty || building == 'Toàn khu') {
      return list;
    }

    return list.where((t) {
      final eqData = res.firstWhere((e) => e['id'] == t.id)['building_equipments'];
      final bld = eqData?['building'] as String? ?? 'Toàn khu';
      return bld == building || bld == 'Toàn khu';
    }).toList();
  }

  /// Lấy danh sách thiết bị sắp đến hạn bảo dưỡng (trong 7 ngày)
  Future<List<BuildingEquipmentModel>> getUpcomingMaintenanceEquipments({
    int daysAhead = 7,
  }) async {
    try {
      final res = await _client.rpc(
        'get_upcoming_maintenance_equipments',
        params: {'p_days_ahead': daysAhead},
      );
      return (res as List)
          .map((e) => BuildingEquipmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback query if RPC isn't deployed on remote
      final threshold = DateTime.now().add(Duration(days: daysAhead)).toIso8601String();
      final res = await _client
          .from('building_equipments')
          .select()
          .lte('next_maintenance_date', threshold)
          .neq('status', 'inactive')
          .order('next_maintenance_date', ascending: true);
      return (res as List)
          .map((e) => BuildingEquipmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }
}
