import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/apartment_model.dart';
import '../models/resident_model.dart';
import '../models/invoice_model.dart';
import '../models/issue_model.dart';

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

  Future<void> assignResidentToApartment(String userId, String apartmentId) async {
    // Upsert or insert into residents_apartments
    // Check if user already assigned, for simplicity we just insert
    // But table has UNIQUE(user_id, apartment_id). We might want to remove old assignments if any, or just insert.
    // Assuming a resident can only have one apartment in this simple system:
    
    // First, delete existing assignments for this user if any
    await _client.from('residents_apartments').delete().eq('user_id', userId);
    
    // Then insert new
    await _client.from('residents_apartments').insert({
      'user_id': userId,
      'apartment_id': apartmentId,
      'relation_role': 'owner',
    });
    
    // Update apartment to not empty
    await _client.from('apartments').update({'is_empty': false}).eq('id', apartmentId);
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

  // Issues Management
  Stream<List<Map<String, dynamic>>> watchRawIssues() {
    return _client.from('issue_reports').stream(primaryKey: ['id']);
  }

  Future<List<IssueModel>> fetchIssues() async {
    final response = await _client
        .from('issue_reports')
        .select('*, apartments(*), users!issue_reports_reporter_id_fkey(*)')
        .order('created_at', ascending: false);
    return (response as List).map((e) => IssueModel.fromJson(e)).toList();
  }

  Future<void> updateIssueStatus(String id, String status) async {
    await _client.from('issue_reports').update({'status': status}).eq('id', id);
  }
}
