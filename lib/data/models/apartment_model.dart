class ApartmentModel {
  final String id;
  final String code;
  final String buildingCode;
  final int floorNumber;
  final double? area;
  final bool isEmpty;
  final double electricReading;
  final double waterReading;

  ApartmentModel({
    required this.id,
    required this.code,
    required this.buildingCode,
    required this.floorNumber,
    this.area,
    this.isEmpty = true,
    this.electricReading = 0,
    this.waterReading = 0,
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
      electricReading: json['electric_reading'] != null ? (json['electric_reading'] as num).toDouble() : 0,
      waterReading: json['water_reading'] != null ? (json['water_reading'] as num).toDouble() : 0,
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
      'electric_reading': electricReading,
      'water_reading': waterReading,
    };
  }

  ApartmentModel copyWith({
    String? id,
    String? code,
    String? buildingCode,
    int? floorNumber,
    double? area,
    bool? isEmpty,
    double? electricReading,
    double? waterReading,
  }) {
    return ApartmentModel(
      id: id ?? this.id,
      code: code ?? this.code,
      buildingCode: buildingCode ?? this.buildingCode,
      floorNumber: floorNumber ?? this.floorNumber,
      area: area ?? this.area,
      isEmpty: isEmpty ?? this.isEmpty,
      electricReading: electricReading ?? this.electricReading,
      waterReading: waterReading ?? this.waterReading,
    );
  }
}
