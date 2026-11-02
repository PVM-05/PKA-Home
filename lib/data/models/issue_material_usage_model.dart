import 'package:intl/intl.dart';

class IssueMaterialUsageModel {
  final String id;
  final String issueReportId;
  final String materialId;
  final String materialName;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double totalAmount;
  final bool isChargeable;
  final String? note;
  final DateTime createdAt;

  const IssueMaterialUsageModel({
    required this.id,
    required this.issueReportId,
    required this.materialId,
    required this.materialName,
    required this.quantity,
    this.unit = 'cái',
    required this.unitPrice,
    required this.totalAmount,
    this.isChargeable = false,
    this.note,
    required this.createdAt,
  });

  String get totalAmountFormatted {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return formatter.format(totalAmount).replaceAll('\u00A0', ' ').trim();
  }

  String get chargeableDisplayName => isChargeable ? 'Tính phí căn hộ' : 'Chi phí tòa nhà';

  factory IssueMaterialUsageModel.fromJson(Map<String, dynamic> json) {
    final matJson = json['maintenance_materials'] as Map<String, dynamic>?;
    final name = (json['material_name'] as String?) ?? (matJson?['name'] as String?) ?? 'Vật tư sửa chữa';
    final unitStr = (json['unit'] as String?) ?? (matJson?['unit'] as String?) ?? 'cái';

    return IssueMaterialUsageModel(
      id: json['id'] as String? ?? '',
      issueReportId: json['issue_report_id'] as String? ?? '',
      materialId: json['material_id'] as String? ?? '',
      materialName: name,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unit: unitStr,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      isChargeable: json['is_chargeable'] as bool? ?? false,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_report_id': issueReportId,
      'material_id': materialId,
      'material_name': materialName,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'is_chargeable': isChargeable,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

