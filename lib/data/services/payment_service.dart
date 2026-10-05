import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../providers/resident_invoice_provider.dart';
import '../providers/amenity_booking_provider.dart';

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
    );
  }
}

class PaymentService {
  const PaymentService();

  Future<PaymentResult> pay({
    required WidgetRef ref,
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

    final result = PaymentResult.fromJson(Map<String, dynamic>.from(res as Map));

    // Làm mới realtime cache của các module liên quan
    if (type == PaymentType.invoice) {
      ref.invalidate(residentInvoiceProvider);
      ref.invalidate(residentInvoiceDetailProvider(referenceId));
    } else {
      ref.invalidate(myAmenityBookingsProvider);
    }

    return result;
  }
}
