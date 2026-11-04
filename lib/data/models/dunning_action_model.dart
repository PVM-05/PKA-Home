import 'debt_risk_score_model.dart';

class DunningActionModel {
  final String id;
  final String apartmentId;
  final String buildingId;
  final DunningTier tier;
  final String actionType;
  final String actionTitle;
  final String actionContent;
  final String status;
  final String? performedBy;
  final DateTime createdAt;

  const DunningActionModel({
    required this.id,
    required this.apartmentId,
    required this.buildingId,
    required this.tier,
    required this.actionType,
    required this.actionTitle,
    required this.actionContent,
    required this.status,
    this.performedBy,
    required this.createdAt,
  });

  factory DunningActionModel.fromJson(Map<String, dynamic> json) {
    return DunningActionModel(
      id: json['id']?.toString() ?? '',
      apartmentId: json['apartment_id']?.toString() ?? '',
      buildingId: json['building_id']?.toString() ?? '',
      tier: DunningTier.fromString(json['tier']?.toString()),
      actionType: json['action_type']?.toString() ?? 'notification',
      actionTitle: json['action_title']?.toString() ?? '',
      actionContent: json['action_content']?.toString() ?? '',
      status: json['status']?.toString() ?? 'sent',
      performedBy: json['performed_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'apartment_id': apartmentId,
    'building_id': buildingId,
    'tier': tier.dbValue,
    'action_type': actionType,
    'action_title': actionTitle,
    'action_content': actionContent,
    'status': status,
    'performed_by': performedBy,
    'created_at': createdAt.toIso8601String(),
  };
}
