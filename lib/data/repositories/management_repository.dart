import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/issue_model.dart';

class ManagementRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<ResidentModel>> fetchResidents() async {
    final response = await _client
        .from('users')
        .select('*, residents_apartments(*, apartments(*))')
        .eq('role', 'resident')
        .order('created_at', ascending: false);

    return (response as List).map((e) => ResidentModel.fromJson(e)).toList();
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
      'subtotal': (item['unit_price'] as num) * (item['quantity'] as num),
    }).toList();
    
    await _client.from('invoice_items').insert(insertItems);
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
}
