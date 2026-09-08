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
    final code = json['code'] as String? ?? '';
    final buildingCode = (json['building_code'] as String?) ??
        (code.isNotEmpty ? code.substring(0, 1).toUpperCase() : '');
    final floorNumber = (json['floor_number'] as int?) ??
        (code.length >= 3 ? int.tryParse(code.substring(1, 3)) ?? 1 : 1);

    return ApartmentModel(
      id: json['id'] as String? ?? '',
      code: code,
      buildingCode: buildingCode,
      floorNumber: floorNumber,
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
