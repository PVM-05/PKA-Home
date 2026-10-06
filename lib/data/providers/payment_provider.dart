import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/payment_transaction_model.dart';
import '../services/payment_service.dart';
import 'resident_invoice_provider.dart';
import 'amenity_booking_provider.dart';
import 'management_provider.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return const PaymentService();
});

/// Bộ điều khiển thanh toán (Orchestration Controller)
/// Đảm nhận gọi PaymentService và quản lý invalidation cache cho toàn bộ app
class PaymentController {
  final Ref _ref;
  final PaymentService _service;

  PaymentController(this._ref, this._service);

  Future<PaymentResult> pay({
    required PaymentType type,
    required String referenceId,
    String outcome = 'SUCCESS',
  }) async {
    final result = await _service.pay(
      type: type,
      referenceId: referenceId,
      outcome: outcome,
    );

    // Khi thanh toán thành công, tự động làm mới toàn bộ provider liên quan
    if (result.success) {
      if (type == PaymentType.invoice) {
        _ref.invalidate(residentInvoiceProvider);
        _ref.invalidate(residentInvoiceDetailProvider(referenceId));
        _ref.invalidate(invoicesProvider);
      } else {
        _ref.invalidate(myAmenityBookingsProvider);
      }
      _ref.invalidate(paymentTransactionsProvider);
    }

    return result;
  }
}

final paymentControllerProvider = Provider<PaymentController>((ref) {
  return PaymentController(ref, ref.watch(paymentServiceProvider));
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
