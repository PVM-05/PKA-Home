import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/vietqr_helper.dart';
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
                        _buildSummaryCard(formatCurrency, formatDate),
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
        error: (error, stack) => Center(child: Text('Lỗi: $error')),
      ),
    );
  }

  Widget _buildSummaryCard(NumberFormat formatCurrency, DateFormat formatDate) {
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

    return Card(
      elevation: 4,
      shadowColor: statusColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [statusColor.withValues(alpha: 0.1), Colors.white],
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
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
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

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
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
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    if (widget.invoice.status != 'unpaid') {
      return const SizedBox.shrink();
    }

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
  }

  void _showPaymentBottomSheet(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final aptCode = widget.invoice.apartment?.code ?? 'N/A';
    final memo = VietQrHelper.buildTransferMemo(aptCode, widget.invoice.period);
    final qrUrl = VietQrHelper.generateBqlInvoiceQrUrl(
      apartmentCode: aptCode,
      period: widget.invoice.period,
      amount: widget.invoice.totalAmount,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
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
                  const Text(
                    'Thanh toán chuyển khoản VietQR',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Quét mã QR từ ứng dụng ngân hàng hoặc sao chép thông tin chuyển khoản bên dưới',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          qrUrl,
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 220,
                              height: 220,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 220,
                            height: 220,
                            color: Colors.grey.shade100,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code, size: 64, color: AppTheme.textSecondary),
                                SizedBox(height: 8),
                                Text('Quét mã ngân hàng', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildCopyableRow(
                          context,
                          label: 'Ngân hàng',
                          value: 'MBBank (Quân Đội)',
                          copyValue: 'MB',
                        ),
                        const Divider(height: 16),
                        _buildCopyableRow(
                          context,
                          label: 'Số tài khoản',
                          value: VietQrHelper.defaultAccountNo,
                          copyValue: VietQrHelper.defaultAccountNo,
                        ),
                        const Divider(height: 16),
                        _buildCopyableRow(
                          context,
                          label: 'Chủ tài khoản',
                          value: VietQrHelper.defaultAccountName,
                        ),
                        const Divider(height: 16),
                        _buildCopyableRow(
                          context,
                          label: 'Số tiền',
                          value: formatCurrency.format(widget.invoice.totalAmount),
                          copyValue: widget.invoice.totalAmount.toInt().toString(),
                        ),
                        const Divider(height: 16),
                        _buildCopyableRow(
                          context,
                          label: 'Nội dung CK',
                          value: memo,
                          copyValue: memo,
                          isHighlight: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _handlePaymentConfirmation(context),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'XÁC NHẬN ĐÃ CHUYỂN KHOẢN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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

  Future<void> _handlePaymentConfirmation(BuildContext context) async {
    Navigator.pop(context); // Đóng bottom sheet

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ResidentInvoiceService.confirmPayment(ref, widget.invoice.id);
      if (context.mounted) {
        Navigator.pop(context); // Đóng loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi thông báo thanh toán thành công! Ban Quản Lý sẽ sớm kiểm tra và duyệt.'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context); // Quay lại trang trước
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Đóng loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
