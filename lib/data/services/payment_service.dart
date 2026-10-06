import '../../core/supabase_config.dart';

enum PaymentType { invoice, service }

class PaymentResult {
  final bool success;
  final String transactionCode;
  final String transactionId;
  final double amount;
  final String title;
  final DateTime paidAt;
  final String? errorMessage;

  PaymentResult({
    required this.success,
    required this.transactionCode,
    required this.transactionId,
    required this.amount,
    required this.title,
    required this.paidAt,
    this.errorMessage,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      success: json['success'] as bool? ?? false,
      transactionCode: json['transaction_code'] as String? ?? '',
      transactionId: json['transaction_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? 'Giao dịch',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String).toLocal() : DateTime.now(),
      errorMessage: json['message'] as String? ?? json['error'] as String?,
    );
  }
}

/// Dịch vụ thanh toán thuần túy (Decoupled Service)
/// Độc lập hoàn toàn với Riverpod để tuân thủ kiến trúc phân tầng sạch
class PaymentService {
  const PaymentService();

  Future<PaymentResult> pay({
    required PaymentType type,
    required String referenceId,
    String outcome = 'SUCCESS',
  }) async {
    final typeString = type == PaymentType.invoice ? 'INVOICE' : 'SERVICE';

    final res = await SupabaseConfig.client.rpc(
      'simulate_unified_payment',
      params: {
        'p_type': typeString,
        'p_reference_id': referenceId,
        'p_outcome': outcome,
      },
    );

    return PaymentResult.fromJson(Map<String, dynamic>.from(res as Map));
  }
}
