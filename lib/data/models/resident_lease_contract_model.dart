import 'package:intl/intl.dart';

class ResidentLeaseContractModel {
  final String id;
  final String userId;
  final String apartmentId;
  final String fullName;
  final String? phone;
  final String relationRole; // 'owner', 'tenant', 'member'
  final String status; // 'active', 'expired', 'terminated'
  final DateTime startDate;
  final DateTime? endDate;
  final double depositAmount;
  final String? contractNumber;
  final String? note;
  final DateTime createdAt;

  const ResidentLeaseContractModel({
    required this.id,
    required this.userId,
    required this.apartmentId,
    required this.fullName,
    this.phone,
    required this.relationRole,
    required this.status,
    required this.startDate,
    this.endDate,
    this.depositAmount = 0.0,
    this.contractNumber,
    this.note,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  String get formattedDeposit {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(depositAmount);
  }

  String get formattedStartDate => DateFormat('dd/MM/yyyy').format(startDate);

  String get formattedEndDate {
    if (endDate == null) return 'Không xác định';
    return DateFormat('dd/MM/yyyy').format(endDate!);
  }

  String get displayRole {
    switch (relationRole.toLowerCase()) {
      case 'owner':
        return 'Chủ hộ';
      case 'tenant':
        return 'Người thuê';
      case 'member':
      default:
        return 'Thành viên';
    }
  }

  String get displayStatus {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Đang lưu trú';
      case 'expired':
        return 'Đã hết hạn';
      case 'terminated':
        return 'Đã kết thúc';
      default:
        return 'Không xác định';
    }
  }

  factory ResidentLeaseContractModel.fromJson(Map<String, dynamic> json) {
    return ResidentLeaseContractModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Chưa xác định',
      phone: json['phone'] as String?,
      relationRole: json['relation_role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'active',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      contractNumber: json['contract_number'] as String?,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'apartment_id': apartmentId,
      'full_name': fullName,
      'phone': phone,
      'relation_role': relationRole,
      'status': status,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'deposit_amount': depositAmount,
      'contract_number': contractNumber,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
