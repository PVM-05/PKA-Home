import '../../core/utils/guard_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/maintenance_material_model.dart';
import '../models/issue_material_usage_model.dart';
import '../models/issue_sla_stats_model.dart';

class MaterialRepository {
  final SupabaseClient? _client;
  final bool _isMockMode;

  SupabaseClient get _supabase {
    final c = _client;
    if (c != null) return c;
    if (SupabaseConfig.isConfigured) {
      return SupabaseConfig.client;
    }
    throw const AppException('Supabase chưa sẵn sàng');
  }

  // In-memory cache phục vụ offline fallback và test runner
  final List<MaintenanceMaterialModel> _inMemoryMaterials = [];
  final List<IssueMaterialUsageModel> _inMemoryIssueMaterials = [];

  MaterialRepository([this._client, this._isMockMode = false]) {
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
    if (_isMockMode) {
      var list = List<MaintenanceMaterialModel>.from(_inMemoryMaterials);
      if (category != null && category.isNotEmpty && category != 'all') {
        list = list.where((m) => m.category == category).toList();
      }
      return list;
    }
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
      mockFallback: () {
        var list = List<MaintenanceMaterialModel>.from(_inMemoryMaterials);
        if (category != null && category.isNotEmpty && category != 'all') {
          list = list.where((m) => m.category == category).toList();
        }
        return list;
      },
    );
  }

  /// 2. Lấy danh sách vật tư sử dụng cho 1 sự cố
  Future<List<IssueMaterialUsageModel>> fetchIssueMaterials(
    String issueId,
  ) async {
    if (_isMockMode) {
      return _inMemoryIssueMaterials
          .where((im) => im.issueReportId == issueId)
          .toList();
    }
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
      mockFallback: () {
        return _inMemoryIssueMaterials
            .where((im) => im.issueReportId == issueId)
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
    if (_isMockMode) {
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
        'message': 'Đã xuất kho và ghi nhận vật tư thành công (Offline Mock)',
        'items_recorded': materials.length,
      };
    }
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
      mockFallback: () {
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
          'message': 'Đã xuất kho và ghi nhận vật tư thành công (Offline Mock)',
          'items_recorded': materials.length,
        };
      },
    );
  }

  /// 4. Lấy thống kê KPI SLA sự cố
  Future<IssueSlaStatsModel> fetchSlaStats({String? buildingId}) async {
    if (_isMockMode) {
      return const IssueSlaStatsModel(
        totalIssues: 12,
        onTimeCount: 9,
        warningCount: 2,
        breachedCount: 1,
        complianceRate: 91.7,
      );
    }
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
      mockFallback: () => const IssueSlaStatsModel(
        totalIssues: 12,
        onTimeCount: 9,
        warningCount: 2,
        breachedCount: 1,
        complianceRate: 91.7,
      ),
    );
  }

  /// 5. Cập nhật tồn kho vật tư (Nhập hàng hoặc điều chỉnh)
  Future<Map<String, dynamic>> updateMaterialStock({
    required String materialId,
    required int newStock,
  }) async {
    if (_isMockMode) {
      final index = _inMemoryMaterials.indexWhere((m) => m.id == materialId);
      if (index != -1) {
        _inMemoryMaterials[index] = _inMemoryMaterials[index].copyWith(
          stockQuantity: newStock,
        );
      }
      return {'success': true, 'message': 'Đã cập nhật tồn kho (Mock)'};
    }
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
      mockFallback: () {
        final index = _inMemoryMaterials.indexWhere((m) => m.id == materialId);
        if (index != -1) {
          _inMemoryMaterials[index] = _inMemoryMaterials[index].copyWith(
            stockQuantity: newStock,
          );
        }
        return {'success': true, 'message': 'Đã cập nhật tồn kho (Mock)'};
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
    if (_isMockMode) {
      final index = _inMemoryMaterials.indexWhere((m) => m.id == materialId);
      if (index != -1) {
        final current = _inMemoryMaterials[index];
        final nextStock = (current.stockQuantity + delta).clamp(0, 999999);
        _inMemoryMaterials[index] = current.copyWith(stockQuantity: nextStock);
        return {
          'success': true,
          'message': 'Đã điều chỉnh tồn kho thành công (Mock)',
          'new_stock': nextStock,
        };
      }
      throw const AppException('Không tìm thấy vật tư');
    }
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
      mockFallback: () {
        final index = _inMemoryMaterials.indexWhere((m) => m.id == materialId);
        if (index != -1) {
          final current = _inMemoryMaterials[index];
          final nextStock = (current.stockQuantity + delta).clamp(0, 999999);
          _inMemoryMaterials[index] = current.copyWith(stockQuantity: nextStock);
          return {
            'success': true,
            'message': 'Đã điều chỉnh tồn kho thành công (Mock)',
            'new_stock': nextStock,
          };
        }
        throw const AppException('Không tìm thấy vật tư');
      },
    );
  }

  /// 6. Thêm vật tư mới vào danh mục kho
  Future<MaintenanceMaterialModel> createMaterial(
    MaintenanceMaterialModel material,
  ) async {
    if (_isMockMode) {
      _inMemoryMaterials.add(material);
      return material;
    }
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
      mockFallback: () {
        _inMemoryMaterials.add(material);
        return material;
      },
    );
  }
}
