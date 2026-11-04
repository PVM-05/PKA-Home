// Hợp đồng RPC cho Nhóm Vận Hành, AI Triage, Lễ Tân & Bưu Kiện

// -------------------------------------------------------------
// 1. Phân Tích & Phân Công Sự Cố AI (triage_and_auto_assign_issue)
// -------------------------------------------------------------
class TriageIssueReportRequestDto {
  final String issueId;
  final bool autoAssign;

  const TriageIssueReportRequestDto({
    required this.issueId,
    this.autoAssign = true,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_issue_id': issueId,
      'p_auto_assign': autoAssign,
    };
  }
}

class TriageIssueReportResponseDto {
  final bool success;
  final String? issueId;
  final bool autoAssigned;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final String? category;
  final String? priority;
  final bool isHazardous;
  final String message;

  const TriageIssueReportResponseDto({
    required this.success,
    this.issueId,
    this.autoAssigned = false,
    this.assignedStaffId,
    this.assignedStaffName,
    this.category,
    this.priority,
    this.isHazardous = false,
    required this.message,
  });

  factory TriageIssueReportResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const TriageIssueReportResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return TriageIssueReportResponseDto(
      success: map['success'] == true,
      issueId: map['issue_id'] as String?,
      autoAssigned: map['auto_assigned'] == true,
      assignedStaffId: map['assigned_staff_id'] as String?,
      assignedStaffName: map['assigned_staff_name'] as String?,
      category: map['category'] as String?,
      priority: map['priority'] as String?,
      isHazardous: map['is_hazardous'] == true,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 2. Check-In Khách Ra Vào (check_in_visitor_pass)
// -------------------------------------------------------------
class VisitorPassCheckInRequestDto {
  final String passCode;
  final String guardId;

  const VisitorPassCheckInRequestDto({
    required this.passCode,
    required this.guardId,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_pass_code': passCode,
      'p_guard_id': guardId,
    };
  }
}

class VisitorPassCheckInResponseDto {
  final bool success;
  final String? passId;
  final String? passCode;
  final String? visitorName;
  final String? checkedInAt;
  final String message;

  const VisitorPassCheckInResponseDto({
    required this.success,
    this.passId,
    this.passCode,
    this.visitorName,
    this.checkedInAt,
    required this.message,
  });

  factory VisitorPassCheckInResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const VisitorPassCheckInResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return VisitorPassCheckInResponseDto(
      success: map['success'] == true,
      passId: map['pass_id'] as String?,
      passCode: map['pass_code'] as String?,
      visitorName: map['visitor_name'] as String?,
      checkedInAt: map['checked_in_at'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 3. Check-Out Khách Ra Vào (check_out_visitor_pass)
// -------------------------------------------------------------
class VisitorPassCheckOutRequestDto {
  final String passCode;
  final String guardId;

  const VisitorPassCheckOutRequestDto({
    required this.passCode,
    required this.guardId,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_pass_code': passCode,
      'p_guard_id': guardId,
    };
  }
}

class VisitorPassCheckOutResponseDto {
  final bool success;
  final String? passId;
  final String? passCode;
  final String? visitorName;
  final String? checkedOutAt;
  final String message;

  const VisitorPassCheckOutResponseDto({
    required this.success,
    this.passId,
    this.passCode,
    this.visitorName,
    this.checkedOutAt,
    required this.message,
  });

  factory VisitorPassCheckOutResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const VisitorPassCheckOutResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return VisitorPassCheckOutResponseDto(
      success: map['success'] == true,
      passId: map['pass_id'] as String?,
      passCode: map['pass_code'] as String?,
      visitorName: map['visitor_name'] as String?,
      checkedOutAt: map['checked_out_at'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 4. Phát & Nhận Kiện Hàng (collect_parcel)
// -------------------------------------------------------------
class CollectParcelRequestDto {
  final String parcelId;
  final String pickupPin;
  final String staffId;
  final String collectedBy;

  const CollectParcelRequestDto({
    required this.parcelId,
    required this.pickupPin,
    required this.staffId,
    this.collectedBy = 'Cư dân',
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_parcel_id': parcelId,
      'p_pickup_pin': pickupPin,
      'p_staff_id': staffId,
      'p_collected_by': collectedBy,
    };
  }
}

class CollectParcelResponseDto {
  final bool success;
  final String? parcelId;
  final String? parcelCode;
  final String? collectedAt;
  final String message;

  const CollectParcelResponseDto({
    required this.success,
    this.parcelId,
    this.parcelCode,
    this.collectedAt,
    required this.message,
  });

  factory CollectParcelResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const CollectParcelResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return CollectParcelResponseDto(
      success: map['success'] == true,
      parcelId: map['parcel_id'] as String?,
      parcelCode: map['parcel_code'] as String?,
      collectedAt: map['collected_at'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 5. Phát Hiện Bất Thường Chỉ Số (detect_meter_reading_anomaly)
// -------------------------------------------------------------
class DetectMeterAnomalyRequestDto {
  final String meterId;
  final double currentReading;
  final String readingDate; // YYYY-MM-DD

  const DetectMeterAnomalyRequestDto({
    required this.meterId,
    required this.currentReading,
    required this.readingDate,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_meter_id': meterId,
      'p_current_reading': currentReading,
      'p_reading_date': readingDate,
    };
  }
}

class DetectMeterAnomalyResponseDto {
  final bool success;
  final bool isAnomaly;
  final double previousReading;
  final double consumption;
  final double? avgConsumption;
  final double? deviationPercent;
  final String reason;

  const DetectMeterAnomalyResponseDto({
    required this.success,
    required this.isAnomaly,
    required this.previousReading,
    required this.consumption,
    this.avgConsumption,
    this.deviationPercent,
    required this.reason,
  });

  factory DetectMeterAnomalyResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const DetectMeterAnomalyResponseDto(
        success: false,
        isAnomaly: false,
        previousReading: 0.0,
        consumption: 0.0,
        reason: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return DetectMeterAnomalyResponseDto(
      success: map['success'] == true,
      isAnomaly: map['is_anomaly'] == true,
      previousReading: (map['previous_reading'] as num?)?.toDouble() ?? 0.0,
      consumption: (map['consumption'] as num?)?.toDouble() ?? 0.0,
      avgConsumption: (map['avg_consumption'] as num?)?.toDouble(),
      deviationPercent: (map['deviation_percent'] as num?)?.toDouble(),
      reason: map['reason'] as String? ?? '',
    );
  }
}
