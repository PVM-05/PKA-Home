import 'apartment_model.dart';
import 'resident_model.dart';
import 'issue_rating_model.dart';
import 'issue_material_usage_model.dart';

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
  final String category; // 'electrical', 'plumbing', 'construction', 'elevator', 'fire_safety', 'other'
  final DateTime? slaDeadline;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final String slaStatus; // 'on_time', 'warning', 'breached'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ApartmentModel? apartment;
  final ResidentModel? reporter;
  final ResidentModel? assignedStaff;
  final List<String> imageUrls;
  final List<IssueImageModel> images;
  final IssueRatingModel? rating;
  final List<IssueMaterialUsageModel> materials;

  IssueModel({
    required this.id,
    required this.apartmentId,
    required this.reporterId,
    this.assignedStaffId,
    required this.description,
    required this.status,
    required this.priority,
    this.category = 'other',
    this.slaDeadline,
    this.acknowledgedAt,
    this.resolvedAt,
    this.slaStatus = 'on_time',
    required this.createdAt,
    this.updatedAt,
    this.apartment,
    this.reporter,
    this.assignedStaff,
    this.imageUrls = const [],
    this.images = const [],
    this.rating,
    this.materials = const [],
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

  /// Tên chuyên môn hiển thị tiếng Việt
  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'electrical':
        return 'Điện';
      case 'plumbing':
        return 'Nước';
      case 'construction':
        return 'Xây dựng/Nội thất';
      case 'elevator':
        return 'Thang máy';
      case 'fire_safety':
        return 'PCCC & An toàn';
      case 'other':
      default:
        return 'Khác';
    }
  }

  /// Trạng thái SLA thời gian thực
  bool get isSlaBreached {
    if (slaStatus == 'breached') return true;
    if (status != 'resolved' && slaDeadline != null) {
      return DateTime.now().isAfter(slaDeadline!);
    }
    if (resolvedAt != null && slaDeadline != null) {
      return resolvedAt!.isAfter(slaDeadline!);
    }
    return false;
  }

  bool get isSlaWarning {
    if (status == 'resolved' || isSlaBreached || slaDeadline == null) return false;
    final remaining = slaDeadline!.difference(DateTime.now());
    return remaining.inMinutes > 0 && remaining.inMinutes <= 120; // Còn dưới 2 giờ
  }

  /// Định dạng thời gian SLA còn lại hoặc trễ hạn
  String get slaRemainingFormatted {
    if (slaDeadline == null) return 'Chưa có SLA';
    final now = DateTime.now();

    if (status == 'resolved') {
      if (resolvedAt != null && resolvedAt!.isAfter(slaDeadline!)) {
        final diff = resolvedAt!.difference(slaDeadline!);
        return 'Hoàn thành trễ (${diff.inHours}h ${diff.inMinutes % 60}p)';
      }
      return 'Đã hoàn thành đúng hạn';
    }

    if (now.isAfter(slaDeadline!)) {
      final diff = now.difference(slaDeadline!);
      if (diff.inDays > 0) return 'Trễ hạn ${diff.inDays} ngày';
      if (diff.inHours > 0) return 'Trễ hạn ${diff.inHours}h ${diff.inMinutes % 60}p';
      return 'Trễ hạn ${diff.inMinutes} phút';
    }

    final diff = slaDeadline!.difference(now);
    if (diff.inDays > 0) return 'Còn ${diff.inDays} ngày ${diff.inHours % 24}h';
    if (diff.inHours > 0) return 'Còn ${diff.inHours}h ${diff.inMinutes % 60}p';
    return 'Còn ${diff.inMinutes} phút';
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

    List<IssueMaterialUsageModel> parsedMaterials = [];
    if (json['issue_materials'] != null && json['issue_materials'] is List) {
      for (var item in json['issue_materials']) {
        if (item is Map<String, dynamic>) {
          parsedMaterials.add(IssueMaterialUsageModel.fromJson(item));
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
      category: json['category'] as String? ?? 'other',
      slaDeadline: json['sla_deadline'] != null ? DateTime.parse(json['sla_deadline']) : null,
      acknowledgedAt: json['acknowledged_at'] != null ? DateTime.parse(json['acknowledged_at']) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
      slaStatus: json['sla_status'] as String? ?? 'on_time',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      apartment: json['apartments'] != null ? ApartmentModel.fromJson(json['apartments']) : null,
      reporter: json['users'] != null ? ResidentModel.fromJson(json['users']) : null,
      assignedStaff: json['assigned_staff'] != null ? ResidentModel.fromJson(json['assigned_staff']) : null,
      imageUrls: parsedUrls,
      images: parsedImages,
      materials: parsedMaterials,
      rating: json['issue_ratings'] != null
          ? (json['issue_ratings'] is List && (json['issue_ratings'] as List).isNotEmpty
              ? IssueRatingModel.fromJson((json['issue_ratings'] as List).first as Map<String, dynamic>)
              : (json['issue_ratings'] is Map<String, dynamic>
                  ? IssueRatingModel.fromJson(json['issue_ratings'] as Map<String, dynamic>)
                  : null))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      'reporter_id': reporterId,
      'assigned_staff_id': assignedStaffId,
      'description': description,
      'status': status,
      'priority': priority,
      'category': category,
      'sla_deadline': slaDeadline?.toIso8601String(),
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'sla_status': slaStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  IssueModel copyWith({
    String? id,
    String? apartmentId,
    String? reporterId,
    String? assignedStaffId,
    String? description,
    String? status,
    String? priority,
    String? category,
    DateTime? slaDeadline,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
    String? slaStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    ApartmentModel? apartment,
    ResidentModel? reporter,
    ResidentModel? assignedStaff,
    List<String>? imageUrls,
    List<IssueImageModel>? images,
    IssueRatingModel? rating,
    List<IssueMaterialUsageModel>? materials,
  }) {
    return IssueModel(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      reporterId: reporterId ?? this.reporterId,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      slaDeadline: slaDeadline ?? this.slaDeadline,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      slaStatus: slaStatus ?? this.slaStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      apartment: apartment ?? this.apartment,
      reporter: reporter ?? this.reporter,
      assignedStaff: assignedStaff ?? this.assignedStaff,
      imageUrls: imageUrls ?? this.imageUrls,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      materials: materials ?? this.materials,
    );
  }
}
