/// Model biểu diễn Phiếu bảo trì & Nhật ký sửa chữa thiết bị tòa nhà (Equipment Maintenance Task)
class EquipmentMaintenanceTaskModel {
  final String id;
  final String equipmentId;
  final String? equipmentCode;
  final String? equipmentName;
  final String title;
  final String taskType;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final String? technicianId;
  final String? technicianName;
  final String? vendorName;
  final String? vendorContact;
  final double cost;
  final String status;
  final bool affectsService;
  final String? serviceInterruptionNote;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EquipmentMaintenanceTaskModel({
    required this.id,
    required this.equipmentId,
    this.equipmentCode,
    this.equipmentName,
    required this.title,
    this.taskType = 'scheduled',
    required this.scheduledStart,
    required this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    this.technicianId,
    this.technicianName,
    this.vendorName,
    this.vendorContact,
    this.cost = 0,
    this.status = 'pending',
    this.affectsService = false,
    this.serviceInterruptionNote,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory EquipmentMaintenanceTaskModel.fromJson(Map<String, dynamic> json) {
    // Trích xuất quan hệ join nếu có (building_equipments, users)
    String? eqCode;
    String? eqName;
    if (json['building_equipments'] is Map<String, dynamic>) {
      final eq = json['building_equipments'] as Map<String, dynamic>;
      eqCode = eq['code'] as String?;
      eqName = eq['name'] as String?;
    } else {
      eqCode = json['equipment_code'] as String?;
      eqName = json['equipment_name'] as String?;
    }

    String? techName;
    if (json['users'] is Map<String, dynamic>) {
      final user = json['users'] as Map<String, dynamic>;
      techName = user['full_name'] as String?;
    } else {
      techName = json['technician_name'] as String?;
    }

    return EquipmentMaintenanceTaskModel(
      id: json['id'] as String? ?? '',
      equipmentId: json['equipment_id'] as String? ?? '',
      equipmentCode: eqCode,
      equipmentName: eqName,
      title: json['title'] as String? ?? '',
      taskType: json['task_type'] as String? ?? 'scheduled',
      scheduledStart: json['scheduled_start'] != null
          ? DateTime.parse(json['scheduled_start'].toString())
          : DateTime.now(),
      scheduledEnd: json['scheduled_end'] != null
          ? DateTime.parse(json['scheduled_end'].toString())
          : DateTime.now().add(const Duration(hours: 2)),
      actualStart: json['actual_start'] != null
          ? DateTime.tryParse(json['actual_start'].toString())
          : null,
      actualEnd: json['actual_end'] != null
          ? DateTime.tryParse(json['actual_end'].toString())
          : null,
      technicianId: json['technician_id'] as String?,
      technicianName: techName,
      vendorName: json['vendor_name'] as String?,
      vendorContact: json['vendor_contact'] as String?,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      affectsService: json['affects_service'] as bool? ?? false,
      serviceInterruptionNote: json['service_interruption_note'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipment_id': equipmentId,
      'title': title,
      'task_type': taskType,
      'scheduled_start': scheduledStart.toIso8601String(),
      'scheduled_end': scheduledEnd.toIso8601String(),
      'actual_start': actualStart?.toIso8601String(),
      'actual_end': actualEnd?.toIso8601String(),
      'technician_id': technicianId,
      'vendor_name': vendorName,
      'vendor_contact': vendorContact,
      'cost': cost,
      'status': status,
      'affects_service': affectsService,
      'service_interruption_note': serviceInterruptionNote,
      'notes': notes,
      'created_by': createdBy,
    };
  }

  EquipmentMaintenanceTaskModel copyWith({
    String? id,
    String? equipmentId,
    String? equipmentCode,
    String? equipmentName,
    String? title,
    String? taskType,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DateTime? actualStart,
    DateTime? actualEnd,
    String? technicianId,
    String? technicianName,
    String? vendorName,
    String? vendorContact,
    double? cost,
    String? status,
    bool? affectsService,
    String? serviceInterruptionNote,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentMaintenanceTaskModel(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentCode: equipmentCode ?? this.equipmentCode,
      equipmentName: equipmentName ?? this.equipmentName,
      title: title ?? this.title,
      taskType: taskType ?? this.taskType,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      vendorName: vendorName ?? this.vendorName,
      vendorContact: vendorContact ?? this.vendorContact,
      cost: cost ?? this.cost,
      status: status ?? this.status,
      affectsService: affectsService ?? this.affectsService,
      serviceInterruptionNote: serviceInterruptionNote ?? this.serviceInterruptionNote,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get taskTypeDisplayName {
    switch (taskType) {
      case 'scheduled':
        return 'Định kỳ';
      case 'unscheduled':
        return 'Đột xuất / Sự cố';
      case 'inspection':
        return 'Kiểm định an toàn';
      default:
        return taskType;
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Chờ thực hiện';
      case 'in_progress':
        return 'Đang bảo dưỡng';
      case 'completed':
        return 'Đã hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
}
