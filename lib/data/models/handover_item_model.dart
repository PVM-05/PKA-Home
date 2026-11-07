class HandoverItemModel {
  final String id;
  final String handoverId;
  final String? assetId;
  final String itemName;
  final String roomArea;
  final int quantity;
  final String condition; // good, minor_scratch, damaged, missing
  final double repairCost;
  final String? note;
  final List<String> photos;
  final DateTime? createdAt;

  const HandoverItemModel({
    required this.id,
    required this.handoverId,
    this.assetId,
    required this.itemName,
    this.roomArea = 'living_room',
    this.quantity = 1,
    this.condition = 'good',
    this.repairCost = 0.0,
    this.note,
    this.photos = const [],
    this.createdAt,
  });

  bool get hasPhotos => photos.isNotEmpty;
  bool get hasDamage => condition == 'damaged' || condition == 'missing' || repairCost > 0;

  String get roomAreaDisplayName {
    switch (roomArea) {
      case 'living_room':
        return 'Phòng khách';
      case 'bedroom':
        return 'Phòng ngủ';
      case 'kitchen':
        return 'Nhà bếp';
      case 'bathroom':
        return 'Nhà vệ sinh';
      case 'balcony':
        return 'Ban công / Logia';
      default:
        return 'Khu vực khác';
    }
  }

  String get conditionDisplayName {
    switch (condition) {
      case 'good':
        return 'Tốt';
      case 'minor_scratch':
        return 'Trầy xước nhẹ';
      case 'damaged':
        return 'Hư hỏng';
      case 'missing':
        return 'Thất lạc';
      default:
        return 'Bình thường';
    }
  }

  factory HandoverItemModel.fromJson(Map<String, dynamic> json) {
    var rawPhotos = json['photos'];
    List<String> parsedPhotos = [];
    if (rawPhotos is List) {
      parsedPhotos = rawPhotos.map((e) => e.toString()).toList();
    }

    return HandoverItemModel(
      id: json['id'] as String,
      handoverId: json['handover_id'] as String,
      assetId: json['asset_id'] as String?,
      itemName: json['item_name'] as String,
      roomArea: (json['room_area'] ?? 'living_room') as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      condition: (json['condition'] ?? 'good') as String,
      repairCost: (json['repair_cost'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
      photos: parsedPhotos,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'handover_id': handoverId,
      if (assetId != null) 'asset_id': assetId,
      'item_name': itemName,
      'room_area': roomArea,
      'quantity': quantity,
      'condition': condition,
      'repair_cost': repairCost,
      if (note != null) 'note': note,
      'photos': photos,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  HandoverItemModel copyWith({
    String? id,
    String? handoverId,
    String? assetId,
    String? itemName,
    String? roomArea,
    int? quantity,
    String? condition,
    double? repairCost,
    String? note,
    List<String>? photos,
    DateTime? createdAt,
  }) {
    return HandoverItemModel(
      id: id ?? this.id,
      handoverId: handoverId ?? this.handoverId,
      assetId: assetId ?? this.assetId,
      itemName: itemName ?? this.itemName,
      roomArea: roomArea ?? this.roomArea,
      quantity: quantity ?? this.quantity,
      condition: condition ?? this.condition,
      repairCost: repairCost ?? this.repairCost,
      note: note ?? this.note,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

