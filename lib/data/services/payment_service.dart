import '../../core/supabase_config.dart';
import '../models/building_payment_config_model.dart';
import '../models/sepay_webhook_payload_model.dart';

enum PaymentType { invoice, service }

class PaymentResult {
  final bool success;
  final bool isPending;
  final String status;
  final String transactionCode;
  final String transactionId;
  final double amount;
  final String title;
  final DateTime paidAt;
  final String? errorMessage;

  PaymentResult({
    required this.success,
    this.isPending = false,
    this.status = 'SUCCESS',
    required this.transactionCode,
    required this.transactionId,
    required this.amount,
    required this.title,
    required this.paidAt,
    this.errorMessage,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String?;
    final isExplicitPending = (json['is_pending'] as bool?) == true;

    final String statusVal;
    if (rawStatus != null && rawStatus.isNotEmpty) {
      statusVal = rawStatus.toUpperCase();
    } else if (isExplicitPending) {
      statusVal = 'PENDING';
    } else {
      statusVal = 'UNKNOWN';
    }

    final isPendingVal = statusVal == 'PENDING';
    final isSuccessVal = (json['success'] as bool? ?? false) && statusVal == 'SUCCESS';
    final hasValidState = isSuccessVal || isPendingVal;

    final txCode = (json['receipt_number'] as String?) ??
        (json['transaction_code'] as String?) ??
        (json['reference_code'] as String?) ??
        '';

    return PaymentResult(
      success: hasValidState,
      isPending: isPendingVal,
      status: statusVal,
      transactionCode: txCode,
      transactionId: json['transaction_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? 'Giao dịch',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String).toLocal() : DateTime.now(),
      errorMessage: hasValidState
          ? (json['message'] as String? ?? json['error'] as String?)
          : (json['message'] as String? ?? json['error'] as String? ?? 'Dữ liệu phản hồi thiếu trạng thái giao dịch hợp lệ.'),
    );
  }
}

/// Dịch vụ thanh toán thực tế (Decoupled Production Payment Service)
class PaymentService {
  final bool isMockMode;

  const PaymentService({this.isMockMode = false});

  /// Khởi tạo ý định thanh toán thực tế (Payment Intent)
  /// Trả về trạng thái PENDING, mã VietQR và mã đối soát ngân hàng
  Future<PaymentResult> createPaymentIntent({
    required PaymentType type,
    required String referenceId,
    String paymentMethod = 'bank_transfer',
  }) async {
    if (isMockMode) {
      return PaymentResult(
        success: true,
        isPending: true,
        status: 'PENDING',
        transactionCode: 'TX-${DateTime.now().millisecondsSinceEpoch}',
        transactionId: 'tx-mock-01',
        amount: 1500000.0,
        title: 'Thanh toán phí dịch vụ',
        paidAt: DateTime.now(),
      );
    }

    final typeString = type == PaymentType.invoice ? 'INVOICE' : 'SERVICE';

    final res = await SupabaseConfig.client.rpc(
      'create_payment_intent',
      params: {
        'p_reference_id': referenceId,
        'p_payment_type': typeString,
        'p_payment_method': paymentMethod,
      },
    );

    return PaymentResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Gửi yêu cầu thanh toán (Khởi tạo Payment Intent PENDING an toàn)
  Future<PaymentResult> pay({
    required PaymentType type,
    required String referenceId,
    String paymentMethod = 'bank_transfer',
    String outcome = 'PENDING',
    String? failureReason,
  }) async {
    return createPaymentIntent(
      type: type,
      referenceId: referenceId,
      paymentMethod: paymentMethod,
    );
  }

  /// Xử lý Webhook biến động số dư từ cổng SePay (sepay.vn)
  Future<Map<String, dynamic>> processSepayWebhook(
    SepayWebhookPayloadModel payload, {
    String? apiKey,
  }) async {
    if (isMockMode) {
      if (!payload.isIncomingTransfer) {
        return {
          'success': true,
          'status': 'IGNORED_OUTGOING',
          'message': 'Giao dịch chi tiền ra, bỏ qua an toàn.',
        };
      }
      final code = payload.extractedPaymentCode;
      if (code != null && code.isNotEmpty) {
        return {
          'success': true,
          'status': 'SUCCESS',
          'invoice_id': 'inv-mock-01',
          'receipt_number': 'REC-${DateTime.now().millisecondsSinceEpoch}',
          'message': 'Gạch nợ hóa đơn tự động qua SePay Webhook thành công.',
        };
      }
      return {
        'success': false,
        'status': 'UNMATCHED',
        'message': 'Không tìm thấy hóa đơn khớp với nội dung chuyển khoản SePay.',
      };
    }

    final res = await SupabaseConfig.client.rpc(
      'process_sepay_webhook',
      params: {
        'p_payload': payload.toJson(),
        'p_api_key': apiKey,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// Lấy cấu hình tài khoản ngân hàng & SePay của tòa nhà
  Future<BuildingPaymentConfigModel?> fetchBuildingPaymentConfig(String buildingId) async {
    if (isMockMode) {
      return BuildingPaymentConfigModel(
        id: 'cfg-mock',
        buildingId: buildingId,
        bankName: 'MBBank',
        bankAccountNumber: '0388888888',
        bankAccountName: 'BAN QUAN LY PKA HOME',
        bankBin: '970422',
      );
    }
    try {
      final res = await SupabaseConfig.client
          .from('building_payment_configs')
          .select()
          .eq('building_id', buildingId)
          .eq('is_active', true)
          .maybeSingle();

      if (res == null) return null;
      return BuildingPaymentConfigModel.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  /// Xử lý Webhook biến động số dư ngân hàng chung
  Future<Map<String, dynamic>> processBankPaymentWebhook(Map<String, dynamic> payload) async {
    final res = await SupabaseConfig.client.rpc(
      'process_bank_payment_webhook',
      params: {
        'p_payload': payload,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }
}
