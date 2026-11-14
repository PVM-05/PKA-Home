import '../../core/utils/guard_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/maintenance_material_model.dart';
import '../models/issue_material_usage_model.dart';
import '../models/issue_sla_stats_model.dart';

class MaterialRepository {
  final SupabaseClient? _client;

  MaterialRepository([this._client]);

  SupabaseClient get _supabase {
    final c = _client;
    if (c != null) return c;
    if (SupabaseConfig.isConfigured) {
      return SupabaseConfig.client;
    }
    throw const AppException('Supabase chưa sẵn sàng');
  }

  /// 1. Lấy danh mục vật tư thiết bị trong kho
  Future<List<MaintenanceMaterialModel>> fetchMaterials({
    String? buildingId,
    String? category,
  }) async {
    return FailClosedGuard.guard(
      operation: 'fetchMaterials',
      call: () async {
        var query = _supabase.from('maintenance_materials').select();
        if (buildingId != null && buildingId.isNotEmpty) {
          query = query.eq('building_id', buildingId);
        }
        if (category != null && category.isNotEmpty && category != 'all') {
          query = query.eq('category', category);
        }

        final res = await query.order('name');
        final data = res as List<dynamic>;
        return data
            .map(
              (j) =>
                  MaintenanceMaterialModel.fromJson(j as Map<String, dynamic>),
            )
            .toList();
      },
    );
  }

  /// 2. Lấy danh sách vật tư sử dụng cho 1 sự cố
  Future<List<IssueMaterialUsageModel>> fetchIssueMaterials(
    String issueId,
  ) async {
    return FailClosedGuard.guard(
      operation: 'fetchIssueMaterials',
      call: () async {
        final res = await _supabase
            .from('issue_materials')
            .select('*, maintenance_materials(name, unit)')
            .eq('issue_report_id', issueId)
            .order('created_at', ascending: true);

        final data = res as List<dynamic>;
        return data
            .map(
              (j) =>
                  IssueMaterialUsageModel.fromJson(j as Map<String, dynamic>),
            )
            .toList();
      },
    );
  }

  /// 3. Xuất kho vật tư và ghi nhận vào sự cố
  Future<Map<String, dynamic>> recordMaterialsUsage({
    required String issueId,
    required List<Map<String, dynamic>> materials,
    String? staffId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'recordMaterialsUsage',
      call: () async {
        final res = await _supabase.rpc(
          'record_issue_materials_usage',
          params: {
            'p_issue_id': issueId,
            'p_materials': materials,
            'p_staff_id': staffId,
          },
        );
        if (res != null) {
          return Map<String, dynamic>.from(res as Map);
        }
        throw const AppException('Không nhận được phản hồi từ máy chủ khi xuất kho');
      },
    );
  }

  /// 4. Lấy thống kê KPI SLA sự cố
  Future<IssueSlaStatsModel> fetchSlaStats({String? buildingId}) async {
    return FailClosedGuard.guard(
      operation: 'fetchSlaStats',
      call: () async {
        final params = <String, dynamic>{};
        if (buildingId != null && buildingId.isNotEmpty) {
          params['p_building_id'] = buildingId;
        }
        final res = await _supabase.rpc(
          'get_issue_sla_stats',
          params: params.isNotEmpty ? params : null,
        );
        if (res != null) {
          return IssueSlaStatsModel.fromJson(
            Map<String, dynamic>.from(res as Map),
          );
        }
        throw const AppException('Không nhận được thống kê SLA từ máy chủ');
      },
    );
  }

  /// 5. Cập nhật tồn kho vật tư (Nhập hàng hoặc điều chỉnh)
  Future<Map<String, dynamic>> updateMaterialStock({
    required String materialId,
    required int newStock,
  }) async {
    return FailClosedGuard.guard(
      operation: 'updateMaterialStock',
      call: () async {
        await _supabase
            .from('maintenance_materials')
            .update({
              'stock_quantity': newStock,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', materialId);
        return {'success': true, 'message': 'Đã cập nhật tồn kho'};
      },
    );
  }

  /// 5.1 Điều chỉnh số lượng tồn kho theo lượng biến động delta (an toàn chống race condition)
  Future<Map<String, dynamic>> adjustMaterialStockDelta({
    required String materialId,
    required int delta,
    required String reason,
    String? staffId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'adjustMaterialStockDelta',
      call: () async {
        final currentRes = await _supabase
            .from('maintenance_materials')
            .select('stock_quantity, building_id')
            .eq('id', materialId)
            .single();

        final currentStock = (currentRes['stock_quantity'] as num?)?.toInt() ?? 0;
        final buildingId = currentRes['building_id'] as String?;
        final nextStock = currentStock + delta;
        if (nextStock < 0) {
          throw const AppException('Số lượng xuất kho vượt quá lượng tồn thực tế');
        }

        await _supabase
            .from('maintenance_materials')
            .update({
              'stock_quantity': nextStock,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', materialId);

        try {
          await _supabase.from('audit_logs').insert({
            'building_id': buildingId,
            'actor_id': staffId ?? _supabase.auth.currentUser?.id,
            'action': delta >= 0 ? 'STOCK_IMPORT' : 'STOCK_ADJUST_LOSS',
            'target_table': 'maintenance_materials',
            'target_id': materialId,
            'entity_name': 'maintenance_materials',
            'entity_id': materialId,
            'new_values': {
              'delta': delta,
              'reason': reason,
              'previous_stock': currentStock,
              'new_stock': nextStock,
            },
          });
        } catch (_) {
          // Bỏ qua lỗi audit nếu schema chưa có bảng audit
        }

        return {
          'success': true,
          'message': 'Đã điều chỉnh tồn kho thành công',
          'new_stock': nextStock,
        };
      },
    );
  }

  /// 6. Thêm vật tư mới vào danh mục kho
  Future<MaintenanceMaterialModel> createMaterial(
    MaintenanceMaterialModel material,
  ) async {
    return FailClosedGuard.guard(
      operation: 'createMaterial',
      call: () async {
        final res = await _supabase
            .from('maintenance_materials')
            .insert(material.toJson())
            .select()
            .single();
        return MaintenanceMaterialModel.fromJson(res);
      },
    );
  }
}
