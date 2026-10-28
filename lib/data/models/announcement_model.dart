class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final bool isUrgent;
  final String targetType; // 'all' | 'block' | 'floor' | 'apartment' | 'block_a' | 'block_b'
  final String? targetValue;
  final String? targetApartment;
  final DateTime createdAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isUrgent,
    this.targetType = 'all',
    this.targetValue,
    this.targetApartment,
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
        return 'Toàn bộ cư dân';
    }
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isUrgent: json['is_urgent'] ?? false,
      targetType: json['target_type'] as String? ?? 'all',
      targetValue: json['target_value'] as String?,
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
      if (targetValue != null) 'target_value': targetValue,
      if (targetApartment != null) 'target_apartment': targetApartment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
