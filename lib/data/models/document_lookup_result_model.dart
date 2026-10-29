import '../../core/utils/vietnamese_currency_text_formatter.dart';

/// Model đại diện cho kết quả tra cứu tính xác thực của Hóa đơn hoặc Biên lai điện tử (Milestone C4)
class DocumentLookupResultModel {
  final bool isValid;
  final String? lookupCode;
  final String? documentType;
  final String? invoiceId;
  final String? period;
  final String? apartmentCode;
  final String? buildingName;
  final String? buildingCode;
  final num? totalAmount;
  final String? formattedAmount;
  final String? status;
  final String? statusText;
  final DateTime? issuedDate;
  final DateTime? paidDate;
  final String? paymentMethod;
  final String? issuer;
  final String? message;

  const DocumentLookupResultModel({
    required this.isValid,
    this.lookupCode,
    this.documentType,
    this.invoiceId,
    this.period,
    this.apartmentCode,
    this.buildingName,
    this.buildingCode,
    this.totalAmount,
    this.formattedAmount,
    this.status,
    this.statusText,
    this.issuedDate,
    this.paidDate,
    this.paymentMethod,
    this.issuer,
    this.message,
  });

  /// Factory tạo đối tượng khi tra cứu thất bại hoặc chứng từ không hợp lệ
  factory DocumentLookupResultModel.invalid(
    String message, {
    String? lookupCode,
  }) {
    return DocumentLookupResultModel(
      isValid: false,
      lookupCode: lookupCode,
      message: message,
    );
  }

  /// Khởi tạo từ Map/JSON trả về từ RPC `verify_document_lookup`
  factory DocumentLookupResultModel.fromJson(Map<String, dynamic> json) {
    final bool valid = json['valid'] == true ||
        json['is_valid'] == true ||
        json['isValid'] == true;

    final String? lookupCode =
        json['lookup_code'] as String? ?? json['lookupCode'] as String?;

    final String? docType = json['document_type_display'] as String? ??
        json['document_type'] as String? ??
        json['documentType'] as String?;

    final num? amount = json['total_amount'] as num? ?? json['totalAmount'] as num?;

    final String? rawStatus = json['status'] as String?;
    final String? statusText = json['status_text'] as String? ??
        json['statusText'] as String? ??
        _resolveStatusText(rawStatus);

    final String? formattedAmount = json['formatted_amount'] as String? ??
        json['formattedAmount'] as String? ??
        (amount != null ? VietnameseCurrencyTextFormatter.format(amount) : null);

    final DateTime? issuedDate = _parseDateTime(
      json['issued_date'] ?? json['due_date'] ?? json['issuedDate'],
    );

    final DateTime? paidDate = _parseDateTime(
      json['paid_date'] ?? json['paid_at'] ?? json['paidDate'],
    );

    return DocumentLookupResultModel(
      isValid: valid,
      lookupCode: lookupCode,
      documentType: docType,
      invoiceId: json['invoice_id'] as String? ?? json['invoiceId'] as String?,
      period: json['period'] as String?,
      apartmentCode: json['apartment_code'] as String? ?? json['apartmentCode'] as String?,
      buildingName: json['building_name'] as String? ?? json['buildingName'] as String?,
      buildingCode: json['building_code'] as String? ?? json['buildingCode'] as String?,
      totalAmount: amount,
      formattedAmount: formattedAmount,
      status: rawStatus,
      statusText: statusText,
      issuedDate: issuedDate,
      paidDate: paidDate,
      paymentMethod: json['payment_method'] as String? ?? json['paymentMethod'] as String?,
      issuer: json['issuer'] as String? ?? json['organization_name'] as String?,
      message: json['message'] as String?,
    );
  }

  /// Chuyển đổi sang Map/JSON
  Map<String, dynamic> toJson() {
    return {
      'valid': isValid,
      if (lookupCode != null) 'lookup_code': lookupCode,
      if (documentType != null) 'document_type': documentType,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (period != null) 'period': period,
      if (apartmentCode != null) 'apartment_code': apartmentCode,
      if (buildingName != null) 'building_name': buildingName,
      if (buildingCode != null) 'building_code': buildingCode,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (formattedAmount != null) 'formatted_amount': formattedAmount,
      if (status != null) 'status': status,
      if (statusText != null) 'status_text': statusText,
      if (issuedDate != null) 'issued_date': issuedDate?.toIso8601String(),
      if (paidDate != null) 'paid_date': paidDate?.toIso8601String(),
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (issuer != null) 'issuer': issuer,
      if (message != null) 'message': message,
    };
  }

  static String? _resolveStatusText(String? status) {
    if (status == null) return null;
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Đã thanh toán / Đã thu tiền';
      case 'unpaid':
        return 'Chưa thanh toán';
      case 'overdue':
        return 'Quá hạn thanh toán';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DocumentLookupResultModel copyWith({
    bool? isValid,
    String? lookupCode,
    String? documentType,
    String? invoiceId,
    String? period,
    String? apartmentCode,
    String? buildingName,
    String? buildingCode,
    num? totalAmount,
    String? formattedAmount,
    String? status,
    String? statusText,
    DateTime? issuedDate,
    DateTime? paidDate,
    String? paymentMethod,
    String? issuer,
    String? message,
  }) {
    return DocumentLookupResultModel(
      isValid: isValid ?? this.isValid,
      lookupCode: lookupCode ?? this.lookupCode,
      documentType: documentType ?? this.documentType,
      invoiceId: invoiceId ?? this.invoiceId,
      period: period ?? this.period,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      buildingName: buildingName ?? this.buildingName,
      buildingCode: buildingCode ?? this.buildingCode,
      totalAmount: totalAmount ?? this.totalAmount,
      formattedAmount: formattedAmount ?? this.formattedAmount,
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      issuedDate: issuedDate ?? this.issuedDate,
      paidDate: paidDate ?? this.paidDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      issuer: issuer ?? this.issuer,
      message: message ?? this.message,
    );
  }
}
