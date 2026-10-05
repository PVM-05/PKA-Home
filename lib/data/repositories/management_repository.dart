import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/role_delegation_model.dart';
import '../../../data/models/issue_rating_model.dart';

class ManagementRepository {
  final SupabaseClient _client;

  ManagementRepository([SupabaseClient? client]) : _client = client ?? SupabaseConfig.client;

  Future<List<ResidentModel>> fetchResidents({String? role}) async {
    var query = _client
        .from('users')
        .select('*, residents_apartments(*, apartments(*))');
    
    if (role != null) {
      query = query.eq('role', role);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((e) => ResidentModel.fromJson(e)).toList();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _client.from('users').update({
      'role': newRole,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<List<ApartmentModel>> fetchApartments() async {
    final response = await _client
        .from('apartments')
        .select()
        .order('code');

    return (response as List).map((e) => ApartmentModel.fromJson(e)).toList();
  }

  Future<void> createApartment(
    String code,
    double area, {
    String? buildingCode,
    int? floorNumber,
  }) async {
    final building = buildingCode ?? (code.isNotEmpty ? code[0].toUpperCase() : 'A');
    final floor = floorNumber ?? (code.length >= 3 ? int.tryParse(code.substring(1, 3)) ?? 1 : 1);
    await _client.from('apartments').insert({
      'code': code,
      'area': area,
      'building_code': building,
      'floor_number': floor,
      'is_empty': true,
    });
  }

  Future<void> updateApartment(
    String id,
    String code,
    double area, {
    String? buildingCode,
    int? floorNumber,
  }) async {
    final building = buildingCode ?? (code.isNotEmpty ? code[0].toUpperCase() : 'A');
    final floor = floorNumber ?? (code.length >= 3 ? int.tryParse(code.substring(1, 3)) ?? 1 : 1);
    await _client.from('apartments').update({
      'code': code,
      'area': area,
      'building_code': building,
      'floor_number': floor,
    }).eq('id', id);
  }

  Future<void> deleteApartment(String id) async {
    await _client.from('apartments').delete().eq('id', id);
  }

  Future<void> assignResidentToApartment(String userId, String apartmentId, {String relationRole = 'owner'}) async {
    // 1. Thêm hoặc cập nhật liên kết giữa cư dân và căn hộ này (bảo toàn các căn hộ khác của cư dân)
    await _client.from('residents_apartments').upsert({
      'user_id': userId,
      'apartment_id': apartmentId,
      'relation_role': relationRole,
    }, onConflict: 'user_id,apartment_id');
    
    // 2. Đánh dấu căn hộ mới là có người ở
    await _client.from('apartments').update({'is_empty': false}).eq('id', apartmentId);
  }

  Future<void> unlinkResidentFromApartment(String userId, String apartmentId) async {
    // Xóa liên kết
    await _client.from('residents_apartments').delete().eq('user_id', userId).eq('apartment_id', apartmentId);
    
    // Kiểm tra xem căn hộ còn ai ở không, nếu không thì set is_empty = true
    final remaining = await _client.from('residents_apartments').select('id').eq('apartment_id', apartmentId);
    if ((remaining as List).isEmpty) {
      await _client.from('apartments').update({'is_empty': true}).eq('id', apartmentId);
    }
  }

  // Realtime Streams
  Stream<List<Map<String, dynamic>>> watchPendingIssues() {
    return _client
        .from('issue_reports')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending');
  }

  Stream<List<Map<String, dynamic>>> watchUnpaidInvoices() {
    return _client
        .from('invoices')
        .stream(primaryKey: ['id'])
        .eq('status', 'unpaid');
  }

  // Invoices Management
  Future<List<InvoiceModel>> fetchInvoices() async {
    final response = await _client
        .from('invoices')
        .select('*, apartments(*)')
        .order('created_at', ascending: false);
    return (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    await _client.from('invoices').update({'status': status}).eq('id', id);
  }

  Future<void> createInvoice(String apartmentId, String period, DateTime dueDate, List<Map<String, dynamic>> items) async {
    try {
      await _client.rpc('create_invoice_with_items', params: {
        'p_apartment_id': apartmentId,
        'p_period': period,
        'p_due_date': dueDate.toIso8601String().split('T')[0],
        'p_items': items,
      });
    } catch (_) {
      // Fallback nếu RPC chưa được nạp
      final response = await _client.from('invoices').insert({
        'apartment_id': apartmentId,
        'period': period,
        'due_date': dueDate.toIso8601String().split('T')[0],
        'status': 'unpaid'
      }).select('id').single();
      
      final invoiceId = response['id'];
      
      final List<Map<String, dynamic>> insertItems = items.map((item) => {
        'invoice_id': invoiceId,
        'fee_type': item['fee_type'],
        'unit_price': item['unit_price'],
        'quantity': item['quantity'],
      }).toList();
      
      if (insertItems.isNotEmpty) {
        await _client.from('invoice_items').insert(insertItems);
      }
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await _client.from('invoices').delete().eq('id', invoiceId);
  }

  Future<void> updateInvoice({
    required String invoiceId,
    required String period,
    required DateTime dueDate,
    required List<Map<String, dynamic>> items,
    String? apartmentId,
    String? status,
  }) async {
    try {
      final rpcParams = <String, dynamic>{
        'p_invoice_id': invoiceId,
        'p_period': period,
        'p_due_date': dueDate.toIso8601String().split('T')[0],
        'p_items': items,
      };
      if (apartmentId != null) rpcParams['p_apartment_id'] = apartmentId;
      if (status != null) rpcParams['p_status'] = status;
      await _client.rpc('update_invoice_with_items', params: rpcParams);
    } catch (_) {
      // Fallback
      final invoiceData = <String, dynamic>{
        'period': period,
        'due_date': dueDate.toIso8601String().split('T')[0],
      };
      if (apartmentId != null) {
        invoiceData['apartment_id'] = apartmentId;
      }
      if (status != null) {
        invoiceData['status'] = status;
      }
      await _client.from('invoices').update(invoiceData).eq('id', invoiceId);

      await _client.from('invoice_items').delete().eq('invoice_id', invoiceId);

      final List<Map<String, dynamic>> insertItems = items.map((item) => {
        'invoice_id': invoiceId,
        'fee_type': item['fee_type'],
        'unit_price': item['unit_price'],
        'quantity': item['quantity'],
      }).toList();

      if (insertItems.isNotEmpty) {
        await _client.from('invoice_items').insert(insertItems);
      }
    }
  }

  // Issues Management
  Stream<List<Map<String, dynamic>>> watchRawIssues() {
    return _client.from('issue_reports').stream(primaryKey: ['id']);
  }

  Future<List<IssueModel>> fetchIssues() async {
    final response = await _client
        .from('issue_reports')
        .select('*, apartments(*), users!issue_reports_reporter_id_fkey(*), assigned_staff:users!issue_reports_assigned_staff_id_fkey(*), issue_images(image_url, image_role)')
        .order('created_at', ascending: false);
    return (response as List).map((e) => IssueModel.fromJson(e)).toList();
  }

  Future<void> updateIssueStatus(String id, String status, {String? assignedStaffId}) async {
    final data = <String, dynamic>{'status': status};
    if (assignedStaffId != null) {
      data['assigned_staff_id'] = assignedStaffId;
    }
    await _client.from('issue_reports').update(data).eq('id', id);
  }

  /// Kỹ thuật viên hoàn thành sự cố kèm tải ảnh minh chứng nghiệm thu
  Future<void> resolveIssueWithProof({
    required String issueId,
    required String staffId,
    required List<File> proofFiles,
  }) async {
    for (int i = 0; i < proofFiles.length; i++) {
      final file = proofFiles[i];
      final fileExt = file.path.split('.').last;
      final fileName = '$staffId/$issueId/proof_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';

      await _client.storage.from('issue-images').upload(fileName, file);
      final imageUrl = _client.storage.from('issue-images').getPublicUrl(fileName);

      await _client.from('issue_images').insert({
        'issue_report_id': issueId,
        'image_url': imageUrl,
        'image_role': 'resolution_proof',
      });
    }

    await updateIssueStatus(issueId, 'resolved', assignedStaffId: staffId);
  }

  Future<void> deleteIssue(String issueId, {List<String> imageUrls = const []}) async {
    // 1. Xóa bản ghi trong bảng issue_reports (issue_images tự động cascade)
    await _client.from('issue_reports').delete().eq('id', issueId);

    // 2. Xóa các file ảnh đính kèm trong Supabase Storage nếu có
    if (imageUrls.isNotEmpty) {
      try {
        final filePaths = imageUrls.map((url) {
          final uri = Uri.parse(url);
          final segments = uri.pathSegments;
          final bucketIndex = segments.indexOf('issue-images');
          if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
            return segments.sublist(bucketIndex + 1).join('/');
          }
          return segments.last;
        }).toList();

        await _client.storage.from('issue-images').remove(filePaths);
      } catch (_) {
        // Không block tiến trình nếu xóa ảnh storage thất bại
      }
    }
  }

  // ============================================================================
  // ROLE DELEGATIONS (ỦY QUYỀN TẠM THỜI)
  // ============================================================================

  Future<List<RoleDelegationModel>> fetchDelegations() async {
    final response = await _client
        .from('role_delegations')
        .select('*, delegator:delegator_id(full_name), delegate:delegate_id(full_name)')
        .order('created_at', ascending: false);

    return (response as List).map((e) => RoleDelegationModel.fromJson(e)).toList();
  }

  Future<List<RoleDelegationModel>> fetchMyActiveDelegations() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final response = await _client
        .from('role_delegations')
        .select('*, delegator:delegator_id(full_name), delegate:delegate_id(full_name)')
        .eq('delegate_id', currentUserId)
        .lte('starts_at', nowIso)
        .gte('ends_at', nowIso);

    return (response as List).map((e) => RoleDelegationModel.fromJson(e)).toList();
  }

  Future<void> createDelegation({
    required String delegateId,
    required String delegatedRole,
    required DateTime startsAt,
    required DateTime endsAt,
    String? note,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Người dùng chưa đăng nhập');

    await _client.from('role_delegations').insert({
      'delegator_id': currentUserId,
      'delegate_id': delegateId,
      'delegated_role': delegatedRole,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'note': note,
    });
  }

  Future<void> revokeDelegation(String id) async {
    await _client.from('role_delegations').update({
      'ends_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Lấy toàn bộ danh sách đánh giá dịch vụ sự cố cho Ban Quản Lý
  Future<List<IssueRatingModel>> fetchAllRatings() async {
    final response = await _client
        .from('issue_ratings')
        .select('*, users:reporter_id(full_name)')
        .order('created_at', ascending: false);

    return (response as List).map((e) => IssueRatingModel.fromJson(e)).toList();
  }

  /// Khóa hoặc mở khóa tài khoản người dùng
  Future<void> toggleUserLock(String userId, bool isLocked) async {
    await _client.from('users').update({
      'is_locked': isLocked,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Tạo hóa đơn hàng loạt theo tháng cho toàn bộ căn hộ đang có người ở
  Future<Map<String, dynamic>> generateMonthlyBulkInvoices({
    required String period,
    required DateTime dueDate,
    double mgmtRate = 10000,
    double electricRate = 3000,
    double waterRate = 15000,
  }) async {
    final response = await _client.rpc('generate_monthly_bulk_invoices', params: {
      'p_period': period,
      'p_due_date': dueDate.toIso8601String(),
      'p_mgmt_rate': mgmtRate,
      'p_electric_rate': electricRate,
      'p_water_rate': waterRate,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  /// Cập nhật chỉ số điện nước tháng cho căn hộ
  Future<void> updateApartmentReadings({
    required String apartmentId,
    required double electricReading,
    required double waterReading,
  }) async {
    await _client.from('apartments').update({
      'electric_reading': electricReading,
      'water_reading': waterReading,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', apartmentId);
  }
}

