import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/invoice_model.dart';
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
              _buildBottomAction(context),
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

  Widget _buildBottomAction(BuildContext context) {
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
            _showPaymentBottomSheet(context);
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

  void _showPaymentBottomSheet(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'CỔNG THANH TOÁN ĐIỆN TỬ',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mô phỏng thanh toán trực tuyến bảo mật cho đồ án',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Thông tin hóa đơn tóm tắt
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Căn hộ: ${widget.invoice.apartment?.code ?? "N/A"}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Kỳ ${widget.invoice.period}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hạn nộp: ${DateFormat('dd/MM/yyyy').format(widget.invoice.dueDate)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Số tiền thanh toán:',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              formatCurrency.format(widget.invoice.totalAmount),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Thẻ phương thức thanh toán
                  const Text(
                    'Phương thức thanh toán:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Demo Payment (Sandbox)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mô phỏng gạch nợ tự động • Không mất phí',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.lock_outline, color: Colors.white, size: 18),
                    label: const Text(
                      'TIẾN HÀNH THANH TOÁN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: () {
                      _showConfirmationScenarioDialog(context, bottomSheetContext);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirmationScenarioDialog(BuildContext parentContext, BuildContext bottomSheetContext) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    showDialog(
      context: parentContext,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Xác Nhận Thanh Toán', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text('Tổng số tiền giao dịch', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency.format(widget.invoice.totalAmount),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn kịch bản kiểm thử để thực hiện:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Thanh toán thành công (Mô phỏng)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(bottomSheetContext);
                _executePayment(parentContext, 'SUCCESS');
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.highlight_off, size: 18),
              label: const Text('Thanh toán thất bại (Mô phỏng)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(bottomSheetContext);
                _executePayment(parentContext, 'FAILED');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy bỏ'),
          ),
        ],
      ),
    );
  }

  Future<void> _executePayment(BuildContext context, String outcome) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang xử lý giao dịch qua Cổng...', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final res = await ResidentInvoiceService.simulatePayment(
        ref: ref,
        invoiceId: widget.invoice.id,
        outcome: outcome,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Đóng loading dialog

      if (outcome == 'SUCCESS') {
        final txCode = res['transaction_code'] as String? ?? 'PAY-DEMO';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Column(
              children: [
                Icon(Icons.verified_rounded, color: AppTheme.success, size: 56),
                SizedBox(height: 12),
                Text('Thanh Toán Thành Công!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hóa đơn đã được gạch nợ tự động trên hệ thống.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mã giao dịch:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Text(txCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDigitalReceiptBottomSheet(context);
                },
                child: const Text('Xem biên nhận'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Xong'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanh toán thất bại: Giao dịch bị từ chối bởi cổng thanh toán (Thử nghiệm). Hóa đơn vẫn chưa thanh toán.'),
            backgroundColor: AppTheme.error,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Đóng loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
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
