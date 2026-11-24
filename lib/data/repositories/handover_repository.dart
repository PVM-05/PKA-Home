import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/guard_helper.dart';
import '../models/apartment_asset_model.dart';
import '../models/apartment_handover_model.dart';
import '../models/handover_item_model.dart';

class HandoverRepository {
  final SupabaseClient? _client;

  HandoverRepository([this._client]);

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
    );
  }

  /// Lấy danh sách biên bản bàn giao của một tòa nhà (cho BQL)
  Future<List<ApartmentHandoverModel>> fetchHandoversByBuilding(
    String buildingId, {
    String? status,
    String? type,
  }) async {
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
    );
  }

  /// Lấy danh sách biên bản của cư dân
  Future<List<ApartmentHandoverModel>> fetchHandoversByResident(String residentId) async {
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
    );
  }

  /// Lấy chi tiết biên bản kèm danh sách items
  Future<ApartmentHandoverModel?> fetchHandoverDetail(String handoverId) async {
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
    );
  }

  /// Tạo mới biên bản bàn giao kèm các hạng mục
  Future<ApartmentHandoverModel> createHandover(
    ApartmentHandoverModel handover,
    List<HandoverItemModel> items,
  ) async {
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
    );
  }

  /// Tạo mới biên bản bàn giao kèm các hạng mục và chữ ký BQL nguyên tử (Atomic)
  Future<ApartmentHandoverModel> createHandoverWithStaffSignature({
    required ApartmentHandoverModel handover,
    required List<HandoverItemModel> items,
    required Uint8List signatureBytes,
    String? notes,
  }) async {
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
    );
  }

  /// Cập nhật một hạng mục kiểm kê (tình trạng, ảnh, chi phí)
  Future<HandoverItemModel> updateHandoverItem(HandoverItemModel item) async {
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
    );
  }

  /// Nhân viên BQL ký tên và gửi biên bản cho Cư dân
  Future<ApartmentHandoverModel> signByStaff(
    String handoverId,
    Uint8List signatureBytes, {
    String? notes,
  }) async {
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
    );
  }

  /// Cư dân ký tên xác nhận hoàn tất biên bản
  Future<ApartmentHandoverModel> signByResident(
    String handoverId,
    Uint8List signatureBytes, {
    String? notes,
  }) async {
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
    );
  }

  /// Cư dân khiếu nại / tranh chấp biên bản
  Future<ApartmentHandoverModel> disputeByResident(
    String handoverId,
    String disputeReason,
  ) async {
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
    );
  }

  /// Tải ảnh hiện trường tài sản hư hỏng lên Storage
  Future<String> uploadHandoverPhoto(
    String handoverId,
    Uint8List photoBytes,
    String fileName,
  ) async {
    return FailClosedGuard.guard(
      operation: 'uploadHandoverPhoto',
      call: () async {
        final path = 'photos/$handoverId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await _supabase.storage.from('handover-docs').uploadBinary(path, photoBytes);
        return path;
      },
    );
  }

  /// Tạo Signed URL tạm thời cho tài liệu/chữ ký trong bucket riêng tư `handover-docs`
  Future<String> getSignedDocumentUrl(
    String? path, {
    int expiresInSeconds = 3600,
  }) async {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    try {
      return await _supabase.storage
          .from('handover-docs')
          .createSignedUrl(path, expiresInSeconds);
    } catch (_) {
      return '';
    }
  }

  /// Trích xuất URL hình ảnh hoặc chữ ký (khuyến nghị dùng [getSignedDocumentUrl] cho bucket private)
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
