import 'apartment_model.dart';

class InvoiceModel {
  final String id;
  final String apartmentId;
  final String period;
  final DateTime dueDate;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ApartmentModel? apartment;
  final String? paymentMethod;
  final String? transactionCode;
  final DateTime? paidAt;
  final String? receiptNumber;
  final String? einvoiceLookupCode;
  final double? paidAmount;

  InvoiceModel({
    required this.id,
    required this.apartmentId,
    required this.period,
    required this.dueDate,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.apartment,
    this.paymentMethod,
    this.transactionCode,
    this.paidAt,
    this.receiptNumber,
    this.einvoiceLookupCode,
    this.paidAmount,
  });

  String get displayReceiptNumber {
    if (receiptNumber != null && receiptNumber!.isNotEmpty) {
      return receiptNumber!;
    }
    final cleanPeriod = period.replaceAll('/', '');
    final suffix = (transactionCode ?? id).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').padRight(5, '0');
    final code = suffix.length >= 5 ? suffix.substring(suffix.length - 5) : suffix;
    return 'PT-$cleanPeriod-${code.toUpperCase()}';
  }

  String get displayLookupCode {
    if (einvoiceLookupCode != null && einvoiceLookupCode!.isNotEmpty) {
      return einvoiceLookupCode!;
    }
    final clean = (transactionCode ?? id).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return clean.length >= 8 ? clean.substring(0, 8).toUpperCase() : clean.toUpperCase().padRight(8, '0');
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] ?? '',
      apartmentId: json['apartment_id'] ?? '',
      period: json['period'] ?? '',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : DateTime.now(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'unpaid',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      apartment: json['apartments'] != null ? ApartmentModel.fromJson(json['apartments']) : null,
      paymentMethod: json['payment_method'] as String?,
      transactionCode: json['transaction_code'] as String?,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      receiptNumber: json['receipt_number'] as String?,
      einvoiceLookupCode: json['einvoice_lookup_code'] as String?,
      paidAmount: (json['paid_amount'] as num?)?.toDouble(),
    );
  }
}
