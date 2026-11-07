class ApartmentAssetModel {
  final String id;
  final String apartmentId;
  final String buildingId;
  final String roomArea; // living_room, bedroom, kitchen, bathroom, balcony, other
  final String name;
  final String? assetCode;
  final int quantity;
  final String condition; // brand_new, good, worn, damaged, missing
  final double replacementPrice;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ApartmentAssetModel({
    required this.id,
    required this.apartmentId,
    required this.buildingId,
    this.roomArea = 'living_room',
    required this.name,
    this.assetCode,
    this.quantity = 1,
    this.condition = 'good',
    this.replacementPrice = 0.0,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDamaged => condition == 'damaged' || condition == 'missing';

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
      case 'brand_new':
        return 'Mới 100%';
      case 'good':
        return 'Tốt';
      case 'worn':
        return 'Cũ / Trầy xước';
      case 'damaged':
        return 'Hư hỏng';
      case 'missing':
        return 'Thất lạc';
      default:
        return 'Bình thường';
    }
  }

  factory ApartmentAssetModel.fromJson(Map<String, dynamic> json) {
    return ApartmentAssetModel(
      id: json['id'] as String,
      apartmentId: json['apartment_id'] as String,
      buildingId: (json['building_id'] ?? '') as String,
      roomArea: (json['room_area'] ?? 'living_room') as String,
      name: json['name'] as String,
      assetCode: json['asset_code'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      condition: (json['condition'] ?? 'good') as String,
      replacementPrice: (json['replacement_price'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      'building_id': buildingId,
      'room_area': roomArea,
      'name': name,
      if (assetCode != null) 'asset_code': assetCode,
      'quantity': quantity,
      'condition': condition,
      'replacement_price': replacementPrice,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  ApartmentAssetModel copyWith({
    String? id,
    String? apartmentId,
    String? buildingId,
    String? roomArea,
    String? name,
    String? assetCode,
    int? quantity,
    String? condition,
    double? replacementPrice,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApartmentAssetModel(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      buildingId: buildingId ?? this.buildingId,
      roomArea: roomArea ?? this.roomArea,
      name: name ?? this.name,
      assetCode: assetCode ?? this.assetCode,
      quantity: quantity ?? this.quantity,
      condition: condition ?? this.condition,
      replacementPrice: replacementPrice ?? this.replacementPrice,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
