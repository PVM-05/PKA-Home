class ApartmentModel {
  final String id;
  final String code;
  final double? area;
  final bool isEmpty;

  ApartmentModel({
    required this.id,
    required this.code,
    this.area,
    this.isEmpty = true,
  });

  factory ApartmentModel.fromJson(Map<String, dynamic> json) {
    return ApartmentModel(
      id: json['id'] as String,
      code: json['code'] as String,
      area: json['area'] != null ? (json['area'] as num).toDouble() : null,
      isEmpty: json['is_empty'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'area': area,
      'is_empty': isEmpty,
    };
  }
}
