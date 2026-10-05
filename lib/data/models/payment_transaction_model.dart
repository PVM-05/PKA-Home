import 'package:intl/intl.dart';

class PaymentTransactionModel {
  final String id;
  final String? invoiceId;
  final String? bookingId;
  final String type; // 'INVOICE' | 'SERVICE'
  final String? title;
  final String? userId;
  final String apartmentId;
  final double amount;
  final String paymentMethod;
  final String status; // 'SUCCESS', 'FAILED', 'CANCELLED'
  final String transactionCode;
  final String? failureReason;
  final DateTime createdAt;

  PaymentTransactionModel({
    required this.id,
    this.invoiceId,
    this.bookingId,
    this.type = 'INVOICE',
    this.title,
    this.userId,
    required this.apartmentId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.transactionCode,
    this.failureReason,
    required this.createdAt,
  });

  bool get isSuccess => status == 'SUCCESS';
  bool get isFailed => status == 'FAILED';
  bool get isCancelled => status == 'CANCELLED';

  bool get isInvoice => type == 'INVOICE';
  bool get isService => type == 'SERVICE';

  String get statusDisplayName {
    switch (status) {
      case 'SUCCESS':
        return 'Thành công';
      case 'FAILED':
        return 'Thất bại';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  String get formattedAmount {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return currencyFormatter.format(amount);
  }

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionModel(
      id: json['id'] as String,
      invoiceId: json['invoice_id'] as String?,
      bookingId: json['booking_id'] as String?,
      type: json['type'] as String? ?? 'INVOICE',
      title: json['title'] as String?,
      userId: json['user_id'] as String?,
      apartmentId: json['apartment_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'Demo Payment',
      status: json['status'] as String? ?? 'SUCCESS',
      transactionCode: json['transaction_code'] as String? ?? '',
      failureReason: json['failure_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'booking_id': bookingId,
      'type': type,
      'title': title,
      'user_id': userId,
      'apartment_id': apartmentId,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': status,
      'transaction_code': transactionCode,
      'failure_reason': failureReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
