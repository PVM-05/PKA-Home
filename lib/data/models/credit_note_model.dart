import 'package:intl/intl.dart';

class CreditNoteModel {
  final String id;
  final String creditNoteCode;
  final String buildingId;
  final String apartmentId;
  final String? invoiceId;
  final String noteType;
  final double amount;
  final String reason;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;

  const CreditNoteModel({
    required this.id,
    required this.creditNoteCode,
    required this.buildingId,
    required this.apartmentId,
    this.invoiceId,
    required this.noteType,
    required this.amount,
    required this.reason,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
  });

  factory CreditNoteModel.fromJson(Map<String, dynamic> json) {
    return CreditNoteModel(
      id: json['id'] as String? ?? '',
      creditNoteCode: json['credit_note_code'] as String? ?? '',
      buildingId: json['building_id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      invoiceId: json['invoice_id'] as String?,
      noteType: json['note_type'] as String? ?? 'CREDIT',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'APPROVED',
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'credit_note_code': creditNoteCode,
      'building_id': buildingId,
      'apartment_id': apartmentId,
      'invoice_id': invoiceId,
      'note_type': noteType,
      'amount': amount,
      'reason': reason,
      'status': status,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isApproved => status == 'APPROVED';

  String get noteTypeVietnamese =>
      noteType == 'CREDIT' ? 'Giảm trừ nợ' : 'Truy thu nợ';

  String get formattedAmount {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);
  }

  String get formattedCreatedAt {
    return DateFormat('dd/MM/yyyy').format(createdAt);
  }

  String get formattedCreatedAtWithTime {
    return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  }
}
