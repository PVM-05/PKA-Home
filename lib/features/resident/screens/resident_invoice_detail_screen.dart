import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/document_pdf_builder.dart';
import '../../../core/utils/invoice_fee_helper.dart';
import '../../../core/utils/utility_fee_calculator.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/unified_payment_sheet.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/tiered_calculation_result_model.dart';
import '../../../data/providers/resident_invoice_provider.dart';
import '../../../data/services/payment_service.dart';
import '../../document/screens/document_preview_screen.dart';
import '../widgets/invoice/resident_digital_receipt_sheet.dart';
import '../widgets/invoice/resident_invoice_fee_item_card.dart';
import '../widgets/invoice/resident_invoice_summary_card.dart';
import '../widgets/tiered_fee_breakdown_dialog.dart';

class ResidentInvoiceDetailScreen extends ConsumerStatefulWidget {
  final InvoiceModel invoice;
  final bool isEmbedded;

  const ResidentInvoiceDetailScreen({
    super.key,
    required this.invoice,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<ResidentInvoiceDetailScreen> createState() =>
      _ResidentInvoiceDetailScreenState();
}

class _ResidentInvoiceDetailScreenState
    extends ConsumerState<ResidentInvoiceDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isOpeningPayment = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutQuad,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  InvoiceModel get _invoice {
    final invoicesState = ref.read(residentInvoiceProvider);
    return invoicesState.valueOrNull?.firstWhere(
          (inv) => inv.id == widget.invoice.id,
          orElse: () => widget.invoice,
        ) ??
        widget.invoice;
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe provider trong build để tự động re-render khi trạng thái hóa đơn thay đổi
    ref.watch(residentInvoiceProvider);
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy');
    final colorScheme = Theme.of(context).colorScheme;
    final detailState = ref.watch(
      residentInvoiceDetailProvider(widget.invoice.id),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        title: Text('Chi tiết hóa đơn ${_invoice.period}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Xuất PDF chứng từ',
            onPressed: () {
              final items = detailState.valueOrNull ?? <Map<String, dynamic>>[];
              _openPdfPreview(context, items);
            },
          ),
        ],
      ),
      body: detailState.when(
        data: (items) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 900;

                      if (isDesktop) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cột trái: Tóm tắt & Nút hành động
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ResidentInvoiceSummaryCard(
                                      invoice: _invoice,
                                      formatCurrency: formatCurrency,
                                      formatDate: formatDate,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildActionWidget(context, items),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Cột phải: Danh sách chi tiết các khoản phí
                              Expanded(
                                flex: 7,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'CHI TIẾT CÁC KHOẢN PHÍ',
                                      style: context.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurfaceVariant,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ...items.map(
                                      (item) => ResidentInvoiceFeeItemCard(
                                        item: item,
                                        formatCurrency: formatCurrency,
                                        onViewTieredBreakdown:
                                            ({
                                              required isElectricity,
                                              required quantity,
                                              required item,
                                            }) => _showTieredBreakdownDialog(
                                              context,
                                              isElectricity: isElectricity,
                                              quantity: quantity,
                                              item: item,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Giao diện Mobile / Tablet (< 900dp)
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          ResidentInvoiceSummaryCard(
                            invoice: _invoice,
                            formatCurrency: formatCurrency,
                            formatDate: formatDate,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'CHI TIẾT CÁC KHOẢN PHÍ',
                            style: context.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...items.map(
                            (item) => ResidentInvoiceFeeItemCard(
                              item: item,
                              formatCurrency: formatCurrency,
                              onViewTieredBreakdown:
                                  ({
                                    required isElectricity,
                                    required quantity,
                                    required item,
                                  }) => _showTieredBreakdownDialog(
                                    context,
                                    isElectricity: isElectricity,
                                    quantity: quantity,
                                    item: item,
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 120),
          ],
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: AppErrorCard(
              error: error,
              onRetry: () => ref.invalidate(
                residentInvoiceDetailProvider(widget.invoice.id),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: detailState.whenOrNull(
        data: (items) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (screenWidth >= 900) {
            return const SizedBox.shrink();
          }
          return _buildBottomAction(context, items);
        },
      ),
    );
  }

  void _openPdfPreview(BuildContext context, List<Map<String, dynamic>> items) {
    final isPaid = _invoice.status.toLowerCase() == 'paid';
    final periodSlug = _invoice.period.replaceAll('/', '_');
    final aptCode = _invoice.apartment?.code ?? _invoice.apartmentId;

    if (isPaid) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(
            title: 'Biên lai điện tử ${_invoice.period} - $aptCode',
            fileName: 'bien_lai_${aptCode}_$periodSlug.pdf',
            buildPdf: (format) => DocumentPdfBuilder.buildReceiptPdfA4(
              invoice: _invoice,
              items: items,
            ),
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(
            title: 'Hóa đơn dịch vụ ${_invoice.period} - $aptCode',
            fileName: 'hoa_don_${aptCode}_$periodSlug.pdf',
            buildPdf: (format) => DocumentPdfBuilder.buildInvoicePdfA4(
              invoice: _invoice,
              items: items,
            ),
          ),
        ),
      );
    }
  }

  void _showTieredBreakdownDialog(
    BuildContext context, {
    required bool isElectricity,
    required num quantity,
    Map<String, dynamic>? item,
  }) {
    // Ưu tiên đọc kết quả phân rã bậc thang đã lưu trữ bất biến trong database của hóa đơn
    if (item != null &&
        item['breakdown'] != null &&
        item['breakdown'] is Map<String, dynamic>) {
      try {
        final storedResult = TieredCalculationResultModel.fromJson(
          item['breakdown'] as Map<String, dynamic>,
        );
        showDialog(
          context: context,
          builder: (_) => TieredFeeBreakdownDialog(
            title: isElectricity
                ? 'Chi tiết bậc thang tiền điện (Đã lưu)'
                : 'Chi tiết định mức tiền nước (Đã lưu)',
            unit: isElectricity ? 'kWh' : 'm³',
            result: storedResult,
          ),
        );
        return;
      } catch (_) {
        // Fallback sang công cụ tính toán tham khảo nếu cấu trúc JSON lưu trữ không tương thích
      }
    }

    if (isElectricity) {
      final result = UtilityFeeCalculator.calculateElectricityEVN6Tiers(
        quantity,
      );
      showDialog(
        context: context,
        builder: (_) => TieredFeeBreakdownDialog(
          title: 'Chi tiết bậc thang tiền điện',
          unit: 'kWh',
          result: result,
        ),
      );
    } else {
      final result = UtilityFeeCalculator.calculateWaterQuota(
        consumption: quantity,
      );
      showDialog(
        context: context,
        builder: (_) => TieredFeeBreakdownDialog(
          title: 'Chi tiết định mức tiền nước',
          unit: 'm³',
          result: result,
        ),
      );
    }
  }

  Widget _buildActionWidget(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final pendingColor = AppStatusColors.getPendingConfirmation(context);

    if (_invoice.status == 'unpaid') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.payment_rounded, size: 22),
          label: Text(
            'THANH TOÁN NGAY',
            style: context.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          onPressed: () {
            _handlePayment(context, items);
          },
        ),
      );
    } else if (_invoice.status == 'pending_confirmation') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            foregroundColor: pendingColor,
            side: BorderSide(color: pendingColor, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(Icons.hourglass_top_rounded, color: pendingColor),
          label: Text(
            'ĐANG CHỜ BQL XÁC NHẬN (CHI TIẾT)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: pendingColor,
            ),
          ),
          onPressed: () {
            showResidentDigitalReceiptSheet(context, invoice: _invoice);
          },
        ),
      );
    } else if (_invoice.status == 'paid') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            foregroundColor: colorScheme.primary,
            side: BorderSide(color: colorScheme.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(Icons.receipt_outlined, color: colorScheme.primary),
          label: Text(
            'XEM BIÊN NHẬN ĐIỆN TỬ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          onPressed: () {
            showResidentDigitalReceiptSheet(context, invoice: _invoice);
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomAction(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (_invoice.status != 'unpaid' &&
        _invoice.status != 'pending_confirmation' &&
        _invoice.status != 'paid') {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.6 : 0.7,
            ),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  offset: const Offset(0, -3),
                  blurRadius: 12,
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: _buildActionWidget(context, items),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePayment(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) async {
    if (_isOpeningPayment) return;
    if (_invoice.effectivePaymentCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hóa đơn chưa được cấp mã thanh toán từ máy chủ. Vui lòng liên hệ Ban Quản Lý.',
          ),
          backgroundColor: AppTheme.textWarning,
        ),
      );
      return;
    }
    _isOpeningPayment = true;

    try {
      final feeBreakdown = items
          .map(
            (item) => {
              'name': InvoiceFeeHelper.getFeeName(item['fee_type'] as String?),
              'amount': (item['subtotal'] as num?)?.toDouble() ?? 0.0,
            },
          )
          .toList();

      final result = await showUnifiedPaymentSheet(
        context: context,
        type: PaymentType.invoice,
        referenceId: _invoice.id,
        title: 'Thanh toán hóa đơn',
        referenceCode: _invoice.effectivePaymentCode,
        amount: _invoice.totalAmount,
        feeBreakdown: feeBreakdown,
      );

      if (result != null && result.success && mounted) {
        ref.invalidate(residentInvoiceProvider);
        ref.invalidate(residentInvoiceDetailProvider(_invoice.id));
        if (result.isPending || result.status == 'PENDING') {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã gửi thông báo thanh toán! Đang chờ Ban Quản Lý xác nhận. Mã: ${result.transactionCode}',
              ),
              backgroundColor: AppTheme.textWarning,
            ),
          );
        } else {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(
                'Thanh toán thành công! Mã GD: ${result.transactionCode}',
              ),
              backgroundColor: AppTheme.textSuccess,
            ),
          );
        }
      }
    } finally {
      _isOpeningPayment = false;
    }
  }
}
