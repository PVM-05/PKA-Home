class BuildingRuleModel {
  final String id;
  final String title;
  final String content;
  final int displayOrder;
  final DateTime? createdAt;

  BuildingRuleModel({
    required this.id,
    required this.title,
    required this.content,
    required this.displayOrder,
    this.createdAt,
  });

  factory BuildingRuleModel.fromJson(Map<String, dynamic> json) {
    return BuildingRuleModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'display_order': displayOrder,
  };
}
