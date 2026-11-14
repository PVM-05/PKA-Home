import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/guard_helper.dart';
import '../models/apartment_asset_model.dart';
import '../models/apartment_handover_model.dart';
import '../models/handover_item_model.dart';

class HandoverRepository {
  final SupabaseClient? _client;
  final bool _isMockMode;

  // In-memory cache cho offline fallback mode
  static final List<ApartmentHandoverModel> _mockHandovers = [
    ApartmentHandoverModel(
      id: 'ho-01',
      apartmentId: 'apt-01',
      buildingId: 'bld-01',
      residentId: 'res-01',
      contractId: 'ctr-01',
      handoverType: 'move_out',
      reportCode: 'HO-202611-00001',
      handoverDate: DateTime.now().subtract(const Duration(days: 1)),
      conductedBy: 'staff-01',
      initialElectricityReading: 1540.0,
      initialWaterReading: 85.0,
      depositHeld: 10000000.0,
      totalDeduction: 1200000.0,
      depositRefund: 8800000.0,
      status: 'pending_resident',
      staffSignatureUrl: 'signatures/staff_ho-01.png',
      staffSignedAt: DateTime.now().subtract(const Duration(hours: 4)),
      lookupCode: 'HK-98A1B2C3D4',
      apartmentCode: 'A0110',
      residentName: 'Nguyễn Văn An',
      staffName: 'Trần Kỹ Thuật',
      items: [
        const HandoverItemModel(
          id: 'item-01',
          handoverId: 'ho-01',
          itemName: 'Điều hòa Daikin 1.5HP',
          roomArea: 'bedroom',
          quantity: 1,
          condition: 'good',
        ),
        const HandoverItemModel(
          id: 'item-02',
          handoverId: 'ho-01',
          itemName: 'Mặt bàn trà phòng khách',
          roomArea: 'living_room',
          quantity: 1,
          condition: 'damaged',
          repairCost: 500000.0,
          note: 'Vết trầy sâu 15cm góc bàn',
          photos: ['photos/ho-01/ban_tra.jpg'],
        ),
        const HandoverItemModel(
          id: 'item-03',
          handoverId: 'ho-01',
          itemName: 'Bộ điều khiển cửa cuốn',
          roomArea: 'living_room',
          quantity: 1,
          condition: 'missing',
          repairCost: 700000.0,
          note: 'Cư dân làm mất remote phụ',
        ),
      ],
    ),
  ];

  static final List<ApartmentAssetModel> _mockAssets = [
    const ApartmentAssetModel(
      id: 'asset-01',
      apartmentId: 'apt-01',
      buildingId: 'bld-01',
      roomArea: 'living_room',
      name: 'Khóa cửa thông minh vân tay',
      assetCode: 'LCK-01',
      quantity: 1,
      condition: 'good',
      replacementPrice: 3500000.0,
    ),
    const ApartmentAssetModel(
      id: 'asset-02',
      apartmentId: 'apt-01',
      buildingId: 'bld-01',
      roomArea: 'living_room',
      name: 'Sofa bọc da cao cấp',
      assetCode: 'SFA-01',
      quantity: 1,
      condition: 'good',
      replacementPrice: 6000000.0,
    ),
    const ApartmentAssetModel(
      id: 'asset-03',
      apartmentId: 'apt-01',
      buildingId: 'bld-01',
      roomArea: 'bedroom',
      name: 'Điều hòa Daikin 1.5HP Inverter',
      assetCode: 'AC-01',
      quantity: 1,
      condition: 'good',
      replacementPrice: 9000000.0,
    ),
    const ApartmentAssetModel(
      id: 'asset-04',
      apartmentId: 'apt-01',
      buildingId: 'bld-01',
      roomArea: 'kitchen',
      name: 'Tủ lạnh Panasonic 2 cánh 250L',
      assetCode: 'FRG-01',
      quantity: 1,
      condition: 'good',
      replacementPrice: 7500000.0,
    ),
    const ApartmentAssetModel(
      id: 'asset-05',
      apartmentId: 'apt-01',
      buildingId: 'bld-01',
      roomArea: 'bathroom',
      name: 'Bình nước nóng Ariston 20L',
      assetCode: 'WTR-01',
      quantity: 1,
      condition: 'good',
      replacementPrice: 2800000.0,
    ),
  ];

  HandoverRepository([this._client, this._isMockMode = false]);

  SupabaseClient get _supabase {
    final c = _client;
    if (c != null) return c;
    if (SupabaseConfig.isConfigured) {
      return SupabaseConfig.client;
    }
    throw const AppException('Supabase chưa sẵn sàng');
  }

  /// Lấy danh mục tài sản nội thất gắn với căn hộ
  Future<List<ApartmentAssetModel>> fetchAssetsByApartment(String apartmentId) async {
    if (_isMockMode) {
      return _mockAssets.where((a) => a.apartmentId == apartmentId).toList();
    }
    return FailClosedGuard.guard(
      operation: 'fetchAssetsByApartment',
      call: () async {
        final response = await _supabase
            .from('apartment_assets')
            .select()
            .eq('apartment_id', apartmentId)
            .order('room_area', ascending: true);

        return (response as List)
            .map((json) => ApartmentAssetModel.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      },
      mockFallback: () => _mockAssets.where((a) => a.apartmentId == apartmentId).toList(),
    );
  }

  /// Lấy danh sách biên bản bàn giao của một tòa nhà (cho BQL)
  Future<List<ApartmentHandoverModel>> fetchHandoversByBuilding(
    String buildingId, {
    String? status,
    String? type,
  }) async {
    if (_isMockMode) {
      return _mockHandovers.where((h) {
        if (h.buildingId != buildingId) return false;
        if (status != null && status.isNotEmpty && h.status != status) return false;
        if (type != null && type.isNotEmpty && h.handoverType != type) return false;
        return true;
      }).toList();
    }
    return FailClosedGuard.guard(
      operation: 'fetchHandoversByBuilding',
      call: () async {
        var query = _supabase
            .from('apartment_handovers')
            .select('*, apartments(code), users!resident_id(full_name), staff:users!conducted_by(full_name)')
            .eq('building_id', buildingId);

        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        if (type != null && type.isNotEmpty) {
          query = query.eq('handover_type', type);
        }

        final response = await query.order('created_at', ascending: false);

        return (response as List).map((json) {
          final map = Map<String, dynamic>.from(json as Map);
          if (map['apartments'] is Map) {
            map['apartment_code'] = map['apartments']['code'];
          }
          if (map['users'] is Map) {
            map['resident_name'] = map['users']['full_name'];
          }
          if (map['staff'] is Map) {
            map['staff_name'] = map['staff']['full_name'];
          }
          return ApartmentHandoverModel.fromJson(map);
        }).toList();
      },
      mockFallback: () {
        return _mockHandovers.where((h) {
          if (h.buildingId != buildingId) return false;
          if (status != null && status.isNotEmpty && h.status != status) return false;
          if (type != null && type.isNotEmpty && h.handoverType != type) return false;
          return true;
        }).toList();
      },
    );
  }

  /// Lấy danh sách biên bản của cư dân
  Future<List<ApartmentHandoverModel>> fetchHandoversByResident(String residentId) async {
    if (_isMockMode) {
      return _mockHandovers.where((h) => h.residentId == residentId).toList();
    }
    return FailClosedGuard.guard(
      operation: 'fetchHandoversByResident',
      call: () async {
        final response = await _supabase
            .from('apartment_handovers')
            .select('*, apartments(code), staff:users!conducted_by(full_name)')
            .eq('resident_id', residentId)
            .order('created_at', ascending: false);

        return (response as List).map((json) {
          final map = Map<String, dynamic>.from(json as Map);
          if (map['apartments'] is Map) {
            map['apartment_code'] = map['apartments']['code'];
          }
          if (map['staff'] is Map) {
            map['staff_name'] = map['staff']['full_name'];
          }
          return ApartmentHandoverModel.fromJson(map);
        }).toList();
      },
      mockFallback: () => _mockHandovers.where((h) => h.residentId == residentId).toList(),
    );
  }

  /// Lấy chi tiết biên bản kèm danh sách items
  Future<ApartmentHandoverModel?> fetchHandoverDetail(String handoverId) async {
    if (_isMockMode) {
      final idx = _mockHandovers.indexWhere((h) => h.id == handoverId);
      return idx != -1 ? _mockHandovers[idx] : null;
    }
    return FailClosedGuard.guard(
      operation: 'fetchHandoverDetail',
      call: () async {
        final response = await _supabase
            .from('apartment_handovers')
            .select('*, handover_items(*), apartments(code), users!resident_id(full_name), staff:users!conducted_by(full_name)')
            .eq('id', handoverId)
            .maybeSingle();

        if (response == null) return null;
        final map = Map<String, dynamic>.from(response as Map);
        if (map['apartments'] is Map) {
          map['apartment_code'] = map['apartments']['code'];
        }
        if (map['users'] is Map) {
          map['resident_name'] = map['users']['full_name'];
        }
        if (map['staff'] is Map) {
          map['staff_name'] = map['staff']['full_name'];
        }
        return ApartmentHandoverModel.fromJson(map);
      },
      mockFallback: () {
        final idx = _mockHandovers.indexWhere((h) => h.id == handoverId);
        return idx != -1 ? _mockHandovers[idx] : null;
      },
    );
  }

  /// Tạo mới biên bản bàn giao kèm các hạng mục
  Future<ApartmentHandoverModel> createHandover(
    ApartmentHandoverModel handover,
    List<HandoverItemModel> items,
  ) async {
    if (_isMockMode) {
      final created = handover.copyWith(items: items);
      _mockHandovers.insert(0, created);
      return created;
    }
    return FailClosedGuard.guard(
      operation: 'createHandover',
      call: () async {
        final data = handover.toJson()..remove('items');
        final response = await _supabase.from('apartment_handovers').insert(data).select().single();
        final createdHandover = ApartmentHandoverModel.fromJson(Map<String, dynamic>.from(response as Map));

        if (items.isNotEmpty) {
          final itemsData = items.map((item) {
            final itemMap = item.toJson();
            itemMap['handover_id'] = createdHandover.id;
            return itemMap;
          }).toList();

          final itemsResp = await _supabase.from('handover_items').insert(itemsData).select();
          final createdItems = (itemsResp as List)
              .map((json) => HandoverItemModel.fromJson(Map<String, dynamic>.from(json as Map)))
              .toList();

          return createdHandover.copyWith(items: createdItems);
        }

        return createdHandover;
      },
      mockFallback: () {
        final created = handover.copyWith(items: items);
        _mockHandovers.insert(0, created);
        return created;
      },
    );
  }

  /// Tạo mới biên bản bàn giao kèm các hạng mục và chữ ký BQL nguyên tử (Atomic)
  Future<ApartmentHandoverModel> createHandoverWithStaffSignature({
    required ApartmentHandoverModel handover,
    required List<HandoverItemModel> items,
    required Uint8List signatureBytes,
    String? notes,
  }) async {
    if (_isMockMode) {
      final fileName = 'signatures/${handover.id}_staff.png';
      final signedHandover = handover.copyWith(
        staffSignatureUrl: fileName,
        staffSignedAt: DateTime.now(),
        staffNotes: notes ?? handover.staffNotes,
        status: 'pending_resident',
        items: items,
      );
      _mockHandovers.removeWhere((h) => h.id == handover.id);
      _mockHandovers.insert(0, signedHandover);
      return signedHandover;
    }
    return FailClosedGuard.guard(
      operation: 'createHandoverWithStaffSignature',
      call: () async {
        // 1. Upload chữ ký BQL lên storage
        final fileName = 'signatures/${handover.id}_staff_${DateTime.now().millisecondsSinceEpoch}.png';
        await _supabase.storage.from('handover-docs').uploadBinary(fileName, signatureBytes);

        // 2. Chuẩn bị dữ liệu handover hoàn chỉnh
        final data = handover.toJson()..remove('items');
        data['staff_signature_url'] = fileName;
        data['staff_signed_at'] = DateTime.now().toIso8601String();
        data['status'] = 'pending_resident';
        if (notes != null && notes.isNotEmpty) {
          data['staff_notes'] = notes;
        }

        // 3. Upsert / Insert handover
        final response = await _supabase.from('apartment_handovers').upsert(data).select().single();
        final createdHandover = ApartmentHandoverModel.fromJson(Map<String, dynamic>.from(response as Map));

        // 4. Insert handover items
        if (items.isNotEmpty) {
          final itemsData = items.map((item) {
            final itemMap = item.toJson();
            itemMap['handover_id'] = createdHandover.id;
            return itemMap;
          }).toList();

          final itemsResp = await _supabase.from('handover_items').upsert(itemsData).select();
          final createdItems = (itemsResp as List)
              .map((json) => HandoverItemModel.fromJson(Map<String, dynamic>.from(json as Map)))
              .toList();

          return createdHandover.copyWith(items: createdItems);
        }

        return createdHandover;
      },
      mockFallback: () {
        final fileName = 'signatures/${handover.id}_staff.png';
        final signedHandover = handover.copyWith(
          staffSignatureUrl: fileName,
          staffSignedAt: DateTime.now(),
          staffNotes: notes ?? handover.staffNotes,
          status: 'pending_resident',
          items: items,
        );
        _mockHandovers.removeWhere((h) => h.id == handover.id);
        _mockHandovers.insert(0, signedHandover);
        return signedHandover;
      },
    );
  }

  /// Cập nhật một hạng mục kiểm kê (tình trạng, ảnh, chi phí)
  Future<HandoverItemModel> updateHandoverItem(HandoverItemModel item) async {
    if (_isMockMode) {
      return item;
    }
    return FailClosedGuard.guard(
      operation: 'updateHandoverItem',
      call: () async {
        final response = await _supabase
            .from('handover_items')
            .update(item.toJson())
            .eq('id', item.id)
            .select()
            .single();

        return HandoverItemModel.fromJson(Map<String, dynamic>.from(response as Map));
      },
      mockFallback: () {
        return item;
      },
    );
  }

  /// Nhân viên BQL ký tên và gửi biên bản cho Cư dân
  Future<ApartmentHandoverModel> signByStaff(
    String handoverId,
    Uint8List signatureBytes, {
    String? notes,
  }) async {
    if (_isMockMode) {
      final idx = _mockHandovers.indexWhere((h) => h.id == handoverId);
      if (idx != -1) {
        final updated = _mockHandovers[idx].copyWith(
          staffSignatureUrl: 'signatures/${handoverId}_staff.png',
          staffSignedAt: DateTime.now(),
          status: 'pending_resident',
          staffNotes: notes,
        );
        _mockHandovers[idx] = updated;
        return updated;
      }
      throw const AppException('Không tìm thấy biên bản');
    }
    return FailClosedGuard.guard(
      operation: 'signByStaff',
      call: () async {
        final fileName = 'signatures/${handoverId}_staff_${DateTime.now().millisecondsSinceEpoch}.png';
        await _supabase.storage.from('handover-docs').uploadBinary(fileName, signatureBytes);

        final updateData = <String, dynamic>{
          'staff_signature_url': fileName,
          'staff_signed_at': DateTime.now().toIso8601String(),
          'status': 'pending_resident',
        };
        if (notes != null) {
          updateData['staff_notes'] = notes;
        }

        final response = await _supabase
            .from('apartment_handovers')
            .update(updateData)
            .eq('id', handoverId)
            .select('*, handover_items(*)')
            .single();

        return ApartmentHandoverModel.fromJson(Map<String, dynamic>.from(response as Map));
      },
      mockFallback: () {
        final idx = _mockHandovers.indexWhere((h) => h.id == handoverId);
        if (idx != -1) {
          final updated = _mockHandovers[idx].copyWith(
            staffSignatureUrl: 'signatures/${handoverId}_staff.png',
            staffSignedAt: DateTime.now(),
            status: 'pending_resident',
            staffNotes: notes,
          );
          _mockHandovers[idx] = updated;
          return updated;
        }
        throw const AppException('Không tìm thấy biên bản');
      },
    );
  }

  /// Cư dân ký tên xác nhận hoàn tất biên bản
  Future<ApartmentHandoverModel> signByResident(
    String handoverId,
    Uint8List signatureBytes, {
    String? notes,
  }) async {
    if (_isMockMode) {
      final idx = _mockHandovers.indexWhere((h) => h.id == handoverId);
      if (idx != -1) {
        final updated = _mockHandovers[idx].copyWith(
          residentSignatureUrl: 'signatures/${handoverId}_resident.png',
          residentSignedAt: DateTime.now(),
          status: 'confirmed',
          residentNotes: notes,
        );
        _mockHandovers[idx] = updated;
        return updated;
      }
      throw const AppException('Không tìm thấy biên bản');
    }
    return FailClosedGuard.guard(
      operation: 'signByResident',
      call: () async {
        final fileName = 'signatures/${handoverId}_resident_${DateTime.now().millisecondsSinceEpoch}.png';
        await _supabase.storage.from('handover-docs').uploadBinary(fileName, signatureBytes);

        final updateData = <String, dynamic>{
          'resident_signature_url': fileName,
          'resident_signed_at': DateTime.now().toIso8601String(),
          'status': 'confirmed',
        };
        if (notes != null) {
          updateData['resident_notes'] = notes;
        }

        final response = await _supabase
            .from('apartment_handovers')
            .update(updateData)
            .eq('id', handoverId)
            .select('*, handover_items(*)')
            .single();

        return ApartmentHandoverModel.fromJson(Map<String, dynamic>.from(response as Map));
      },
      mockFallback: () {
        final idx = _mockHandovers.indexWhere((h) => h.id == handoverId);
        if (idx != -1) {
          final updated = _mockHandovers[idx].copyWith(
            residentSignatureUrl: 'signatures/${handoverId}_resident.png',
            residentSignedAt: DateTime.now(),
            status: 'confirmed',
            residentNotes: notes,
          );
          _mockHandovers[idx] = updated;
          return updated;
        }
        throw const AppException('Không tìm thấy biên bản');
      },
    );
  }

  /// Cư dân khiếu nại / tranh chấp biên bản
  Future<ApartmentHandoverModel> disputeByResident(
    String handoverId,
    String disputeReason,
  ) async {
    if (_isMockMode) {
      final idx = _mockHandovers.indexWhere((h) => h.id == handoverId);
      if (idx != -1) {
        final updated = _mockHandovers[idx].copyWith(
          status: 'disputed',
          residentNotes: disputeReason,
        );
        _mockHandovers[idx] = updated;
        return updated;
      }
      throw const AppException('Không tìm thấy biên bản');
    }
    return FailClosedGuard.guard(
      operation: 'disputeByResident',
      call: () async {
        final updateData = {
          'status': 'disputed',
          'resident_notes': disputeReason,
        };

        final response = await _supabase
            .from('apartment_handovers')
            .update(updateData)
            .eq('id', handoverId)
            .select('*, handover_items(*)')
            .single();

        return ApartmentHandoverModel.fromJson(Map<String, dynamic>.from(response as Map));
      },
      mockFallback: () {
        final idx = _mockHandovers.indexWhere((h) => h.id == handoverId);
        if (idx != -1) {
          final updated = _mockHandovers[idx].copyWith(
            status: 'disputed',
            residentNotes: disputeReason,
          );
          _mockHandovers[idx] = updated;
          return updated;
        }
        throw const AppException('Không tìm thấy biên bản');
      },
    );
  }

  /// Tải ảnh hiện trường tài sản hư hỏng lên Storage
  Future<String> uploadHandoverPhoto(
    String handoverId,
    Uint8List photoBytes,
    String fileName,
  ) async {
    if (_isMockMode) {
      return 'photos/$handoverId/mock_$fileName';
    }
    return FailClosedGuard.guard(
      operation: 'uploadHandoverPhoto',
      call: () async {
        final path = 'photos/$handoverId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await _supabase.storage.from('handover-docs').uploadBinary(path, photoBytes);
        return path;
      },
      mockFallback: () {
        return 'photos/$handoverId/mock_$fileName';
      },
    );
  }

  /// Trích xuất URL hình ảnh hoặc chữ ký
  String getDocumentUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    try {
      return _supabase.storage.from('handover-docs').getPublicUrl(path);
    } catch (_) {
      return path;
    }
  }
}
