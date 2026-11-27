class AnnouncementModel {
  final String id;
  final String? buildingId;
  final String title;
  final String content;
  final bool isUrgent;
  final String targetType; // 'all' | 'block' | 'floor' | 'apartment' | 'block_a' | 'block_b'
  final String? targetValue;
  final String? targetApartment;
  final String category; // 'emergency' | 'elevator_maintenance' | 'utility_outage' | 'resident_meeting' | 'general'
  final DateTime? eventStartAt;
  final DateTime? eventEndAt;
  final bool isPinned;
  final int broadcastCount;
  final int readCount;
  final String? hotlineContact;
  final DateTime createdAt;

  AnnouncementModel({
    required this.id,
    this.buildingId,
    required this.title,
    required this.content,
    required this.isUrgent,
    this.targetType = 'all',
    this.targetValue,
    this.targetApartment,
    this.category = 'general',
    this.eventStartAt,
    this.eventEndAt,
    this.isPinned = false,
    this.broadcastCount = 0,
    this.readCount = 0,
    this.hotlineContact,
    required this.createdAt,
  });

  String get targetDisplayName {
    switch (targetType) {
      case 'block':
        return 'Block ${targetValue ?? ""}';
      case 'floor':
        return 'Tầng ${targetValue ?? ""}';
      case 'apartment':
        final apt = targetValue ?? targetApartment ?? '';
        return 'Căn hộ $apt';
      case 'block_a':
        return 'Tòa A';
      case 'block_b':
        return 'Tòa B';
      case 'all':
      default:
        return 'Tất cả cư dân';
    }
  }

  String get categoryDisplayName {
    switch (category) {
      case 'emergency':
        return 'Khẩn cấp';
      case 'elevator_maintenance':
        return 'Bảo trì thang máy';
      case 'utility_outage':
        return 'Cúp điện / nước';
      case 'resident_meeting':
        return 'Họp cư dân';
      case 'general':
      default:
        return 'Thông báo chung';
    }
  }

  bool get isOngoing {
    if (eventStartAt == null || eventEndAt == null) return false;
    final now = DateTime.now();
    return now.isAfter(eventStartAt!) && now.isBefore(eventEndAt!);
  }

  double get readRatio {
    if (broadcastCount <= 0) return 0.0;
    return (readCount / broadcastCount).clamp(0.0, 1.0);
  }

  String get readRatioPercentageText {
    return '${(readRatio * 100).toStringAsFixed(1)}%';
  }

  AnnouncementModel copyWith({
    String? id,
    String? buildingId,
    String? title,
    String? content,
    bool? isUrgent,
    String? targetType,
    String? targetValue,
    String? targetApartment,
    String? category,
    DateTime? eventStartAt,
    DateTime? eventEndAt,
    bool? isPinned,
    int? broadcastCount,
    int? readCount,
    String? hotlineContact,
    DateTime? createdAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      title: title ?? this.title,
      content: content ?? this.content,
      isUrgent: isUrgent ?? this.isUrgent,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      targetApartment: targetApartment ?? this.targetApartment,
      category: category ?? this.category,
      eventStartAt: eventStartAt ?? this.eventStartAt,
      eventEndAt: eventEndAt ?? this.eventEndAt,
      isPinned: isPinned ?? this.isPinned,
      broadcastCount: broadcastCount ?? this.broadcastCount,
      readCount: readCount ?? this.readCount,
      hotlineContact: hotlineContact ?? this.hotlineContact,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isUrgent: json['is_urgent'] ?? false,
      targetType: json['target_type'] as String? ?? 'all',
      targetValue: json['target_value'] as String?,
      targetApartment: json['target_apartment'] as String?,
      category: json['category'] as String? ?? 'general',
      eventStartAt: json['event_start_at'] != null
          ? DateTime.tryParse(json['event_start_at'] as String)
          : null,
      eventEndAt: json['event_end_at'] != null
          ? DateTime.tryParse(json['event_end_at'] as String)
          : null,
      isPinned: json['is_pinned'] ?? false,
      broadcastCount: (json['broadcast_count'] as num?)?.toInt() ?? 0,
      readCount: (json['read_count'] as num?)?.toInt() ?? 0,
      hotlineContact: json['hotline_contact'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (buildingId != null) 'building_id': buildingId,
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
      'target_type': targetType,
      if (targetValue != null) 'target_value': targetValue,
      if (targetApartment != null) 'target_apartment': targetApartment,
      'category': category,
      if (eventStartAt != null) 'event_start_at': eventStartAt!.toIso8601String(),
      if (eventEndAt != null) 'event_end_at': eventEndAt!.toIso8601String(),
      'is_pinned': isPinned,
      'broadcast_count': broadcastCount,
      'read_count': readCount,
      if (hotlineContact != null) 'hotline_contact': hotlineContact,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
