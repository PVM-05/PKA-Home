import '../../core/supabase_config.dart';

enum PaymentType { invoice, service }

class PaymentResult {
  final bool success;
  final bool isPending;
  final String status;
  final String transactionCode;
  final String transactionId;
  final double amount;
  final String title;
  final DateTime paidAt;
  final String? errorMessage;

  PaymentResult({
    required this.success,
    this.isPending = false,
    this.status = 'SUCCESS',
    required this.transactionCode,
    required this.transactionId,
    required this.amount,
    required this.title,
    required this.paidAt,
    this.errorMessage,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String?;
    final isExplicitPending = (json['is_pending'] as bool?) == true;
    final isExplicitSuccess = (json['success'] as bool?) == true;

    final String statusVal;
    if (rawStatus != null && rawStatus.isNotEmpty) {
      statusVal = rawStatus.toUpperCase();
    } else if (isExplicitPending) {
      statusVal = 'PENDING';
    } else if (isExplicitSuccess) {
      statusVal = 'SUCCESS';
    } else {
      statusVal = 'FAILED';
    }

    final isPendingVal = statusVal == 'PENDING';
    final isSuccessVal = statusVal == 'SUCCESS' && (json['success'] as bool? ?? true);
    final hasValidState = isSuccessVal || isPendingVal;

    final txCode = (json['receipt_number'] as String?) ??
        (json['transaction_code'] as String?) ??
        '';

    return PaymentResult(
      success: hasValidState,
      isPending: isPendingVal,
      status: statusVal,
      transactionCode: txCode,
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
    String paymentMethod = 'bank_transfer',
    String outcome = 'SUCCESS',
    String? failureReason,
  }) async {
    final typeString = type == PaymentType.invoice ? 'INVOICE' : 'SERVICE';

    final res = await SupabaseConfig.client.rpc(
      'simulate_unified_payment',
      params: {
        'p_reference_id': referenceId,
        'p_payment_type': typeString,
        'p_payment_method': paymentMethod,
        'p_outcome': outcome,
        if (failureReason != null) 'p_failure_reason': failureReason,
      },
    );

    return PaymentResult.fromJson(Map<String, dynamic>.from(res as Map));
  }
}
