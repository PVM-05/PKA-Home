import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/services/payment_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

class PaymentProcessingStep extends StatelessWidget {
  final double amount;
  final NumberFormat currencyFormat;

  const PaymentProcessingStep({
    super.key,
    required this.amount,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      key: const ValueKey('step_processing'),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Đang gửi thông báo thanh toán...',
            textAlign: TextAlign.center,
            style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormat.format(amount),
              style: context.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hệ thống đang ghi nhận yêu cầu vào sổ kế toán và chuyển đến BQL',
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class PaymentPendingStep extends StatelessWidget {
  final PaymentResult? result;
  final String title;
  final double amount;
  final String selectedMethod;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final VoidCallback onAcknowledge;

  const PaymentPendingStep({
    super.key,
    required this.result,
    required this.title,
    required this.amount,
    required this.selectedMethod,
    required this.currencyFormat,
    required this.dateFormat,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = AppStatusColors.getPendingConfirmation(context);
    final txCode = result?.transactionCode ?? 'PENDING-001';
    final dateStr = dateFormat.format(result?.paidAt ?? DateTime.now());

    return Column(
      key: const ValueKey('step_pending_confirmation'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: warningColor.withValues(alpha: isDark ? 0.2 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hourglass_top, color: warningColor, size: 44),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Đã gửi thông báo thanh toán',
            textAlign: TextAlign.center,
            style: context.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: warningColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: warningColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: warningColor.withValues(alpha: isDark ? 0.4 : 0.3),
              ),
            ),
            child: Text(
              'Chờ Ban Quản Lý xác nhận',
              style: context.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: warningColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormat.format(amount),
              style: context.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              _PaymentInfoRow(
                label: 'Mã yêu cầu',
                value: txCode,
                isHighlight: true,
              ),
              const Divider(height: 16),
              _PaymentInfoRow(label: 'Nội dung', value: title),
              const Divider(height: 16),
              _PaymentInfoRow(label: 'Thời gian gửi', value: dateStr),
              const Divider(height: 16),
              _PaymentInfoRow(
                label: 'Hình thức',
                value: _formatMethodName(selectedMethod),
              ),
              const Divider(height: 16),
              const _PaymentInfoRow(
                label: 'Trạng thái',
                value: 'Chờ Ban Quản Lý đối soát',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppTheme.textWarning,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onAcknowledge,
          child: Text(
            'ĐÃ HIỂU',
            style: context.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class PaymentSuccessStep extends StatelessWidget {
  final PaymentResult? result;
  final String title;
  final double amount;
  final String selectedMethod;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final VoidCallback onDone;

  const PaymentSuccessStep({
    super.key,
    required this.result,
    required this.title,
    required this.amount,
    required this.selectedMethod,
    required this.currencyFormat,
    required this.dateFormat,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = AppStatusColors.getPaid(context);
    final txCode = result?.transactionCode ?? 'SUCCESS-001';
    final dateStr = dateFormat.format(result?.paidAt ?? DateTime.now());

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
              color: successColor.withValues(alpha: isDark ? 0.2 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: successColor, size: 52),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Thanh toán thành công',
            textAlign: TextAlign.center,
            style: context.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: successColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormat.format(amount),
              style: context.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              _PaymentInfoRow(
                label: 'Mã giao dịch',
                value: txCode,
                isHighlight: true,
              ),
              const Divider(height: 16),
              _PaymentInfoRow(label: 'Nội dung', value: title),
              const Divider(height: 16),
              _PaymentInfoRow(label: 'Thời gian', value: dateStr),
              const Divider(height: 16),
              _PaymentInfoRow(
                label: 'Phương thức',
                value: _formatMethodName(selectedMethod),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onDone,
          child: Text(
            'HOÀN TẤT',
            style: context.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class PaymentFailedStep extends StatelessWidget {
  final String? errorMessage;
  final bool isSubmitting;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const PaymentFailedStep({
    super.key,
    required this.errorMessage,
    required this.isSubmitting,
    required this.onClose,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = AppTheme.getSemanticError(context);

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
              color: errorColor.withValues(alpha: isDark ? 0.2 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, color: errorColor, size: 52),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Giao dịch không thành công',
            textAlign: TextAlign.center,
            style: context.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: errorColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            errorMessage ??
                'Đã xảy ra sự cố trong quá trình gửi thông báo giao dịch.',
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onClose,
                child: Text(
                  'ĐÓNG',
                  style: context.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isSubmitting ? null : onRetry,
                child: Text(
                  'THỬ LẠI',
                  style: context.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _PaymentInfoRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHighlight ? colorScheme.primary : colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

String _formatMethodName(String selectedMethod) {
  switch (selectedMethod) {
    case 'bank_transfer':
      return 'Chuyển khoản VietQR (Napas 247)';
    case 'vnpay':
      return 'Cổng thanh toán VNPay';
    default:
      return 'Tiền mặt tại BQL';
  }
}
