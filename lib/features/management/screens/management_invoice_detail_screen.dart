import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/document_pdf_builder.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/invoice_fee_helper.dart';
import '../../../core/utils/vietnamese_currency_words.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/electronic_receipt_sheet.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/invoice_items_provider.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/payment_provider.dart';
import '../../document/screens/document_preview_screen.dart';
import 'edit_invoice_screen.dart';

/// Màn hình chi tiết hóa đơn & đối soát phía Ban Quản Lý.
class ManagementInvoiceDetailScreen extends ConsumerWidget {
  final InvoiceModel invoice;

  const ManagementInvoiceDetailScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy');
    final detailState = ref.watch(invoiceDetailProvider(invoice.id));
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final errorColor = AppTheme.getSemanticError(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết Hóa đơn ${invoice.period}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Xuất PDF / In chứng từ',
            onPressed: () {
              final items = detailState.valueOrNull ?? <Map<String, dynamic>>[];
              _showPrintExportBottomSheet(context, items);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Sửa hóa đơn',
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditInvoiceScreen(invoice: invoice),
                ),
              );
              if (updated == true) {
                ref.invalidate(invoiceDetailProvider(invoice.id));
                ref.invalidate(invoicesProvider);
              }
            },
          ),
          if (!invoice.isPaid)
            IconButton(
              icon: Icon(Icons.delete_outline, color: errorColor),
              tooltip: 'Xóa hóa đơn',
              onPressed: () => _confirmDeleteInvoice(context, ref),
            ),
        ],
      ),
      body: detailState.when(
        data: (items) {
          if (isDesktop) {
            return _buildDesktopLayout(
              context,
              ref,
              items,
              formatCurrency,
              formatDate,
            );
          }
          return _buildMobileLayout(
            context,
            ref,
            items,
            formatCurrency,
            formatDate,
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 4, itemHeight: 90)],
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: AppSpacing.p16,
            child: AppErrorCard(
              error: error,
              onRetry: () => ref.invalidate(invoiceDetailProvider(invoice.id)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> items,
    NumberFormat formatCurrency,
    DateFormat formatDate,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cột trái: Tóm tắt hóa đơn và khối nút hành động
              SizedBox(
                width: 440,
                child: ListView(
                  children: [
                    _buildSummaryCard(context, formatCurrency, formatDate),
                    AppSpacing.h16,
                    _buildDesktopActionPanel(context, ref, items),
                    AppSpacing.h40,
                  ],
                ),
              ),
              AppSpacing.w24,
              // Cột phải: Danh mục chi tiết các khoản phí
              Expanded(
                child: AppCard(
                  padding: AppSpacing.p20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          AppSpacing.w8,
                          Expanded(
                            child: Text(
                              'CHI TIẾT CÁC KHOẢN PHÍ',
                              style: context.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: AppRadius.r12,
                            ),
                            child: Text(
                              '${items.length} mục',
                              style: context.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  )
                                  .tabularFigures(),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h16,
                      const Divider(),
                      Expanded(
                        child: ListView(
                          children: items
                              .map(
                                (item) =>
                                    _buildFeeItem(context, item, formatCurrency),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> items,
    NumberFormat formatCurrency,
    DateFormat formatDate,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: AppSpacing.p16,
                children: [
                  _buildSummaryCard(context, formatCurrency, formatDate),
                  AppSpacing.h24,
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            AppSpacing.w6,
                            Expanded(
                              child: Text(
                                'CHI TIẾT CÁC KHOẢN PHÍ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.w8,
                      Text(
                        '${items.length} mục',
                        style: context.labelSmall
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            )
                            .tabularFigures(),
                      ),
                    ],
                  ),
                  AppSpacing.h12,
                  ...items.map(
                    (item) => _buildFeeItem(context, item, formatCurrency),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            _buildBottomAction(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    NumberFormat formatCurrency,
    DateFormat formatDate,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color statusColor;
    final String statusText;

    switch (invoice.status) {
      case 'paid':
        statusColor = AppStatusColors.getPaid(context);
        statusText = 'Đã thanh toán';
        break;
      case 'pending_confirmation':
        statusColor = AppStatusColors.getPendingConfirmation(context);
        statusText = 'Chờ xác nhận';
        break;
      default:
        statusColor = AppStatusColors.getUnpaid(context);
        statusText = 'Chưa thanh toán';
    }

    return AppCard(
      color: statusColor.withValues(alpha: 0.06),
      borderColor: statusColor.withValues(alpha: 0.4),
      padding: AppSpacing.p16,
      child: Column(
        children: [
          Text(
            'TỔNG CỘNG',
            style: context.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.h8,
          Semantics(
            label:
                'Tổng tiền ${formatCurrency.format(invoice.totalAmount)}, tức ${VietnameseCurrencyWords.toVietnameseWords(invoice.totalAmount)}',
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatCurrency.format(invoice.totalAmount),
                style: context.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: statusColor)
                    .tabularFigures(),
              ),
            ),
          ),
          AppSpacing.h16,
          const Divider(),
          AppSpacing.h16,
          _buildInfoRow(
            context,
            'Trạng thái',
            statusText,
            valueColor: statusColor,
          ),
          AppSpacing.h8,
          _buildInfoRow(
            context,
            'Hạn thanh toán',
            formatDate.format(invoice.dueDate),
          ),
          AppSpacing.h8,
          _buildInfoRow(context, 'Căn hộ', invoice.apartment?.code ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: context.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AppSpacing.w8,
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: context.bodyMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? colorScheme.onSurface,
                )
                .tabularFigures(),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeItem(
    BuildContext context,
    Map<String, dynamic> item,
    NumberFormat formatCurrency,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawFeeType = item['fee_type'] as String?;
    final feeDisplayName = InvoiceFeeHelper.getFeeName(rawFeeType);
    final feeIcon = InvoiceFeeHelper.getFeeIcon(rawFeeType);
    final feeColor = InvoiceFeeHelper.getFeeColor(rawFeeType);
    final feeUnit = InvoiceFeeHelper.getFeeUnit(rawFeeType);

    final qty = item['quantity'] ?? 1;
    final qtyStr = (qty is num && qty == qty.roundToDouble())
        ? qty.toInt().toString()
        : qty.toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: AppSpacing.p8,
            decoration: BoxDecoration(
              color: feeColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.r12,
            ),
            child: Icon(feeIcon, color: feeColor, size: 20),
          ),
          AppSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feeDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatCurrency.format(item['unit_price'] ?? 0)} x $qtyStr$feeUnit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)
                      .tabularFigures(),
                ),
              ],
            ),
          ),
          AppSpacing.w8,
          Flexible(
            child: Text(
              formatCurrency.format(item['subtotal'] ?? 0),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)
                  .tabularFigures(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActionPanel(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> items,
  ) {
    final isPending = invoice.status == 'pending_confirmation';
    final isUnpaid = invoice.status == 'unpaid';
    final isPaid = invoice.status == 'paid';
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'THAO TÁC NGHIỆP VỤ',
            style: context.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          AppSpacing.h12,
          if (isPaid) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
              ),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text(
                'XEM BIÊN LAI THU TIỀN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => showElectronicReceiptSheet(
                context: context,
                invoice: invoice,
              ),
            ),
            AppSpacing.h12,
          ],
          if (isPending || isUnpaid) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textSuccess,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                isPending
                    ? 'XÁC NHẬN ĐÃ THU TIỀN'
                    : 'XÁC NHẬN THU TẠI QUẦY',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _confirmPayment(context, ref, isPending),
            ),
            AppSpacing.h12,
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
            ),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('In ấn / Xuất PDF (A4 & 80mm)'),
            onPressed: () => _showPrintExportBottomSheet(context, items),
          ),
          AppSpacing.h12,
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Chỉnh sửa thông tin hóa đơn'),
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditInvoiceScreen(invoice: invoice),
                ),
              );
              if (updated == true) {
                ref.invalidate(invoiceDetailProvider(invoice.id));
                ref.invalidate(invoicesProvider);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, WidgetRef ref) {
    final isPending = invoice.status == 'pending_confirmation';
    final isUnpaid = invoice.status == 'unpaid';
    final isPaid = invoice.status == 'paid';

    if (!isPending && !isUnpaid && !isPaid) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final barColor = theme.cardTheme.color ?? colorScheme.surfaceContainerLow;

    if (isPaid) {
      return Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            decoration: BoxDecoration(
              color: barColor,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  offset: const Offset(0, -3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.r14,
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long, size: 20),
                    label: Text(
                      'XEM BIÊN LAI THU TIỀN',
                      style: context.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () => showElectronicReceiptSheet(
                      context: context,
                      invoice: invoice,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final reqMethod = (invoice.paymentMethod ?? '').toLowerCase();
    final isCashRequest = reqMethod == 'cash' || reqMethod == 'tiền mặt';

    final String buttonLabel;
    if (isPending) {
      buttonLabel = isCashRequest
          ? 'XÁC NHẬN ĐÃ THU (Cư dân báo nộp Tiền mặt)'
          : 'XÁC NHẬN ĐÃ THU (Cư dân báo Chuyển khoản)';
    } else {
      buttonLabel = 'XÁC NHẬN ĐÃ THU (Thu trực tiếp tại quầy)';
    }

    return Center(
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                offset: const Offset(0, -3),
                blurRadius: 12,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textSuccess,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.r14,
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      buttonLabel,
                      style: context.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  onPressed: () => _confirmPayment(context, ref, isPending),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPayment(
    BuildContext context,
    WidgetRef ref,
    bool isPending,
  ) async {
    final reqMethod = (invoice.paymentMethod ?? '').toLowerCase();
    final isCashRequest = reqMethod == 'cash' || reqMethod == 'tiền mặt';
    String selectedMethod = isCashRequest ? 'CASH' : 'BANK_TRANSFER';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final colorScheme = Theme.of(dialogCtx).colorScheme;
          final successColor = AppTheme.getSemanticSuccess(dialogCtx);
          final warningColor = AppTheme.getSemanticWarning(dialogCtx);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: Row(
              children: [
                Icon(Icons.check_circle_outline, color: successColor),
                AppSpacing.w8,
                const Expanded(child: Text('Xác nhận thu tiền')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vui lòng kiểm tra và xác nhận phương thức đã nhận đủ:',
                  ),
                  AppSpacing.h12,
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.p12,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: AppRadius.r8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Căn hộ: ${invoice.apartment?.code ?? "Chưa rõ"}',
                          style: dialogCtx.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold)
                              .tabularFigures(),
                        ),
                        AppSpacing.h4,
                        Text(
                          '• Kỳ phí: ${invoice.period}',
                          style: dialogCtx.bodyMedium?.tabularFigures(),
                        ),
                        AppSpacing.h4,
                        Text(
                          '• Số tiền: ${NumberFormat.currency(locale: "vi_VN", symbol: "đ").format(invoice.totalAmount)}',
                          style: dialogCtx.bodyMedium
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              )
                              .tabularFigures(),
                        ),
                        if (isPending) ...[
                          AppSpacing.h4,
                          Text(
                            '• Cư dân đã báo: ${isCashRequest ? "Nộp tiền mặt tại BQL" : "Chuyển khoản (VietQR)"}',
                            style: dialogCtx.bodySmall?.copyWith(
                              color: warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.h12,
                  Text(
                    'Hình thức thanh toán thực thu:',
                    style: dialogCtx.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.h6,
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Tiền mặt (CASH)'),
                    value: 'CASH',
                    // ignore: deprecated_member_use
                    groupValue: selectedMethod,
                    // ignore: deprecated_member_use
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMethod = val);
                      }
                    },
                  ),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Chuyển khoản (BANK_TRANSFER)'),
                    value: 'BANK_TRANSFER',
                    // ignore: deprecated_member_use
                    groupValue: selectedMethod,
                    // ignore: deprecated_member_use
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMethod = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textSuccess,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Xác nhận đã thu'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(managementRepositoryProvider);
      final methodTitle = selectedMethod == 'CASH'
          ? 'Tiền mặt'
          : 'Chuyển khoản';
      final txnTitle =
          'Thanh toán hóa đơn kỳ ${invoice.period} ($methodTitle)';

      // Sử dụng recordManualPayment để đảm bảo tính nguyên tử (atomic transaction)
      await repo.recordManualPayment(
        invoiceId: invoice.id,
        paymentMethod: selectedMethod,
        notes: txnTitle,
      );

      ref.invalidate(invoicesProvider);
      ref.invalidate(paymentTransactionsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          'Xác nhận thu tiền ($methodTitle) thành công.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
      }
    }
  }

  void _showPrintExportBottomSheet(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final periodSlug = invoice.period.replaceAll('/', '_');
    final aptCode = invoice.apartment?.code ?? invoice.apartmentId;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        final colorScheme = Theme.of(bottomSheetContext).colorScheme;
        final successColor = AppTheme.getSemanticSuccess(bottomSheetContext);
        final warningColor = AppTheme.getSemanticWarning(bottomSheetContext);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: AppSpacing.p8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.r8,
                      ),
                      child: Icon(
                        Icons.print_outlined,
                        color: colorScheme.primary,
                      ),
                    ),
                    AppSpacing.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tùy chọn In ấn & Xuất chứng từ',
                            style: bottomSheetContext.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Chọn mẫu định dạng tài liệu cần xuất hoặc in',
                            style: bottomSheetContext.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AppSpacing.h16,
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.description_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    'Hóa đơn dịch vụ (Khổ A4)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Bảng kê chi tiết phí và mã VietQR thanh toán 24/7',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DocumentPreviewScreen(
                          title: 'Hóa đơn dịch vụ A4 - Căn hộ $aptCode',
                          fileName: 'hoa_don_${aptCode}_$periodSlug.pdf',
                          buildPdf: (format) =>
                              DocumentPdfBuilder.buildInvoicePdfA4(
                                invoice: invoice,
                                items: items,
                              ),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.verified_outlined, color: successColor),
                  title: const Text(
                    'Biên lai thu tiền điện tử (Khổ A4)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Chứng từ thu phí chính thức có con dấu mộc số BQL',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DocumentPreviewScreen(
                          title: 'Biên lai thu tiền A4 - Căn hộ $aptCode',
                          fileName: 'bien_lai_${aptCode}_$periodSlug.pdf',
                          buildPdf: (format) =>
                              DocumentPdfBuilder.buildReceiptPdfA4(
                                invoice: invoice,
                                items: items,
                              ),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.receipt_long_outlined,
                    color: warningColor,
                  ),
                  title: const Text(
                    'Phiếu in nhiệt quầy thu ngân (Cuộn 80mm)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Phiếu thu gọn cho máy in bill nhiệt POS tại quầy BQL',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DocumentPreviewScreen(
                          title: 'Phiếu in nhiệt 80mm - Căn hộ $aptCode',
                          fileName: 'phieu_thu_80mm_${aptCode}_$periodSlug.pdf',
                          buildPdf: (format) =>
                              DocumentPdfBuilder.buildReceiptPdf80mm(
                                invoice: invoice,
                                items: items,
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteInvoice(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (invoice.isPaid) {
      AppSnackBar.showWarning(
        context,
        'Hóa đơn đã thanh toán là bất biến. Không được phép xóa. Để điều chỉnh số tiền hoặc hoàn phí, vui lòng tạo Phiếu giảm trừ (Credit Note).',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: const Text('Xác nhận xóa hóa đơn'),
          content: SingleChildScrollView(
            child: Text(
              'Bạn có chắc chắn muốn xóa hóa đơn kỳ ${invoice.period} của căn hộ ${invoice.apartment?.code ?? ''}?\n\nToàn bộ các khoản phí liên quan sẽ bị xóa và không thể khôi phục.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(managementRepositoryProvider).deleteInvoice(invoice.id);
        ref.invalidate(invoicesProvider);
        if (context.mounted) {
          AppSnackBar.showSuccess(context, 'Đã xóa hóa đơn thành công!');
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackBar.showError(context, formatErrorMessage(e));
        }
      }
    }
  }
}
