import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/vietnamese_currency_words.dart';
import '../../data/models/maintenance_fund_transaction_model.dart';

class AccountingVoucherDialog extends StatelessWidget {
  final MaintenanceFundTransactionModel transaction;
  final String buildingName;

  const AccountingVoucherDialog({
    super.key,
    required this.transaction,
    required this.buildingName,
  });

  static Future<void> show(
    BuildContext context, {
    required MaintenanceFundTransactionModel transaction,
    String buildingName = 'Ban Quản Lý Tòa Nhà',
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AccountingVoucherDialog(
        transaction: transaction,
        buildingName: buildingName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    final isIncome = transaction.isIncome;
    final title = isIncome ? 'PHIẾU THU' : 'PHIẾU CHI';
    final formCode = isIncome ? 'Mẫu 01-TT theo Thông tư 200/2014/TT-BTC' : 'Mẫu 02-TT theo Thông tư 200/2014/TT-BTC';
    final personLabel = isIncome ? 'Họ tên người nộp tiền:' : 'Họ tên người nhận tiền:';
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final amountWords = VietnameseCurrencyWords.toVietnameseWords(transaction.amount);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header đơn vị & mẫu biểu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buildingName.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quỹ bảo trì 2% sở hữu chung',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 4,
                    child: Text(
                      formCode,
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Tiêu đề chứng từ
              Center(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isIncome ? colorScheme.primary : errorColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Số: ${transaction.voucherNumber}',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ngày ${transaction.createdAt.day} tháng ${transaction.createdAt.month} năm ${transaction.createdAt.year}',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nội dung chi tiết
              _buildInfoRow(context, personLabel, transaction.recipientOrPayer, isBold: true),
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Lý do:', transaction.description),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Số tiền:',
                currencyFormat.format(transaction.amount),
                isBold: true,
                valueColor: isIncome ? colorScheme.primary : errorColor,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Viết bằng chữ:', amountWords, isItalic: true),
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Kèm theo chứng từ gốc:', transaction.referenceType ?? 'Phiếu nghiệm thu kỹ thuật'),
              const SizedBox(height: 24),

              // Chữ ký 4 bên
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSignBox(context, 'Giám đốc BQL', 'Ký và ghi rõ họ tên'),
                  _buildSignBox(context, 'Kế toán trưởng', 'Ký và ghi rõ họ tên'),
                  _buildSignBox(context, 'Người lập phiếu', 'Ký và ghi rõ họ tên'),
                  _buildSignBox(context, isIncome ? 'Người nộp tiền' : 'Người nhận tiền', 'Ký và ghi rõ họ tên'),
                ],
              ),
              const SizedBox(height: 24),

              // Nút hành động
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('In chứng từ'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã kết nối máy in văn phòng BQL.')),
                      );
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool isBold = false, bool isItalic = false, Color? valueColor}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 4,
          child: Text(label, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: valueColor ?? colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignBox(BuildContext context, String title, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onSurface), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
