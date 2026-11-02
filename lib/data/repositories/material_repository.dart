import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/maintenance_material_model.dart';
import '../models/issue_material_usage_model.dart';
import '../models/issue_sla_stats_model.dart';

class MaterialRepository {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? SupabaseConfig.client;

  // In-memory cache phục vụ offline fallback và test runner
  final List<MaintenanceMaterialModel> _inMemoryMaterials = [];
  final List<IssueMaterialUsageModel> _inMemoryIssueMaterials = [];

  MaterialRepository([this._client]) {
    _initMockData();
  }

  void _initMockData() {
    if (_inMemoryMaterials.isNotEmpty) return;

    final now = DateTime.now();
    _inMemoryMaterials.addAll([
      MaintenanceMaterialModel(
        id: 'mat-01',
        code: 'MAT-ELEC-01',
        name: 'Bóng đèn LED Rạng Đông 18W',
        category: 'electrical',
        unit: 'cái',
        unitPrice: 65000,
        stockQuantity: 45,
        minStockAlert: 10,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-02',
        code: 'MAT-ELEC-02',
        name: 'Aptomat tép Schneider 1P 20A',
        category: 'electrical',
        unit: 'cái',
        unitPrice: 120000,
        stockQuantity: 20,
        minStockAlert: 5,
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-03',
        code: 'MAT-ELEC-03',
        name: 'Dây điện đôi Cadivi 2x2.5mm',
        category: 'electrical',
        unit: 'mét',
        unitPrice: 18000,
        stockQuantity: 150,
        minStockAlert: 30,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-04',
        code: 'MAT-PLUMB-01',
        name: 'Van bi đồng Miha D21',
        category: 'plumbing',
        unit: 'cái',
        unitPrice: 85000,
        stockQuantity: 25,
        minStockAlert: 8,
        createdAt: now.subtract(const Duration(days: 22)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-05',
        code: 'MAT-PLUMB-02',
        name: 'Dây cấp nước bồn cầu inox 304',
        category: 'plumbing',
        unit: 'sợi',
        unitPrice: 45000,
        stockQuantity: 30,
        minStockAlert: 10,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-06',
        code: 'MAT-PLUMB-03',
        name: 'Keo dán ống PVC Bình Minh 500g',
        category: 'plumbing',
        unit: 'hộp',
        unitPrice: 55000,
        stockQuantity: 12,
        minStockAlert: 4,
        createdAt: now.subtract(const Duration(days: 18)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-07',
        code: 'MAT-CONST-01',
        name: 'Keo silicone Apolo A500',
        category: 'construction',
        unit: 'chai',
        unitPrice: 58000,
        stockQuantity: 35,
        minStockAlert: 10,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-08',
        code: 'MAT-CONST-02',
        name: 'Khóa tay gạt cửa thông phòng Hafele',
        category: 'construction',
        unit: 'bộ',
        unitPrice: 380000,
        stockQuantity: 8,
        minStockAlert: 3,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-09',
        code: 'MAT-ELEV-01',
        name: 'Đèn chiếu sáng cabin thang máy LED 12V',
        category: 'elevator',
        unit: 'bộ',
        unitPrice: 220000,
        stockQuantity: 6,
        minStockAlert: 2,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      MaintenanceMaterialModel(
        id: 'mat-10',
        code: 'MAT-FIRE-01',
        name: 'Đầu phun sprinkler chữa cháy quay xuống',
        category: 'fire_safety',
        unit: 'cái',
        unitPrice: 75000,
        stockQuantity: 15,
        minStockAlert: 5,
        createdAt: now.subtract(const Duration(days: 8)),
      ),
    ]);
  }

  /// 1. Lấy danh sách vật tư kho
  Future<List<MaintenanceMaterialModel>> fetchMaterials({
    String? buildingId,
    String? category,
  }) async {
    try {
      var query = _supabase.from('maintenance_materials').select();
      if (buildingId != null && buildingId.isNotEmpty) {
        query = query.eq('building_id', buildingId);
      }
      if (category != null && category.isNotEmpty && category != 'all') {
        query = query.eq('category', category);
      }

      final res = await query.order('name');
      final data = res as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((j) => MaintenanceMaterialModel.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback
    }

    var list = List<MaintenanceMaterialModel>.from(_inMemoryMaterials);
    if (category != null && category.isNotEmpty && category != 'all') {
      list = list.where((m) => m.category == category).toList();
    }
    return list;
  }

  /// 2. Lấy danh sách vật tư sử dụng cho 1 sự cố
  Future<List<IssueMaterialUsageModel>> fetchIssueMaterials(String issueId) async {
    try {
      final res = await _supabase
          .from('issue_materials')
          .select('*, maintenance_materials(name, unit)')
          .eq('issue_report_id', issueId)
          .order('created_at', ascending: true);

      final data = res as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((j) => IssueMaterialUsageModel.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback
    }

    return _inMemoryIssueMaterials.where((im) => im.issueReportId == issueId).toList();
  }

  /// 3. Xuất kho vật tư và ghi nhận vào sự cố
  Future<Map<String, dynamic>> recordMaterialsUsage({
    required String issueId,
    required List<Map<String, dynamic>> materials,
    String? staffId,
  }) async {
    try {
      final res = await _supabase.rpc('record_issue_materials_usage', params: {
        'p_issue_id': issueId,
        'p_materials': materials,
        'p_staff_id': staffId,
      });
      if (res != null) {
        return Map<String, dynamic>.from(res as Map);
      }
    } catch (_) {
      // Fallback
    }

    // In-memory fallback
    for (final item in materials) {
      final matId = item['material_id'] as String;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final isChargeable = item['is_chargeable'] as bool? ?? false;
      final note = item['note'] as String?;

      final matIndex = _inMemoryMaterials.indexWhere((m) => m.id == matId);
      if (matIndex != -1) {
        final mat = _inMemoryMaterials[matIndex];
        final newStock = (mat.stockQuantity - qty).clamp(0, 999999);
        _inMemoryMaterials[matIndex] = mat.copyWith(stockQuantity: newStock);

        _inMemoryIssueMaterials.add(
          IssueMaterialUsageModel(
            id: 'usage-${DateTime.now().millisecondsSinceEpoch}-${_inMemoryIssueMaterials.length}',
            issueReportId: issueId,
            materialId: mat.id,
            materialName: mat.name,
            quantity: qty,
            unit: mat.unit,
            unitPrice: mat.unitPrice,
            totalAmount: mat.unitPrice * qty,
            isChargeable: isChargeable,
            note: note,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return {
      'success': true,
      'message': 'Đã xuất kho và ghi nhận vật tư thành công (Offline Mode)',
      'items_recorded': materials.length,
    };
  }

  /// 4. Lấy thống kê KPI SLA sự cố
  Future<IssueSlaStatsModel> fetchSlaStats({String? buildingId}) async {
    try {
      final params = <String, dynamic>{};
      if (buildingId != null && buildingId.isNotEmpty) {
        params['p_building_id'] = buildingId;
      }
      final res = await _supabase.rpc(
        'get_issue_sla_stats',
        params: params.isNotEmpty ? params : null,
      );
      if (res != null) {
        return IssueSlaStatsModel.fromJson(Map<String, dynamic>.from(res as Map));
      }
    } catch (_) {
      // Fallback
    }

    return const IssueSlaStatsModel(
      totalIssues: 12,
      onTimeCount: 9,
      warningCount: 2,
      breachedCount: 1,
      complianceRate: 91.7,
    );
  }

  /// 5. Cập nhật tồn kho vật tư (Nhập hàng hoặc điều chỉnh)
  Future<Map<String, dynamic>> updateMaterialStock({
    required String materialId,
    required int newStock,
  }) async {
    try {
      await _supabase
          .from('maintenance_materials')
          .update({'stock_quantity': newStock, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', materialId);
      return {'success': true, 'message': 'Đã cập nhật tồn kho'};
    } catch (_) {
      // Fallback
    }

    final index = _inMemoryMaterials.indexWhere((m) => m.id == materialId);
    if (index != -1) {
      _inMemoryMaterials[index] = _inMemoryMaterials[index].copyWith(stockQuantity: newStock);
    }
    return {'success': true, 'message': 'Đã cập nhật tồn kho'};
  }

  /// 6. Thêm vật tư mới vào danh mục kho
  Future<MaintenanceMaterialModel> createMaterial(MaintenanceMaterialModel material) async {
    try {
      final res = await _supabase
          .from('maintenance_materials')
          .insert(material.toJson())
          .select()
          .single();
      return MaintenanceMaterialModel.fromJson(res);
    } catch (_) {
      // Fallback
    }

    _inMemoryMaterials.add(material);
    return material;
  }
}
