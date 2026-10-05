import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../data/services/payment_service.dart';
import '../../data/providers/payment_provider.dart';

enum _PaymentStep { confirmation, processing, success, failed }

/// Hàm tiện ích mở Bottom Sheet Thanh toán dùng chung
Future<PaymentResult?> showUnifiedPaymentSheet({
  required BuildContext context,
  required PaymentType type,
  required String referenceId,
  required String title,
  required String referenceCode,
  required double amount,
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
  final List<Map<String, dynamic>>? feeBreakdown;

  const UnifiedPaymentSheet({
    super.key,
    required this.type,
    required this.referenceId,
    required this.title,
    required this.referenceCode,
    required this.amount,
    this.feeBreakdown,
  });

  @override
  ConsumerState<UnifiedPaymentSheet> createState() => _UnifiedPaymentSheetState();
}

class _UnifiedPaymentSheetState extends ConsumerState<UnifiedPaymentSheet> {
  _PaymentStep _step = _PaymentStep.confirmation;
  PaymentResult? _result;
  String? _errorMessage;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _startPayment() async {
    setState(() {
      _step = _PaymentStep.processing;
    });

    try {
      // Giả lập độ trễ mạng/gateway 1.2s - 1.5s tạo trải nghiệm thực tế
      await Future.delayed(const Duration(milliseconds: 1400));

      final service = ref.read(paymentServiceProvider);
      final res = await service.pay(
        ref: ref,
        type: widget.type,
        referenceId: widget.referenceId,
        outcome: 'SUCCESS',
      );

      if (mounted) {
        setState(() {
          _result = res;
          _step = res.success ? _PaymentStep.success : _PaymentStep.failed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _step = _PaymentStep.failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
        return _buildProcessingStep(context);
      case _PaymentStep.success:
        return _buildSuccessStep(context);
      case _PaymentStep.failed:
        return _buildFailedStep(context);
    }
  }

  Widget _buildConfirmationStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        Text(
          widget.referenceCode,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(
                'TỔNG TIỀN THANH TOÁN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _currencyFormat.format(widget.amount),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (widget.feeBreakdown != null && widget.feeBreakdown!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Chi tiết các khoản',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
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
                      Text(name, style: const TextStyle(fontSize: 13)),
                      Text(
                        _currencyFormat.format(amount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Phương thức thanh toán',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.radio_button_checked, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Demo Payment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Giao dịch mô phỏng (Sandbox)',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified, color: AppTheme.primary, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          onPressed: _startPayment,
          child: const Text(
            'THANH TOÁN',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildProcessingStep(BuildContext context) {
    return Padding(
      key: const ValueKey('step_processing'),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Đang xử lý giao dịch...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(widget.amount),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hệ thống đang kết nối và xác nhận thanh toán tự động',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep(BuildContext context) {
    final txCode = _result?.transactionCode ?? 'DEMO-001';
    final dateStr = _dateFormat.format(_result?.paidAt ?? DateTime.now());

    return Column(
      key: const ValueKey('step_success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: AppTheme.success, size: 54),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Thanh toán thành công',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.success),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _currencyFormat.format(widget.amount),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              _buildInfoRow('Mã giao dịch', txCode, isHighlight: true),
              const Divider(height: 16),
              _buildInfoRow('Nội dung', widget.title),
              const Divider(height: 16),
              _buildInfoRow('Thời gian', dateStr),
              const Divider(height: 16),
              _buildInfoRow('Phương thức', 'Demo Payment'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            Navigator.pop(context, _result);
          },
          child: const Text(
            'HOÀN TẤT',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFailedStep(BuildContext context) {
    return Column(
      key: const ValueKey('step_failed'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: AppTheme.error, size: 54),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Giao dịch không thành công',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.error),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _errorMessage ?? 'Đã xảy ra sự cố trong quá trình mô phỏng giao dịch.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('ĐÓNG', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.primary : null,
          ),
        ),
      ],
    );
  }
}
