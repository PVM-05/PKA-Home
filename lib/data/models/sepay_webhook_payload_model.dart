/// Model strongly-typed đại diện cho Webhook Payload từ cổng SePay (sepay.vn)
class SepayWebhookPayloadModel {
  final String id;
  final String? gateway;
  final DateTime? transactionDate;
  final String? accountNumber;
  final String? code;
  final String content;
  final String transferType; // 'in' (tiền vào) hoặc 'out' (tiền ra)
  final double transferAmount;
  final double? accumulated;
  final String? subAccount;
  final String? referenceCode;
  final String? description;

  const SepayWebhookPayloadModel({
    required this.id,
    this.gateway,
    this.transactionDate,
    this.accountNumber,
    this.code,
    required this.content,
    required this.transferType,
    required this.transferAmount,
    this.accumulated,
    this.subAccount,
    this.referenceCode,
    this.description,
  });

  /// Kiểm tra có phải giao dịch nhận tiền vào tài khoản
  bool get isIncomingTransfer => transferType.trim().toLowerCase() == 'in';

  /// Khóa chống trùng lặp Idempotency Key duy nhất
  String get effectiveIdempotencyKey {
    return id.isNotEmpty ? id : (referenceCode ?? '');
  }

  /// Trích xuất tự động mã hóa đơn (INV...) hoặc mã đặt tiện ích (AMN...) từ nội dung
  String? get extractedPaymentCode {
    if (!isIncomingTransfer) return null;

    final text = '$content ${description ?? ''} ${code ?? ''}';
    final regExp = RegExp(r'(INV|AMN)\d{4}[A-Za-z0-9]+', caseSensitive: false);
    final match = regExp.firstMatch(text);
    return match?.group(0)?.toUpperCase();
  }

  factory SepayWebhookPayloadModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final dateRaw = json['transactionDate'] ?? json['transaction_date'];
    if (dateRaw != null) {
      if (dateRaw is DateTime) {
        parsedDate = dateRaw;
      } else {
        parsedDate = DateTime.tryParse(dateRaw.toString());
      }
    }

    final rawId = json['id'] ?? json['transaction_id'] ?? json['reference'];

    return SepayWebhookPayloadModel(
      id: rawId?.toString() ?? '',
      gateway: json['gateway'] as String?,
      transactionDate: parsedDate,
      accountNumber: (json['accountNumber'] ?? json['account_number']) as String?,
      code: json['code'] as String?,
      content: (json['content'] ?? json['description'] ?? '') as String,
      transferType: (json['transferType'] ?? json['transfer_type'] ?? 'in') as String,
      transferAmount: (json['transferAmount'] ?? json['amount'] as num?)?.toDouble() ?? 0.0,
      accumulated: (json['accumulated'] as num?)?.toDouble(),
      subAccount: (json['subAccount'] ?? json['sub_account']) as String?,
      referenceCode: (json['referenceCode'] ?? json['reference_code']) as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': int.tryParse(id) ?? id,
      'gateway': gateway,
      'transactionDate': transactionDate?.toIso8601String(),
      'accountNumber': accountNumber,
      'code': code,
      'content': content,
      'transferType': transferType,
      'transferAmount': transferAmount,
      'accumulated': accumulated,
      'subAccount': subAccount,
      'referenceCode': referenceCode,
      'description': description,
    };
  }

  SepayWebhookPayloadModel copyWith({
    String? id,
    String? gateway,
    DateTime? transactionDate,
    String? accountNumber,
    String? code,
    String? content,
    String? transferType,
    double? transferAmount,
    double? accumulated,
    String? subAccount,
    String? referenceCode,
    String? description,
  }) {
    return SepayWebhookPayloadModel(
      id: id ?? this.id,
      gateway: gateway ?? this.gateway,
      transactionDate: transactionDate ?? this.transactionDate,
      accountNumber: accountNumber ?? this.accountNumber,
      code: code ?? this.code,
      content: content ?? this.content,
      transferType: transferType ?? this.transferType,
      transferAmount: transferAmount ?? this.transferAmount,
      accumulated: accumulated ?? this.accumulated,
      subAccount: subAccount ?? this.subAccount,
      referenceCode: referenceCode ?? this.referenceCode,
      description: description ?? this.description,
    );
  }
}
