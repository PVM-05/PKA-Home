import 'handover_item_model.dart';

class ApartmentHandoverModel {
  final String id;
  final String apartmentId;
  final String buildingId;
  final String? residentId;
  final String? contractId;
  final String handoverType; // move_in, move_out
  final String reportCode;
  final DateTime handoverDate;
  final String conductedBy;
  final double initialElectricityReading;
  final double initialWaterReading;
  final double depositHeld;
  final double totalDeduction;
  final double depositRefund;
  final String status; // draft, pending_resident, confirmed, disputed, cancelled
  final String? staffSignatureUrl;
  final DateTime? staffSignedAt;
  final String? residentSignatureUrl;
  final DateTime? residentSignedAt;
  final String? residentNotes;
  final String? staffNotes;
  final String? pdfUrl;
  final String lookupCode;
  final List<HandoverItemModel> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Metadata bổ sung nếu nạp qua join
  final String? apartmentCode;
  final String? residentName;
  final String? staffName;

  const ApartmentHandoverModel({
    required this.id,
    required this.apartmentId,
    required this.buildingId,
    this.residentId,
    this.contractId,
    required this.handoverType,
    required this.reportCode,
    required this.handoverDate,
    required this.conductedBy,
    this.initialElectricityReading = 0.0,
    this.initialWaterReading = 0.0,
    this.depositHeld = 0.0,
    this.totalDeduction = 0.0,
    this.depositRefund = 0.0,
    this.status = 'draft',
    this.staffSignatureUrl,
    this.staffSignedAt,
    this.residentSignatureUrl,
    this.residentSignedAt,
    this.residentNotes,
    this.staffNotes,
    this.pdfUrl,
    required this.lookupCode,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
    this.apartmentCode,
    this.residentName,
    this.staffName,
  });

  bool get isMoveIn => handoverType == 'move_in';
  bool get isPendingResident => status == 'pending_resident';
  bool get isConfirmed => status == 'confirmed';
  bool get isDisputed => status == 'disputed';

  double get depositRefundCalculated {
    if (handoverType == 'move_out') {
      final calculated = depositHeld - totalDeduction;
      return calculated > 0 ? calculated : 0.0;
    }
    return depositRefund;
  }

  String get handoverTypeDisplayName {
    switch (handoverType) {
      case 'move_in':
        return 'Nhận nhà (Move-in)';
      case 'move_out':
        return 'Trả nhà (Move-out)';
      default:
        return 'Bàn giao';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'draft':
        return 'Bản nháp';
      case 'pending_resident':
        return 'Chờ cư dân ký';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'disputed':
        return 'Có khiếu nại';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  factory ApartmentHandoverModel.fromJson(Map<String, dynamic> json) {
    List<HandoverItemModel> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((e) => HandoverItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['handover_items'] is List) {
      parsedItems = (json['handover_items'] as List)
          .map((e) => HandoverItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ApartmentHandoverModel(
      id: json['id'] as String,
      apartmentId: json['apartment_id'] as String,
      buildingId: (json['building_id'] ?? '') as String,
      residentId: json['resident_id'] as String?,
      contractId: json['contract_id'] as String?,
      handoverType: json['handover_type'] as String,
      reportCode: json['report_code'] as String,
      handoverDate: json['handover_date'] != null
          ? DateTime.tryParse(json['handover_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      conductedBy: json['conducted_by'] as String,
      initialElectricityReading: (json['initial_electricity_reading'] as num?)?.toDouble() ?? 0.0,
      initialWaterReading: (json['initial_water_reading'] as num?)?.toDouble() ?? 0.0,
      depositHeld: (json['deposit_held'] as num?)?.toDouble() ?? 0.0,
      totalDeduction: (json['total_deduction'] as num?)?.toDouble() ?? 0.0,
      depositRefund: (json['deposit_refund'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? 'draft') as String,
      staffSignatureUrl: json['staff_signature_url'] as String?,
      staffSignedAt: json['staff_signed_at'] != null ? DateTime.tryParse(json['staff_signed_at'] as String) : null,
      residentSignatureUrl: json['resident_signature_url'] as String?,
      residentSignedAt: json['resident_signed_at'] != null ? DateTime.tryParse(json['resident_signed_at'] as String) : null,
      residentNotes: json['resident_notes'] as String?,
      staffNotes: json['staff_notes'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      lookupCode: (json['lookup_code'] ?? '') as String,
      items: parsedItems,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      apartmentCode: json['apartment_code'] as String?,
      residentName: json['resident_name'] as String?,
      staffName: json['staff_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      'building_id': buildingId,
      if (residentId != null) 'resident_id': residentId,
      if (contractId != null) 'contract_id': contractId,
      'handover_type': handoverType,
      'report_code': reportCode,
      'handover_date': handoverDate.toIso8601String().split('T').first,
      'conducted_by': conductedBy,
      'initial_electricity_reading': initialElectricityReading,
      'initial_water_reading': initialWaterReading,
      'deposit_held': depositHeld,
      'total_deduction': totalDeduction,
      'deposit_refund': depositRefund,
      'status': status,
      if (staffSignatureUrl != null) 'staff_signature_url': staffSignatureUrl,
      if (staffSignedAt != null) 'staff_signed_at': staffSignedAt!.toIso8601String(),
      if (residentSignatureUrl != null) 'resident_signature_url': residentSignatureUrl,
      if (residentSignedAt != null) 'resident_signed_at': residentSignedAt!.toIso8601String(),
      if (residentNotes != null) 'resident_notes': residentNotes,
      if (staffNotes != null) 'staff_notes': staffNotes,
      if (pdfUrl != null) 'pdf_url': pdfUrl,
      'lookup_code': lookupCode,
      if (items.isNotEmpty) 'items': items.map((e) => e.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  ApartmentHandoverModel copyWith({
    String? id,
    String? apartmentId,
    String? buildingId,
    String? residentId,
    String? contractId,
    String? handoverType,
    String? reportCode,
    DateTime? handoverDate,
    String? conductedBy,
    double? initialElectricityReading,
    double? initialWaterReading,
    double? depositHeld,
    double? totalDeduction,
    double? depositRefund,
    String? status,
    String? staffSignatureUrl,
    DateTime? staffSignedAt,
    String? residentSignatureUrl,
    DateTime? residentSignedAt,
    String? residentNotes,
    String? staffNotes,
    String? pdfUrl,
    String? lookupCode,
    List<HandoverItemModel>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? apartmentCode,
    String? residentName,
    String? staffName,
  }) {
    return ApartmentHandoverModel(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      buildingId: buildingId ?? this.buildingId,
      residentId: residentId ?? this.residentId,
      contractId: contractId ?? this.contractId,
      handoverType: handoverType ?? this.handoverType,
      reportCode: reportCode ?? this.reportCode,
      handoverDate: handoverDate ?? this.handoverDate,
      conductedBy: conductedBy ?? this.conductedBy,
      initialElectricityReading: initialElectricityReading ?? this.initialElectricityReading,
      initialWaterReading: initialWaterReading ?? this.initialWaterReading,
      depositHeld: depositHeld ?? this.depositHeld,
      totalDeduction: totalDeduction ?? this.totalDeduction,
      depositRefund: depositRefund ?? this.depositRefund,
      status: status ?? this.status,
      staffSignatureUrl: staffSignatureUrl ?? this.staffSignatureUrl,
      staffSignedAt: staffSignedAt ?? this.staffSignedAt,
      residentSignatureUrl: residentSignatureUrl ?? this.residentSignatureUrl,
      residentSignedAt: residentSignedAt ?? this.residentSignedAt,
      residentNotes: residentNotes ?? this.residentNotes,
      staffNotes: staffNotes ?? this.staffNotes,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      lookupCode: lookupCode ?? this.lookupCode,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      residentName: residentName ?? this.residentName,
      staffName: staffName ?? this.staffName,
    );
  }
}

