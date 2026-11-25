import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/building_payment_config_model.dart';
import '../models/payment_transaction_model.dart';
import '../services/payment_service.dart';
import 'resident_invoice_provider.dart';
import 'amenity_booking_provider.dart';
import 'auth_provider.dart';
import 'building_provider.dart';
import 'management_provider.dart';
import 'resident_apartment_provider.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return const PaymentService();
});

/// Provider nạp cấu hình tài khoản ngân hàng & SePay theo tòa nhà
final buildingPaymentConfigProvider = FutureProvider.family<BuildingPaymentConfigModel?, String>((ref, buildingId) async {
  final service = ref.watch(paymentServiceProvider);
  return service.fetchBuildingPaymentConfig(buildingId);
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
    String paymentMethod = 'bank_transfer',
    String outcome = 'PENDING',
  }) async {
    final result = await _service.pay(
      type: type,
      referenceId: referenceId,
      paymentMethod: paymentMethod,
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

/// Stream Realtime lắng nghe giao dịch mới (phụ thuộc phiên đăng nhập để chống rò rỉ cache)
final _paymentTransactionsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authUser = ref.watch(authProvider).valueOrNull;
  final userId = authUser?.id ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client.auth.currentUser?.id : null);
  if (userId == null) {
    return const Stream.empty();
  }
  if (authUser != null && authUser.isManagement) {
    return SupabaseConfig.client
        .from('payment_transactions')
        .stream(primaryKey: ['id']);
  }
  return SupabaseConfig.client
      .from('payment_transactions')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId);
});

/// Provider tải danh sách lịch sử giao dịch (Hóa đơn & Dịch vụ gom chung, lọc theo ngữ cảnh căn hộ / tòa nhà)
final paymentTransactionsProvider = FutureProvider<List<PaymentTransactionModel>>((ref) async {
  final authUser = ref.watch(authProvider).valueOrNull;
  ref.watch(_paymentTransactionsStreamProvider);

  final userId = authUser?.id ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client.auth.currentUser?.id : null);
  if (userId == null) return [];

  if (authUser != null && !authUser.isManagement) {
    final selectedAptId = ref.watch(selectedApartmentIdProvider);
    var query = SupabaseConfig.client.from('payment_transactions').select();
    if (selectedAptId != null && selectedAptId.isNotEmpty) {
      query = query.eq('apartment_id', selectedAptId);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((item) => PaymentTransactionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // Luồng Ban Quản Lý / Kế toán: lắng nghe tòa nhà đang chọn
  final activeBuildingId = ref.watch(activeBuildingIdProvider);
  final response = await SupabaseConfig.client
      .from('payment_transactions')
      .select('*, apartments(building_id)')
      .order('created_at', ascending: false);

  final rawList = List<Map<String, dynamic>>.from(response as List);
  final hasBuildingInfo = rawList.any((r) => (r['apartments'] as Map?)?['building_id'] != null);
  final filtered = hasBuildingInfo
      ? rawList.where((r) {
          final bId = (r['apartments'] as Map?)?['building_id'] as String?;
          return bId == null || bId == activeBuildingId;
        })
      : rawList;

  return filtered
      .map((item) => PaymentTransactionModel.fromJson(item))
      .toList();
});
