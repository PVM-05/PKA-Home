import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/role_delegation_model.dart';

class ManagementRepository {
  final SupabaseClient _client = SupabaseConfig.client;

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

  Future<void> createApartment(String code, double area) async {
    await _client.from('apartments').insert({
      'code': code,
      'area': area,
      'is_empty': true,
    });
  }

  Future<void> updateApartment(String id, String code, double area) async {
    await _client.from('apartments').update({
      'code': code,
      'area': area,
    }).eq('id', id);
  }

  Future<void> deleteApartment(String id) async {
    await _client.from('apartments').delete().eq('id', id);
  }

  Future<void> assignResidentToApartment(String userId, String apartmentId) async {
    // 1. Lấy danh sách căn hộ cũ của cư dân trước khi xóa liên kết
    final oldLinks = await _client
        .from('residents_apartments')
        .select('apartment_id')
        .eq('user_id', userId);

    // 2. Xóa liên kết cũ của cư dân
    await _client.from('residents_apartments').delete().eq('user_id', userId);
    
    // 3. Tạo liên kết với căn hộ mới
    await _client.from('residents_apartments').insert({
      'user_id': userId,
      'apartment_id': apartmentId,
      'relation_role': 'owner',
    });
    
    // 4. Đánh dấu căn hộ mới là có người ở
    await _client.from('apartments').update({'is_empty': false}).eq('id', apartmentId);

    // 5. Giải phóng căn hộ cũ nếu không còn ai cư trú
    for (final link in (oldLinks as List)) {
      final oldAptId = link['apartment_id'];
      if (oldAptId == apartmentId) continue;
      final remaining = await _client
          .from('residents_apartments')
          .select('id')
          .eq('apartment_id', oldAptId);
      if ((remaining as List).isEmpty) {
        await _client.from('apartments').update({'is_empty': true}).eq('id', oldAptId);
      }
    }
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
    
    await _client.from('invoice_items').insert(insertItems);
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

  // Issues Management
  Stream<List<Map<String, dynamic>>> watchRawIssues() {
    return _client.from('issue_reports').stream(primaryKey: ['id']);
  }

  Future<List<IssueModel>> fetchIssues() async {
    final response = await _client
        .from('issue_reports')
        .select('*, apartments(*), users!issue_reports_reporter_id_fkey(*), assigned_staff:users!issue_reports_assigned_staff_id_fkey(*), issue_images(image_url)')
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
}

