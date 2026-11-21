import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../data/models/invoice_model.dart';

void showResidentDigitalReceiptSheet(
  BuildContext context, {
  required InvoiceModel invoice,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ResidentDigitalReceiptSheet(
      parentContext: context,
      invoice: invoice,
    ),
  );
}

class _ResidentDigitalReceiptSheet extends StatelessWidget {
  final BuildContext parentContext;
  final InvoiceModel invoice;

  const _ResidentDigitalReceiptSheet({
    required this.parentContext,
    required this.invoice,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy HH:mm');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isPaid = invoice.status == 'paid';
    final statusColor = isPaid
        ? AppStatusColors.getPaid(context)
        : AppStatusColors.getPendingConfirmation(context);
    final receiptCode =
        'REC-${invoice.id.length > 8 ? invoice.id.substring(0, 8).toUpperCase() : invoice.id.toUpperCase()}';

    final methodLabel = invoice.paymentMethod == 'sepay' ||
            invoice.paymentMethod == 'VIETQR' ||
            invoice.paymentMethod == 'bank_transfer'
        ? 'Chuyển khoản VietQR (Napas 247)'
        : (invoice.paymentMethod == 'cash' || invoice.paymentMethod == 'CASH'
              ? 'Tiền mặt tại BQL'
              : (invoice.paymentMethod ?? 'Chuyển khoản trực tuyến'));

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaid ? Icons.verified : Icons.hourglass_top,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    isPaid ? 'BIÊN NHẬN THANH TOÁN' : 'XÁC NHẬN CHUYỂN KHOẢN',
                    style: context.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isPaid
                  ? 'Giao dịch đã được Ban Quản Lý phê duyệt hợp lệ'
                  : 'Đã gửi yêu cầu đối soát, BQL đang kiểm tra giao dịch',
              style: context.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  _CopyableRow(
                    label: 'Mã biên nhận',
                    value: receiptCode,
                    copyValue: receiptCode,
                  ),
                  const Divider(height: 16),
                  _CopyableRow(
                    label: 'Căn hộ',
                    value: invoice.apartment?.code ?? 'N/A',
                  ),
                  const Divider(height: 16),
                  _CopyableRow(
                    label: 'Kỳ thu',
                    value: invoice.period,
                  ),
                  const Divider(height: 16),
                  _CopyableRow(
                    label: 'Số tiền thanh toán',
                    value: formatCurrency.format(invoice.totalAmount),
                    isHighlight: true,
                  ),
                  const Divider(height: 16),
                  _CopyableRow(
                    label: 'Phương thức',
                    value: methodLabel,
                  ),
                  if (invoice.transactionCode != null) ...[
                    const Divider(height: 16),
                    _CopyableRow(
                      label: 'Mã giao dịch',
                      value: invoice.transactionCode!,
                      copyValue: invoice.transactionCode!,
                    ),
                  ],
                  const Divider(height: 16),
                  _CopyableRow(
                    label: 'Thời gian',
                    value: formatDate.format(
                      (invoice.updatedAt ?? invoice.createdAt).toLocal(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(
                'Sao chép thông tin biên nhận',
                style: context.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                AppHaptics.selection();
                final summary =
                    'BIÊN NHẬN THANH TOÁN VIVONA\n'
                    'Mã: $receiptCode\n'
                    'Căn hộ: ${invoice.apartment?.code ?? "N/A"}\n'
                    'Kỳ: ${invoice.period}\n'
                    'Số tiền: ${formatCurrency.format(invoice.totalAmount)}\n'
                    'Trạng thái: ${isPaid ? "Đã thanh toán" : "Chờ xác nhận"}\n'
                    'Thời gian: ${formatDate.format((invoice.updatedAt ?? invoice.createdAt).toLocal())}';
                Clipboard.setData(ClipboardData(text: summary));
                Navigator.pop(context);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép toàn bộ thông tin biên nhận'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  final String label;
  final String value;
  final String? copyValue;
  final bool isHighlight;

  const _CopyableRow({
    required this.label,
    required this.value,
    this.copyValue,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            style: context.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHighlight ? colorScheme.primary : colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.right,
          ),
        ),
        if (copyValue != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Sao chép $label',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () {
              AppHaptics.selection();
              Clipboard.setData(ClipboardData(text: copyValue!));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã sao chép: $copyValue'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(
              Icons.copy_rounded,
              size: 16,
              color: colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
