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
  });

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
    );
  }
}
