class PetitionModel {
  final String id;
  final String petitionCode;
  final String apartmentId;
  final String? apartmentCode;
  final String authorUserId;
  final String? authorName;
  final String title;
  final String content;
  final String category; // security, hygiene, amenity, noise, other
  final List<String> imageUrls;
  final int endorsementCount;
  final String status; // pending, acknowledged, in_progress, resolved, rejected
  final String? officialResponse;
  final String? respondedByStaffId;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEndorsedByMe;

  const PetitionModel({
    required this.id,
    required this.petitionCode,
    required this.apartmentId,
    this.apartmentCode,
    required this.authorUserId,
    this.authorName,
    required this.title,
    required this.content,
    this.category = 'general',
    this.imageUrls = const [],
    this.endorsementCount = 0,
    this.status = 'pending',
    this.officialResponse,
    this.respondedByStaffId,
    this.respondedAt,
    required this.createdAt,
    this.updatedAt,
    this.isEndorsedByMe = false,
  });

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'security':
        return 'An ninh & Trật tự';
      case 'hygiene':
        return 'Vệ sinh & Môi trường';
      case 'amenity':
        return 'Tiện ích & Cảnh quan';
      case 'noise':
        return 'Tiếng ồn sinh hoạt';
      case 'other':
      default:
        return 'Góp ý chung';
    }
  }

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'acknowledged':
        return 'Đã tiếp nhận';
      case 'in_progress':
        return 'Đang xử lý';
      case 'resolved':
        return 'Đã giải quyết';
      case 'rejected':
        return 'Từ chối / Không phù hợp';
      case 'pending':
      default:
        return 'Chờ tiếp nhận';
    }
  }

  factory PetitionModel.fromJson(Map<String, dynamic> json) {
    String? aptCode;
    if (json['apartments'] is Map) {
      aptCode = json['apartments']['code'] as String?;
    } else if (json['apartment_code'] != null) {
      aptCode = json['apartment_code'] as String?;
    }

    String? authName;
    if (json['users'] is Map) {
      authName = json['users']['full_name'] as String?;
    } else if (json['author_name'] != null) {
      authName = json['author_name'] as String?;
    }

    List<String> imgs = [];
    if (json['image_urls'] is List) {
      imgs = (json['image_urls'] as List).map((e) => e.toString()).toList();
    }

    return PetitionModel(
      id: json['id'] as String,
      petitionCode: (json['petition_code'] as String?) ?? '',
      apartmentId: (json['apartment_id'] as String?) ?? '',
      apartmentCode: aptCode,
      authorUserId: (json['author_user_id'] as String?) ?? '',
      authorName: authName,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'general',
      imageUrls: imgs,
      endorsementCount: (json['endorsement_count'] as int?) ?? 0,
      status: (json['status'] as String?) ?? 'pending',
      officialResponse: json['official_response'] as String?,
      respondedByStaffId: json['responded_by_staff_id'] as String?,
      respondedAt: json['responded_at'] != null ? DateTime.tryParse(json['responded_at'].toString()) : null,
      createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      isEndorsedByMe: (json['is_endorsed_by_me'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petition_code': petitionCode,
      'apartment_id': apartmentId,
      'apartment_code': apartmentCode,
      'author_user_id': authorUserId,
      'author_name': authorName,
      'title': title,
      'content': content,
      'category': category,
      'image_urls': imageUrls,
      'endorsement_count': endorsementCount,
      'status': status,
      'official_response': officialResponse,
      'responded_by_staff_id': respondedByStaffId,
      if (respondedAt != null) 'responded_at': respondedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'is_endorsed_by_me': isEndorsedByMe,
    };
  }

  PetitionModel copyWith({
    String? id,
    String? petitionCode,
    String? apartmentId,
    String? apartmentCode,
    String? authorUserId,
    String? authorName,
    String? title,
    String? content,
    String? category,
    List<String>? imageUrls,
    int? endorsementCount,
    String? status,
    String? officialResponse,
    String? respondedByStaffId,
    DateTime? respondedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEndorsedByMe,
  }) {
    return PetitionModel(
      id: id ?? this.id,
      petitionCode: petitionCode ?? this.petitionCode,
      apartmentId: apartmentId ?? this.apartmentId,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      authorUserId: authorUserId ?? this.authorUserId,
      authorName: authorName ?? this.authorName,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      endorsementCount: endorsementCount ?? this.endorsementCount,
      status: status ?? this.status,
      officialResponse: officialResponse ?? this.officialResponse,
      respondedByStaffId: respondedByStaffId ?? this.respondedByStaffId,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEndorsedByMe: isEndorsedByMe ?? this.isEndorsedByMe,
    );
  }
}

