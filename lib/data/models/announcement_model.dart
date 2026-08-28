class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final bool isUrgent;
  final DateTime createdAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isUrgent,
    required this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      isUrgent: json['is_urgent'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
