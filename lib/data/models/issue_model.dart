import 'apartment_model.dart';
import 'resident_model.dart';

class IssueModel {
  final String id;
  final String apartmentId;
  final String reporterId;
  final String description;
  final String status;
  final String priority;
  final DateTime createdAt;
  final ApartmentModel? apartment;
  final ResidentModel? reporter;

  IssueModel({
    required this.id,
    required this.apartmentId,
    required this.reporterId,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.apartment,
    this.reporter,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      id: json['id'] ?? '',
      apartmentId: json['apartment_id'] ?? '',
      reporterId: json['reporter_id'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'medium',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      apartment: json['apartments'] != null ? ApartmentModel.fromJson(json['apartments']) : null,
      reporter: json['users'] != null ? ResidentModel.fromJson(json['users']) : null,
    );
  }
}
