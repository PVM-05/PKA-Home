import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/unified_payment_sheet.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/services/payment_service.dart';
import '../../../data/providers/resident_invoice_provider.dart';

class ResidentInvoiceDetailScreen extends ConsumerStatefulWidget {
  final InvoiceModel invoice;

  const ResidentInvoiceDetailScreen({super.key, required this.invoice});

  @override
  ConsumerState<ResidentInvoiceDetailScreen> createState() => _ResidentInvoiceDetailScreenState();
}

class _ResidentInvoiceDetailScreenState extends ConsumerState<ResidentInvoiceDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuad),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy');
    final detailState = ref.watch(residentInvoiceDetailProvider(widget.invoice.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết hóa đơn ${widget.invoice.period}'),
      ),
      body: detailState.when(
        data: (items) {
          return Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryCard(context, formatCurrency, formatDate),
                        const SizedBox(height: 32),
                        const Text(
                          'CHI TIẾT CÁC KHOẢN PHÍ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...items.map((item) => _buildFeeItemCard(item, formatCurrency)),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomAction(context, items),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(formatErrorMessage(error), style: const TextStyle(color: AppTheme.error))),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, NumberFormat formatCurrency, DateFormat formatDate) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (widget.invoice.status) {
      case 'paid':
        statusColor = AppTheme.success;
        statusText = 'Đã thanh toán';
        statusIcon = Icons.check_circle;
        break;
      case 'pending_confirmation':
        statusColor = AppTheme.warning;
        statusText = 'Chờ xác nhận';
        statusIcon = Icons.hourglass_top;
        break;
      default:
        statusColor = AppTheme.error;
        statusText = 'Chưa thanh toán';
        statusIcon = Icons.error_outline;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface)
        : Colors.white;

    return Card(
      elevation: 3,
      color: cardBg,
      shadowColor: statusColor.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
              cardBg,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'TỔNG CỘNG',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatCurrency.format(widget.invoice.totalAmount),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.calendar_today, 'Hạn thanh toán', formatDate.format(widget.invoice.dueDate)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.apartment, 'Căn hộ', widget.invoice.apartment?.code ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeItemCard(Map<String, dynamic> item, NumberFormat formatCurrency) {
    String feeType = item['fee_type'] ?? 'Phí khác';
    IconData feeIcon = Icons.receipt_long;
    Color feeColor = AppTheme.primary;

    if (feeType.toLowerCase().contains('nước')) {
      feeIcon = Icons.water_drop;
      feeColor = Colors.blue;
    } else if (feeType.toLowerCase().contains('điện')) {
      feeIcon = Icons.electric_bolt;
      feeColor = Colors.orange;
    } else if (feeType.toLowerCase().contains('xe')) {
      feeIcon = Icons.local_parking;
      feeColor = Colors.teal;
    } else if (feeType.toLowerCase().contains('quản lý')) {
      feeIcon = Icons.admin_panel_settings;
      feeColor = Colors.indigo;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: feeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feeIcon, color: feeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feeType,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCurrency.format(item['unit_price'] ?? 0)} x ${item['quantity'] ?? 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency.format(item['subtotal'] ?? 0),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, List<Map<String, dynamic>> items) {
    if (widget.invoice.status == 'unpaid') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.payment),
          label: const Text('THANH TOÁN NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: () {
            _handlePayment(context, items);
          },
        ),
      );
    } else if (widget.invoice.status == 'paid' || widget.invoice.status == 'pending_confirmation') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppTheme.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.receipt_outlined, color: AppTheme.primary),
          label: const Text(
            'XEM BIÊN NHẬN ĐIỆN TỬ',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          onPressed: () {
            _showDigitalReceiptBottomSheet(context);
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _handlePayment(BuildContext context, List<Map<String, dynamic>> items) async {
    final feeBreakdown = items.map((item) => {
      'name': item['fee_type'] as String? ?? 'Khoản phí',
      'amount': (item['subtotal'] as num?)?.toDouble() ?? 0.0,
    }).toList();

    final aptCode = widget.invoice.apartment?.code ?? '';
    final periodClean = widget.invoice.period.replaceAll('/', '');

    final result = await showUnifiedPaymentSheet(
      context: context,
      type: PaymentType.invoice,
      referenceId: widget.invoice.id,
      title: 'Thanh toán hóa đơn',
      referenceCode: '#INV-$periodClean-$aptCode',
      amount: widget.invoice.totalAmount,
      feeBreakdown: feeBreakdown,
    );

    if (result != null && result.success && mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('Thanh toán thành công! Mã GD: ${result.transactionCode}'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Widget _buildCopyableRow(
    BuildContext context, {
    required String label,
    required String value,
    String? copyValue,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isHighlight ? AppTheme.primary : AppTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        if (copyValue != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyValue));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã sao chép: $copyValue'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.copy, size: 16, color: AppTheme.primary),
            ),
          ),
        ],
      ],
    );
  }

  void _showDigitalReceiptBottomSheet(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy HH:mm');
    final isPaid = widget.invoice.status == 'paid';
    final receiptCode = 'REC-${widget.invoice.id.length > 8 ? widget.invoice.id.substring(0, 8).toUpperCase() : widget.invoice.id.toUpperCase()}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
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
                      color: (isPaid ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPaid ? Icons.verified : Icons.hourglass_top,
                      color: isPaid ? AppTheme.success : AppTheme.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isPaid ? 'BIÊN NHẬN THANH TOÁN' : 'XÁC NHẬN CHUYỂN KHOẢN',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isPaid
                    ? 'Giao dịch đã được Ban Quản Lý phê duyệt hợp lệ'
                    : 'Đã gửi yêu cầu đối soát, BQL đang kiểm tra giao dịch',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildCopyableRow(
                      context,
                      label: 'Mã biên nhận',
                      value: receiptCode,
                      copyValue: receiptCode,
                    ),
                    const Divider(height: 16),
                    _buildCopyableRow(
                      context,
                      label: 'Căn hộ',
                      value: widget.invoice.apartment?.code ?? 'N/A',
                    ),
                    const Divider(height: 16),
                    _buildCopyableRow(
                      context,
                      label: 'Kỳ thu',
                      value: widget.invoice.period,
                    ),
                    const Divider(height: 16),
                    _buildCopyableRow(
                      context,
                      label: 'Số tiền thanh toán',
                      value: formatCurrency.format(widget.invoice.totalAmount),
                      isHighlight: true,
                    ),
                    const Divider(height: 16),
                    _buildCopyableRow(
                      context,
                      label: 'Phương thức',
                      value: widget.invoice.paymentMethod == 'DEMO' ? 'Demo Payment (Cổng điện tử)' : (widget.invoice.paymentMethod ?? 'Chuyển khoản trực tuyến'),
                    ),
                    if (widget.invoice.transactionCode != null) ...[
                      const Divider(height: 16),
                      _buildCopyableRow(
                        context,
                        label: 'Mã giao dịch',
                        value: widget.invoice.transactionCode!,
                        copyValue: widget.invoice.transactionCode!,
                      ),
                    ],
                    const Divider(height: 16),
                    _buildCopyableRow(
                      context,
                      label: 'Thời gian',
                      value: formatDate.format((widget.invoice.updatedAt ?? widget.invoice.createdAt).toLocal()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                label: const Text(
                  'Sao chép thông tin biên nhận',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final summary = 'BIÊN NHẬN THANH TOÁN PKA-HOME\n'
                      'Mã: $receiptCode\n'
                      'Căn hộ: ${widget.invoice.apartment?.code ?? "N/A"}\n'
                      'Kỳ: ${widget.invoice.period}\n'
                      'Số tiền: ${formatCurrency.format(widget.invoice.totalAmount)}\n'
                      'Trạng thái: ${isPaid ? "Đã thanh toán" : "Chờ xác nhận"}\n'
                      'Thời gian: ${formatDate.format((widget.invoice.updatedAt ?? widget.invoice.createdAt).toLocal())}';
                  Clipboard.setData(ClipboardData(text: summary));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép toàn bộ thông tin biên nhận'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
