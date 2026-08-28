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
  final List<String> imageUrls;

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
    this.imageUrls = const [],
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedImages = [];
    if (json['issue_images'] != null) {
      if (json['issue_images'] is List) {
        parsedImages = (json['issue_images'] as List).map((e) => e['image_url'] as String).toList();
      }
    }

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
      imageUrls: parsedImages,
    );
  }
}
