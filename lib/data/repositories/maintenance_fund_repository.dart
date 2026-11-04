import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../contracts/contracts.dart';
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

  /// Ghi sổ quỹ bảo trì sử dụng hợp đồng Strongly-Typed DTO
  Future<RecordMaintenanceTransactionResponseDto> recordTransactionContract(
    RecordMaintenanceTransactionRequestDto request,
  ) async {
    final client = _client;
    if (client == null) {
      return const RecordMaintenanceTransactionResponseDto(
        success: false,
        message: 'Chưa cấu hình Supabase Client.',
      );
    }

    try {
      final res = await client.rpc(
        'record_maintenance_fund_transaction',
        params: request.toRpcParams(),
      );
      return RecordMaintenanceTransactionResponseDto.fromRpc(res);
    } catch (e) {
      return RecordMaintenanceTransactionResponseDto(
        success: false,
        message: 'Lỗi ghi sổ quỹ bảo trì: $e',
      );
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
    final req = RecordMaintenanceTransactionRequestDto(
      buildingId: buildingId,
      transactionType: transactionType,
      amount: amount,
      category: category,
      description: description,
      receiptUrl: null,
      referenceId: referenceId,
      createdBy: null,
    );

    final resDto = await recordTransactionContract(req);
    if (!resDto.success && resDto.message.contains('Chưa cấu hình')) {
      return null;
    }

    return {
      'success': resDto.success,
      'transaction_id': resDto.transactionId,
      'voucher_number': resDto.voucherNumber,
      'new_balance': resDto.newBalance,
      'message': resDto.message,
    };
  }
}
