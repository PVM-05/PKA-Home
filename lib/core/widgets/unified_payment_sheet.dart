import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/invoice_model.dart';
import '../../data/providers/building_provider.dart';
import '../../data/providers/payment_provider.dart';
import '../../data/providers/resident_apartment_provider.dart';
import '../../data/providers/resident_invoice_provider.dart';
import '../../data/services/payment_service.dart';
import '../config/app_environment.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/network_error_handler.dart';
import '../utils/vietqr_generator.dart';
import 'payment/payment_method_option_card.dart';
import 'payment/payment_status_steps.dart';
import 'payment/vietqr_transfer_panel.dart';

enum _PaymentStep {
  confirmation,
  processing,
  success,
  pendingConfirmation,
  failed,
}

/// Hàm tiện ích mở Bottom Sheet Thanh toán dùng chung
Future<PaymentResult?> showUnifiedPaymentSheet({
  required BuildContext context,
  required PaymentType type,
  required String referenceId,
  required String title,
  required String referenceCode,
  required double amount,
  String? buildingId,
  List<Map<String, dynamic>>? feeBreakdown,
}) {
  return showModalBottomSheet<PaymentResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => UnifiedPaymentSheet(
      type: type,
      referenceId: referenceId,
      title: title,
      referenceCode: referenceCode,
      amount: amount,
      buildingId: buildingId,
      feeBreakdown: feeBreakdown,
    ),
  );
}

class UnifiedPaymentSheet extends ConsumerStatefulWidget {
  final PaymentType type;
  final String referenceId;
  final String title;
  final String referenceCode;
  final double amount;
  final String? buildingId;
  final List<Map<String, dynamic>>? feeBreakdown;

  const UnifiedPaymentSheet({
    super.key,
    required this.type,
    required this.referenceId,
    required this.title,
    required this.referenceCode,
    required this.amount,
    this.buildingId,
    this.feeBreakdown,
  });

  @override
  ConsumerState<UnifiedPaymentSheet> createState() =>
      _UnifiedPaymentSheetState();
}

class _UnifiedPaymentSheetState extends ConsumerState<UnifiedPaymentSheet> {
  _PaymentStep _step = _PaymentStep.confirmation;
  String _selectedMethod = 'bank_transfer'; // 'bank_transfer' | 'vnpay' | 'cash'
  PaymentResult? _result;
  String? _errorMessage;
  bool _isSubmitting = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _startPayment() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _step = _PaymentStep.processing;
    });

    try {
      // Độ trễ phản hồi nghiệp vụ bảo đảm đồng bộ trạng thái
      await Future.delayed(const Duration(milliseconds: 600));

      final controller = ref.read(paymentControllerProvider);
      final res = await controller.pay(
        type: widget.type,
        referenceId: widget.referenceId,
        paymentMethod: _selectedMethod,
        outcome: 'PENDING',
      );

      if (mounted) {
        setState(() {
          _result = res;
          _errorMessage = res.errorMessage != null
              ? NetworkErrorHandler.getMessage(res.errorMessage!)
              : null;

          if (res.isPending || res.status == 'PENDING') {
            _step = _PaymentStep.pendingConfirmation;
          } else if (res.success) {
            _step = _PaymentStep.success;
          } else {
            _step = _PaymentStep.failed;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = NetworkErrorHandler.getMessage(e);
          _step = _PaymentStep.failed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _startVnpayPayment(String bldId) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _step = _PaymentStep.processing;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final memo = widget.referenceCode
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toUpperCase();
      final paymentUrl = await paymentService.createVnpayPaymentUrl(
        invoiceId: widget.referenceId,
        buildingId: bldId,
        amount: widget.amount,
        txnRef: memo,
        orderInfo: 'Thanh toan $memo',
        returnUrl: 'https://vivona.web.app/payment-result',
        isSandbox: !AppEnvironment.current.isProduction,
      );

      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        final uri = Uri.parse(paymentUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        if (mounted) {
          setState(() {
            _result = PaymentResult(
              success: true,
              isPending: true,
              status: 'PENDING',
              transactionCode: memo,
              transactionId: 'vnpay-${DateTime.now().millisecondsSinceEpoch}',
              amount: widget.amount,
              title: widget.title,
              paidAt: DateTime.now(),
              errorMessage:
                  'Đã mở cổng VNPay. Đang chờ kết quả thanh toán từ ngân hàng...',
            );
            _step = _PaymentStep.pendingConfirmation;
          });
        }
      } else {
        throw Exception('Không thể khởi tạo URL thanh toán VNPay');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = NetworkErrorHandler.getMessage(e);
          _step = _PaymentStep.failed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _handleInvoiceStatusChange(List<InvoiceModel>? invoices) {
    if (invoices == null || _step == _PaymentStep.success) return;

    final invoice = invoices.cast<InvoiceModel?>().firstWhere(
      (inv) => inv?.id == widget.referenceId,
      orElse: () => null,
    );

    if (invoice != null && invoice.status == 'paid' && mounted) {
      setState(() {
        _result = PaymentResult(
          success: true,
          status: 'SUCCESS',
          transactionCode: invoice.displayReceiptNumber,
          transactionId: invoice.transactionCode ?? invoice.id,
          amount: invoice.paidAmount ?? invoice.totalAmount,
          title: widget.title,
          paidAt: invoice.paidAt ?? DateTime.now(),
        );
        _step = _PaymentStep.success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == PaymentType.invoice) {
      ref.listen<AsyncValue<List<InvoiceModel>>>(residentInvoiceProvider, (
        previous,
        next,
      ) {
        _handleInvoiceStatusChange(next.valueOrNull);
      });
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bgColor = theme.cardTheme.color ?? colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCurrentStep(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_step) {
      case _PaymentStep.confirmation:
        return _buildConfirmationStep(context);
      case _PaymentStep.processing:
        return PaymentProcessingStep(
          amount: widget.amount,
          currencyFormat: _currencyFormat,
        );
      case _PaymentStep.pendingConfirmation:
        return PaymentPendingStep(
          result: _result,
          title: widget.title,
          amount: widget.amount,
          selectedMethod: _selectedMethod,
          currencyFormat: _currencyFormat,
          dateFormat: _dateFormat,
          onAcknowledge: () => Navigator.pop(context, _result),
        );
      case _PaymentStep.success:
        return PaymentSuccessStep(
          result: _result,
          title: widget.title,
          amount: widget.amount,
          selectedMethod: _selectedMethod,
          currencyFormat: _currencyFormat,
          dateFormat: _dateFormat,
          onDone: () => Navigator.pop(context, _result),
        );
      case _PaymentStep.failed:
        return PaymentFailedStep(
          errorMessage: _errorMessage,
          isSubmitting: _isSubmitting,
          onClose: () => Navigator.pop(context),
          onRetry: _startPayment,
        );
    }
  }

  Widget _buildConfirmationStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = AppTheme.getSemanticSuccess(context);

    // Ưu tiên 1: Tòa nhà truyền trực tiếp qua widget (ví dụ từ chi tiết hóa đơn/đặt chỗ)
    // Ưu tiên 2: Tòa nhà của căn hộ cư dân đang chọn (residentBuildingProvider)
    // Nếu cư dân đã chọn căn hộ, tuyệt đối không fallback sang activeBuildingProvider để tránh chuyển tiền nhầm tòa nhà khác
    // Chỉ fallback sang activeBuildingProvider khi không có ngữ cảnh căn hộ cư dân (ví dụ BQL đang thao tác độc lập)
    final residentBldId = ref.watch(residentBuildingIdProvider);
    final building = widget.buildingId != null && widget.buildingId!.isNotEmpty
        ? ref.watch(buildingByIdProvider(widget.buildingId!)).value
        : (residentBldId != null
              ? ref.watch(residentBuildingProvider).value
              : ref.watch(activeBuildingProvider).value);

    final targetBldId = widget.buildingId ?? residentBldId ?? building?.id;
    final sepayConfig = targetBldId != null && targetBldId.isNotEmpty
        ? ref.watch(buildingPaymentConfigProvider(targetBldId)).value
        : null;

    final hasSepayConfig =
        sepayConfig != null &&
        sepayConfig.isActive &&
        sepayConfig.bankAccountNumber.isNotEmpty;
    final hasBankConfig =
        hasSepayConfig || (building != null && building.hasValidBankAccount);
    final bankBin = hasSepayConfig
        ? sepayConfig.bankBin
        : (building?.bankBin ?? '');
    final bankName = hasSepayConfig
        ? sepayConfig.bankName
        : (building?.bankName ?? '');
    final bankAccountNumber = hasSepayConfig
        ? sepayConfig.bankAccountNumber
        : (building?.bankAccountNumber ?? '');
    final bankAccountName = hasSepayConfig
        ? sepayConfig.bankAccountName
        : (building?.bankAccountName ?? '');

    final hasVnpayConfig =
        sepayConfig != null &&
        sepayConfig.vnpayIsActive &&
        (sepayConfig.vnpayTmnCode?.isNotEmpty ?? false);

    // Chuẩn hóa memo chữ-số thuần túy (loại bỏ #, -, ký tự đặc biệt)
    final cleanMemo = widget.referenceCode
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final hasValidMemo = cleanMemo.isNotEmpty;
    final isInvoicePayment = widget.type == PaymentType.invoice;
    final canUseBankTransfer = hasBankConfig && hasValidMemo;
    final canUseVnpay = hasVnpayConfig && hasValidMemo && isInvoicePayment;

    final vietQrString = canUseBankTransfer
        ? VietQrGenerator.generate(
            bankBin: bankBin,
            bankAccount: bankAccountNumber,
            amount: widget.amount,
            memo: cleanMemo,
            accountName: bankAccountName,
          )
        : '';

    final actionDisabled =
        _isSubmitting ||
        (_selectedMethod == 'bank_transfer' && !canUseBankTransfer) ||
        (_selectedMethod == 'vnpay' && !canUseVnpay);

    final actionLabel =
        (_selectedMethod == 'bank_transfer' && !canUseBankTransfer)
        ? (!hasBankConfig
              ? 'BQL CHƯA CẤU HÌNH TÀI KHOẢN'
              : 'CHƯA CÓ MÃ THANH TOÁN HỢP LỆ')
        : (_selectedMethod == 'vnpay' && !canUseVnpay)
        ? (!isInvoicePayment
              ? 'CHƯA HỖ TRỢ VNPAY CHO DỊCH VỤ NÀY'
              : (!hasVnpayConfig
                    ? 'BQL CHƯA KÍCH HOẠT VNPAY'
                    : 'CHƯA CÓ MÃ THANH TOÁN HỢP LỆ'))
        : (_selectedMethod == 'vnpay'
              ? 'MỞ CỔNG VNPAY'
              : 'GỬI THÔNG BÁO THANH TOÁN');

    return Column(
      key: const ValueKey('step_confirmation'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        Text(
          widget.referenceCode,
          style: context.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 12),

        // Huy hiệu đối soát tự động VietQR Napas 247
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: successColor.withValues(alpha: isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: successColor.withValues(alpha: isDark ? 0.4 : 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: successColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thanh toán tự động 24/7 qua VietQR Napas 247. Hệ thống tự động đối soát và gạch nợ tức thì qua Webhook ngân hàng.',
                  style: context.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: successColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Khối tổng tiền thanh toán
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                'TỔNG TIỀN THANH TOÁN',
                style: context.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _currencyFormat.format(widget.amount),
                  style: context.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (widget.feeBreakdown != null && widget.feeBreakdown!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Chi tiết các khoản',
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                  : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: widget.feeBreakdown!.map((item) {
                final name = item['name'] as String? ?? '';
                final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: context.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currencyFormat.format(amount),
                        style: context.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Text(
          'Chọn hình thức thanh toán',
          style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Lựa chọn 1: Chuyển khoản VietQR
        PaymentMethodOptionCard(
          isSelected: _selectedMethod == 'bank_transfer',
          title: 'Chuyển khoản VietQR (Napas 247)',
          subtitle: 'Quét mã chuyển tiền nhanh 24/7 liên ngân hàng',
          trailingIcon: Icons.qr_code_2,
          onTap: () => setState(() => _selectedMethod = 'bank_transfer'),
        ),
        const SizedBox(height: 10),

        if (_selectedMethod == 'bank_transfer') ...[
          VietQrTransferPanel(
            hasBankConfig: hasBankConfig,
            hasValidMemo: hasValidMemo,
            vietQrString: vietQrString,
            bankName: bankName,
            bankAccountNumber: bankAccountNumber,
            bankAccountName: bankAccountName,
            cleanMemo: cleanMemo,
            amount: widget.amount,
          ),
          const SizedBox(height: 10),
        ],

        // Lựa chọn 2: Cổng thanh toán trực tuyến VNPay (chỉ áp dụng cho hóa đơn căn hộ)
        if (isInvoicePayment) ...[
          PaymentMethodOptionCard(
            isSelected: _selectedMethod == 'vnpay',
            title: 'Cổng thanh toán trực tuyến VNPay',
            subtitle: 'Hỗ trợ thẻ ATM nội địa, Visa/Mastercard và ví VNPAY',
            trailingIcon: Icons.credit_card,
            onTap: () => setState(() => _selectedMethod = 'vnpay'),
          ),
          const SizedBox(height: 10),
          if (_selectedMethod == 'vnpay') ...[
            VnpayInfoPanel(hasVnpayConfig: hasVnpayConfig),
            const SizedBox(height: 10),
          ],
        ],

        // Lựa chọn 3: Tiền mặt tại quầy
        PaymentMethodOptionCard(
          isSelected: _selectedMethod == 'cash',
          title: 'Tiền mặt tại văn phòng Ban Quản Lý',
          subtitle: 'Đến quầy nộp tiền trực tiếp và nhận biên nhận giấy',
          trailingIcon: Icons.payments_outlined,
          onTap: () => setState(() => _selectedMethod = 'cash'),
        ),

        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          onPressed: actionDisabled
              ? null
              : () {
                  if (_selectedMethod == 'vnpay') {
                    _startVnpayPayment(targetBldId ?? '');
                  } else {
                    _startPayment();
                  }
                },
          child: _isSubmitting
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _selectedMethod == 'vnpay'
                            ? 'ĐANG MỞ CỔNG VNPAY...'
                            : 'ĐANG GỬI THÔNG BÁO...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  actionLabel,
                  textAlign: TextAlign.center,
                  style: context.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
