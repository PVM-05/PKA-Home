class ApartmentModel {
  final String id;
  final String code;
  final String buildingCode;
  final int floorNumber;
  final double? area;
  final bool isEmpty;

  ApartmentModel({
    required this.id,
    required this.code,
    required this.buildingCode,
    required this.floorNumber,
    this.area,
    this.isEmpty = true,
  });

  factory ApartmentModel.fromJson(Map<String, dynamic> json) {
    return ApartmentModel(
      id: json['id'] as String,
      code: json['code'] as String,
      buildingCode: json['building_code'] as String,
      floorNumber: json['floor_number'] as int,
      area: json['area'] != null ? (json['area'] as num).toDouble() : null,
      isEmpty: json['is_empty'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'building_code': buildingCode,
      'floor_number': floorNumber,
      'area': area,
      'is_empty': isEmpty,
    };
  }
}
