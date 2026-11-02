import 'package:intl/intl.dart';

class MaintenanceMaterialModel {
  final String id;
  final String? buildingId;
  final String code;
  final String name;
  final String category; // 'electrical', 'plumbing', 'construction', 'elevator', 'fire_safety', 'other'
  final String unit; // 'cái', 'mét', 'bộ', 'cuộn', 'chai'...
  final double unitPrice;
  final int stockQuantity;
  final int minStockAlert;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MaintenanceMaterialModel({
    required this.id,
    this.buildingId,
    required this.code,
    required this.name,
    this.category = 'other',
    this.unit = 'cái',
    this.unitPrice = 0.0,
    this.stockQuantity = 0,
    this.minStockAlert = 5,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => stockQuantity <= minStockAlert;

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'electrical':
        return 'Điện';
      case 'plumbing':
        return 'Nước';
      case 'construction':
        return 'Xây dựng/Nội thất';
      case 'elevator':
        return 'Thang máy';
      case 'fire_safety':
        return 'PCCC & An toàn';
      case 'other':
      default:
        return 'Khác';
    }
  }

  String get priceFormatted {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return formatter.format(unitPrice).replaceAll('\u00A0', ' ').trim();
  }

  factory MaintenanceMaterialModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceMaterialModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      unit: json['unit'] as String? ?? 'cái',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      minStockAlert: (json['min_stock_alert'] as num?)?.toInt() ?? 5,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'code': code,
      'name': name,
      'category': category,
      'unit': unit,
      'unit_price': unitPrice,
      'stock_quantity': stockQuantity,
      'min_stock_alert': minStockAlert,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  MaintenanceMaterialModel copyWith({
    String? id,
    String? buildingId,
    String? code,
    String? name,
    String? category,
    String? unit,
    double? unitPrice,
    int? stockQuantity,
    int? minStockAlert,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaintenanceMaterialModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
