import 'apartment_model.dart';
import 'resident_model.dart';

class IssueImageModel {
  final String imageUrl;
  final String role; // 'report' | 'resolution_proof'

  IssueImageModel({
    required this.imageUrl,
    this.role = 'report',
  });

  bool get isReport => role == 'report';
  bool get isResolutionProof => role == 'resolution_proof';

  factory IssueImageModel.fromJson(Map<String, dynamic> json) {
    return IssueImageModel(
      imageUrl: json['image_url'] as String? ?? '',
      role: json['image_role'] as String? ?? 'report',
    );
  }
}

class IssueModel {
  final String id;
  final String apartmentId;
  final String reporterId;
  final String? assignedStaffId;
  final String description;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ApartmentModel? apartment;
  final ResidentModel? reporter;
  final ResidentModel? assignedStaff;
  final List<String> imageUrls;
  final List<IssueImageModel> images;

  IssueModel({
    required this.id,
    required this.apartmentId,
    required this.reporterId,
    this.assignedStaffId,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
    this.apartment,
    this.reporter,
    this.assignedStaff,
    this.imageUrls = const [],
    this.images = const [],
  });

  /// Danh sách ảnh do cư dân gửi khi báo cáo sự cố (ảnh "Trước")
  List<String> get reportImages {
    final list = images.where((i) => i.isReport).map((i) => i.imageUrl).toList();
    return list.isNotEmpty ? list : imageUrls;
  }

  /// Danh sách ảnh do kỹ thuật viên / BQL chụp nghiệm thu sau khi hoàn thành (ảnh "Sau")
  List<String> get resolutionProofImages {
    return images.where((i) => i.isResolutionProof).map((i) => i.imageUrl).toList();
  }

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedUrls = [];
    List<IssueImageModel> parsedImages = [];

    if (json['issue_images'] != null && json['issue_images'] is List) {
      for (var item in json['issue_images']) {
        if (item is Map<String, dynamic>) {
          final url = item['image_url'] as String? ?? '';
          if (url.isNotEmpty) {
            parsedUrls.add(url);
            parsedImages.add(IssueImageModel.fromJson(item));
          }
        }
      }
    }

    return IssueModel(
      id: json['id'] ?? '',
      apartmentId: json['apartment_id'] ?? '',
      reporterId: json['reporter_id'] ?? '',
      assignedStaffId: json['assigned_staff_id'] as String?,
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'medium',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      apartment: json['apartments'] != null ? ApartmentModel.fromJson(json['apartments']) : null,
      reporter: json['users'] != null ? ResidentModel.fromJson(json['users']) : null,
      assignedStaff: json['assigned_staff'] != null ? ResidentModel.fromJson(json['assigned_staff']) : null,
      imageUrls: parsedUrls,
      images: parsedImages,
    );
  }
}
