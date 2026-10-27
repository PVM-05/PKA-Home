import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../utils/vietnamese_currency_words.dart';
import '../../data/models/invoice_model.dart';
import '../../data/providers/building_provider.dart';

/// Hàm tiện ích mở Bottom Sheet Biên lai thu tiền điện tử
Future<void> showElectronicReceiptSheet({
  required BuildContext context,
  required InvoiceModel invoice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ElectronicReceiptSheet(invoice: invoice),
  );
}

class ElectronicReceiptSheet extends ConsumerWidget {
  final InvoiceModel invoice;

  const ElectronicReceiptSheet({super.key, required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDateTime = DateFormat('dd/MM/yyyy HH:mm');

    final activeBuilding = ref.watch(activeBuildingProvider).value;
    final buildingName = activeBuilding?.name ?? 'TÒA NHÀ PKA LANDMARK';
    final receiptNumber = invoice.displayReceiptNumber;
    final lookupCode = invoice.displayLookupCode;
    final paidDate = invoice.paidAt ?? invoice.createdAt;
    final amountWords = VietnameseCurrencyWords.toVietnameseWords(invoice.totalAmount);
    final paymentMethodLabel = (invoice.paymentMethod?.toLowerCase().contains('cash') == true ||
            invoice.paymentMethod?.toLowerCase().contains('tiền mặt') == true)
        ? 'Tiền mặt'
        : 'Chuyển khoản VietQR';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppTheme.primary, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'BIÊN LAI THU TIỀN ĐIỆN TỬ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFFBFDFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tên đơn vị thu & tiêu ngữ
                    Text(
                      'BAN QUẢN LÝ $buildingName'.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hệ thống Quản lý Chung cư PKA-Home',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Tiêu đề phiếu thu
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'PHIẾU THU TIỀN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Số: $receiptNumber',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            'Mã tra cứu: $lookupCode',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Thông tin chi tiết
                    _buildReceiptRow('Căn hộ nộp tiền', invoice.apartment?.code ?? 'A0110', isBold: true),
                    const SizedBox(height: 8),
                    _buildReceiptRow('Kỳ thu phí', 'Tháng ${invoice.period}'),
                    const SizedBox(height: 8),
                    _buildReceiptRow('Thời gian thanh toán', formatDateTime.format(paidDate)),
                    const SizedBox(height: 8),
                    _buildReceiptRow('Hình thức thanh toán', paymentMethodLabel),
                    if (invoice.transactionCode != null && invoice.transactionCode!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildReceiptRow('Mã giao dịch', invoice.transactionCode!),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Số tiền bằng số và bằng chữ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'TỔNG TIỀN THU:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          formatCurrency.format(invoice.totalAmount),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bằng chữ: ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: Text(
                              amountWords,
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Dấu mộc điện tử "ĐÃ THU TIỀN"
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green.shade700, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'ĐÃ THU TIỀN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd/MM/yyyy').format(paidDate),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Biên lai điện tử có giá trị xác nhận nghĩa vụ tài chính hoàn tất giữa Cư dân và Ban Quản Lý.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom action button: Chia sẻ biên lai
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text(
                  'Chia sẻ biên lai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  final text = '''
[BIÊN LAI THU TIỀN ĐIỆN TỬ]
Ban Quản Lý: $buildingName
Số biên lai: $receiptNumber
Mã tra cứu: $lookupCode
Căn hộ: ${invoice.apartment?.code ?? 'A0110'}
Kỳ phí: ${invoice.period}
Số tiền: ${formatCurrency.format(invoice.totalAmount)}
Bằng chữ: $amountWords
Hình thức: $paymentMethodLabel
Thời gian: ${formatDateTime.format(paidDate)}
Trạng thái: ĐÃ THU TIỀN
''';
                  Share.share(text.trim(), subject: 'Biên lai thu tiền điện tử - $receiptNumber');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
