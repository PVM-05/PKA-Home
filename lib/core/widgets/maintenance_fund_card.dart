import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Card thông tin Quỹ bảo trì 2% phần sở hữu chung theo Điều 108 Luật Nhà ở.
/// Cung cấp thông tin minh bạch về số dư, lãi suất tích lũy, mục đích sử dụng
/// và danh mục bảo trì định kỳ cho cả Cư dân và Ban Quản lý.
class MaintenanceFundCard extends StatefulWidget {
  final bool isManagement;

  const MaintenanceFundCard({
    super.key,
    this.isManagement = false,
  });

  @override
  State<MaintenanceFundCard> createState() => _MaintenanceFundCardState();
}

class _MaintenanceFundCardState extends State<MaintenanceFundCard> {
  bool _isExpanded = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  // Số liệu quỹ bảo trì chung cư minh bạch
  static const double _totalFundBalance = 2450000000.0; // 2,45 tỷ VNĐ
  static const double _annualInterestEarned = 127400000.0; // 127,4 triệu VNĐ tiền lãi ngân hàng
  static const double _interestRatePercent = 5.2; // Lãi suất tiết kiệm kỳ hạn 12 tháng
  static const double _collectedPercent = 98.5; // Tỷ lệ đã hoàn thành đóng quỹ
  static const String _bankAccountInfo = 'Vietcombank - Chi nhánh Thăng Long\nSTK Chuyên dùng: 0011 0042 88999';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề và biểu tượng
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quỹ bảo trì 2% sở hữu chung',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Theo Điều 108 Luật Nhà ở Việt Nam',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                  tooltip: _isExpanded ? 'Thu gọn' : 'Xem chi tiết',
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Thẻ số dư chính
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.08),
                    AppTheme.secondary.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Số dư quỹ khả dụng hiện tại',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currencyFormat.format(_totalFundBalance),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, color: AppTheme.success, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Lãi sinh lời gửi kỳ hạn ($_interestRatePercent%/năm): +${_currencyFormat.format(_annualInterestEarned)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Các chỉ số phụ
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tỷ lệ thu nộp',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '$_collectedPercent%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hình thức gửi',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'TK Chuyên dùng',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kiểm toán',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Hàng quý',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Phần chi tiết mở rộng
            if (_isExpanded) ...[
              const Divider(height: 24),
              _buildDetailItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Tài khoản ngân hàng lưu ký',
                content: _bankAccountInfo,
              ),
              const SizedBox(height: 10),
              _buildDetailItem(
                icon: Icons.verified_outlined,
                title: 'Mục đích sử dụng hợp pháp',
                content:
                    'Chỉ sử dụng để bảo trì các hạng mục thuộc sở hữu chung của tòa nhà (hệ thống thang máy, PCCC, máy biến áp dự phòng, chống thấm dột mặt ngoài và mái nhà).',
              ),
              const SizedBox(height: 10),
              _buildDetailItem(
                icon: Icons.block_outlined,
                title: 'Nghiêm cấm theo pháp luật',
                content:
                    'Tuyệt đối không sử dụng kinh phí bảo trì 2% cho mục đích quản lý vận hành tòa nhà, trả lương bộ máy nhân sự hoặc việc riêng ngoài danh mục bảo trì chung.',
                color: AppTheme.error,
              ),
              if (widget.isManagement) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warningBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.warningText, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lưu ý Ban Quản lý: Mọi khoản chi từ quỹ bảo trì phải có biên bản nghiệm thu kỹ thuật và hóa đơn VAT hợp pháp.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.warningText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String content,
    Color color = AppTheme.primary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color == AppTheme.error ? AppTheme.error : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
