import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/maintenance_fund_model.dart';
import '../models/maintenance_fund_transaction_model.dart';

class MaintenanceFundRepository {
  SupabaseClient? get _client {
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  Future<MaintenanceFundModel?> fetchFundByBuilding(String? buildingId) async {
    final client = _client;
    if (client == null) return null;

    try {
      var query = client.from('maintenance_funds').select();
      if (buildingId != null && buildingId.isNotEmpty) {
        query = query.eq('building_id', buildingId);
      }
      final response = await query.order('created_at', ascending: false).limit(1).maybeSingle();
      if (response == null) {
        // Fallback lấy quỹ mặc định nếu tòa nhà chưa tạo bản ghi riêng
        final fallback = await client.from('maintenance_funds').select().order('created_at', ascending: false).limit(1).maybeSingle();
        return fallback != null ? MaintenanceFundModel.fromJson(fallback) : null;
      }
      return MaintenanceFundModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<List<MaintenanceFundTransactionModel>> fetchTransactions({
    String? buildingId,
    String? transactionType,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('maintenance_fund_transactions').select();
      if (buildingId != null && buildingId.isNotEmpty) {
        query = query.eq('building_id', buildingId);
      }
      if (transactionType != null && transactionType != 'ALL') {
        query = query.eq('transaction_type', transactionType);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List<dynamic>)
          .map((item) => MaintenanceFundTransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> recordTransaction({
    required String buildingId,
    required String transactionType,
    required String category,
    required double amount,
    required String description,
    required String recipientOrPayer,
    String? referenceType,
    String? referenceId,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('record_maintenance_fund_transaction', params: {
        'p_building_id': buildingId,
        'p_transaction_type': transactionType,
        'p_category': category,
        'p_amount': amount,
        'p_description': description,
        'p_recipient_or_payer': recipientOrPayer,
        if (referenceType != null) 'p_reference_type': referenceType,
        if (referenceId != null) 'p_reference_id': referenceId,
      });
      return res as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
