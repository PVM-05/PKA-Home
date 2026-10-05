import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/payment_transaction_model.dart';
import '../services/payment_service.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return const PaymentService();
});

/// Stream Realtime lắng nghe giao dịch mới
final _paymentTransactionsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = SupabaseConfig.client.auth.currentUser;
  if (user == null) {
    return const Stream.empty();
  }
  return SupabaseConfig.client
      .from('payment_transactions')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id);
});

/// Provider tải danh sách lịch sử giao dịch (Hóa đơn & Dịch vụ gom chung)
final paymentTransactionsProvider = FutureProvider<List<PaymentTransactionModel>>((ref) async {
  // Lắng nghe stream realtime để tự động cập nhật UI khi có giao dịch mới
  ref.watch(_paymentTransactionsStreamProvider);

  final user = SupabaseConfig.client.auth.currentUser;
  if (user == null) return [];

  final response = await SupabaseConfig.client
      .from('payment_transactions')
      .select()
      .order('created_at', ascending: false);

  return (response as List)
      .map((item) => PaymentTransactionModel.fromJson(item as Map<String, dynamic>))
      .toList();
});
