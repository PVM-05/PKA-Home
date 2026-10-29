import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/accounting_period_model.dart';
import '../models/apartment_ledger_entry_model.dart';
import '../models/credit_note_model.dart';

class AccountingRepository {
  final SupabaseClient? _injectedClient;

  AccountingRepository({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  List<ApartmentLedgerEntryModel> parseLedgerEntries(List<dynamic> list) {
    return list
        .map((item) => ApartmentLedgerEntryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<CreditNoteModel> parseCreditNotes(List<dynamic> list) {
    return list
        .map((item) => CreditNoteModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<AccountingPeriodModel> parseAccountingPeriods(List<dynamic> list) {
    return list
        .map((item) => AccountingPeriodModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApartmentLedgerEntryModel>> fetchLedgerEntries({
    required String apartmentId,
    String? period,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('apartment_ledger_entries').select();
      query = query.eq('apartment_id', apartmentId);
      if (period != null && period.isNotEmpty) {
        query = query.eq('period', period);
      }

      final response = await query.order('created_at', ascending: false);
      return parseLedgerEntries(response as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  Future<double> fetchApartmentBalance(String apartmentId) async {
    final client = _client;
    if (client == null) return 0.0;

    try {
      final response = await client.rpc(
        'get_apartment_ledger_balance',
        params: {'p_apartment_id': apartmentId},
      );
      if (response != null && response is num) {
        return response.toDouble();
      }
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<CreditNoteModel>> fetchCreditNotes({
    required String buildingId,
    String? apartmentId,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('credit_notes').select();
      if (buildingId.isNotEmpty) {
        query = query.eq('building_id', buildingId);
      }
      if (apartmentId != null && apartmentId.isNotEmpty) {
        query = query.eq('apartment_id', apartmentId);
      }

      final response = await query.order('created_at', ascending: false);
      return parseCreditNotes(response as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  Future<List<AccountingPeriodModel>> fetchAccountingPeriods(String buildingId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('accounting_periods')
          .select()
          .eq('building_id', buildingId)
          .order('period', ascending: false);

      return parseAccountingPeriods(response as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> recordLedgerEntry({
    required String buildingId,
    required String apartmentId,
    required String entryType,
    required double amount,
    required String period,
    required String referenceType,
    String? referenceId,
    String description = '',
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final params = <String, dynamic>{
        'p_building_id': buildingId,
        'p_apartment_id': apartmentId,
        'p_entry_type': entryType,
        'p_amount': amount,
        'p_period': period,
        'p_reference_type': referenceType,
        'p_reference_id': referenceId,
        'p_description': description,
        'p_created_by': client.auth.currentUser?.id,
      };

      final response = await client.rpc(
        'record_apartment_ledger_entry',
        params: params,
      );
      return response is Map<String, dynamic> ? response : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> issueCreditNote({
    required String buildingId,
    required String apartmentId,
    String? invoiceId,
    String noteType = 'CREDIT',
    required double amount,
    required String reason,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final params = <String, dynamic>{
        'p_building_id': buildingId,
        'p_apartment_id': apartmentId,
        'p_invoice_id': invoiceId,
        'p_note_type': noteType,
        'p_amount': amount,
        'p_reason': reason,
        'p_approved_by': client.auth.currentUser?.id,
      };

      final response = await client.rpc(
        'issue_credit_note',
        params: params,
      );
      return response is Map<String, dynamic> ? response : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> closeAccountingPeriod({
    required String buildingId,
    required String period,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final params = <String, dynamic>{
        'p_building_id': buildingId,
        'p_period': period,
        'p_closed_by': client.auth.currentUser?.id,
        'p_notes': notes,
      };

      final response = await client.rpc(
        'close_accounting_period',
        params: params,
      );
      return response is Map<String, dynamic> ? response : null;
    } catch (_) {
      return null;
    }
  }
}
