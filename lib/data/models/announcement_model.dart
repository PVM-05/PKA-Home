class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final bool isUrgent;
  final String targetType; // 'all' | 'block_a' | 'block_b' | 'apartment'
  final String? targetApartment;
  final DateTime createdAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isUrgent,
    this.targetType = 'all',
    this.targetApartment,
    required this.createdAt,
  });

  String get targetDisplayName {
    switch (targetType) {
      case 'block_a':
        return 'Tòa A';
      case 'block_b':
        return 'Tòa B';
      case 'apartment':
        return 'Căn hộ ${targetApartment ?? ""}';
      case 'all':
      default:
        return 'Tất cả cư dân';
    }
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isUrgent: json['is_urgent'] ?? false,
      targetType: json['target_type'] as String? ?? 'all',
      targetApartment: json['target_apartment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
      'target_type': targetType,
      if (targetApartment != null) 'target_apartment': targetApartment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
