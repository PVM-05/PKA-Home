import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../../data/services/payment_service.dart';
import '../../data/providers/payment_provider.dart';
import '../utils/network_error_handler.dart';

enum _PaymentStep { confirmation, processing, success, pendingConfirmation, failed }

/// Hàm tiện ích mở Bottom Sheet Thanh toán dùng chung
Future<PaymentResult?> showUnifiedPaymentSheet({
  required BuildContext context,
  required PaymentType type,
  required String referenceId,
  required String title,
  required String referenceCode,
  required double amount,
  List<Map<String, dynamic>>? feeBreakdown,
}) {
  return showModalBottomSheet<PaymentResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => UnifiedPaymentSheet(
      type: type,
      referenceId: referenceId,
      title: title,
      referenceCode: referenceCode,
      amount: amount,
      feeBreakdown: feeBreakdown,
    ),
  );
}

class UnifiedPaymentSheet extends ConsumerStatefulWidget {
  final PaymentType type;
  final String referenceId;
  final String title;
  final String referenceCode;
  final double amount;
  final List<Map<String, dynamic>>? feeBreakdown;

  const UnifiedPaymentSheet({
    super.key,
    required this.type,
    required this.referenceId,
    required this.title,
    required this.referenceCode,
    required this.amount,
    this.feeBreakdown,
  });

  @override
  ConsumerState<UnifiedPaymentSheet> createState() => _UnifiedPaymentSheetState();
}

class _UnifiedPaymentSheetState extends ConsumerState<UnifiedPaymentSheet> {
  _PaymentStep _step = _PaymentStep.confirmation;
  String _selectedMethod = 'bank_transfer'; // 'bank_transfer' | 'cash'
  PaymentResult? _result;
  String? _errorMessage;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  bool _isSubmitting = false;

  Future<void> _startPayment() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _step = _PaymentStep.processing;
    });

    try {
      // Giả lập độ trễ mạng/gateway 1.2s - 1.5s tạo trải nghiệm thực tế
      await Future.delayed(const Duration(milliseconds: 1400));

      final controller = ref.read(paymentControllerProvider);
      final res = await controller.pay(
        type: widget.type,
        referenceId: widget.referenceId,
        paymentMethod: _selectedMethod,
        outcome: 'SUCCESS',
      );

      if (mounted) {
        setState(() {
          _result = res;
          _errorMessage = res.errorMessage != null
              ? NetworkErrorHandler.getMessage(res.errorMessage!)
              : null;
          if (res.isPending || res.status == 'PENDING') {
            _step = _PaymentStep.pendingConfirmation;
          } else if (res.success) {
            _step = _PaymentStep.success;
          } else {
            _step = _PaymentStep.failed;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = NetworkErrorHandler.getMessage(e);
          _step = _PaymentStep.failed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCurrentStep(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_step) {
      case _PaymentStep.confirmation:
        return _buildConfirmationStep(context);
      case _PaymentStep.processing:
        return _buildProcessingStep(context);
      case _PaymentStep.pendingConfirmation:
        return _buildPendingConfirmationStep(context);
      case _PaymentStep.success:
        return _buildSuccessStep(context);
      case _PaymentStep.failed:
        return _buildFailedStep(context);
    }
  }

  Widget _buildConfirmationStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      key: const ValueKey('step_confirmation'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        Text(
          widget.referenceCode,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),

        // Cảnh báo mô phỏng demo phục vụ đồ án
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quy trình mô phỏng phục vụ đánh giá đồ án. Hệ thống không trừ tiền tài khoản thực tế.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(
                'TỔNG TIỀN THANH TOÁN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _currencyFormat.format(widget.amount),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (widget.feeBreakdown != null && widget.feeBreakdown!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Chi tiết các khoản',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
            child: Column(
              children: widget.feeBreakdown!.map((item) {
                final name = item['name'] as String? ?? '';
                final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 13)),
                      Text(
                        _currencyFormat.format(amount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Chọn hình thức thanh toán',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Lựa chọn 1: Chuyển khoản mô phỏng
        InkWell(
          onTap: () {
            setState(() {
              _selectedMethod = 'bank_transfer';
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _selectedMethod == 'bank_transfer'
                  ? AppTheme.primary.withValues(alpha: 0.06)
                  : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedMethod == 'bank_transfer' ? AppTheme.primary : (isDark ? Colors.white12 : Colors.grey.shade200),
                width: _selectedMethod == 'bank_transfer' ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedMethod == 'bank_transfer' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: _selectedMethod == 'bank_transfer' ? AppTheme.primary : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chuyển khoản (VietQR Mô Phỏng)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Gửi xác nhận đã chuyển để BQL kiểm tra và gạch nợ',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.qr_code_2, color: AppTheme.primary, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Thông tin QR mô phỏng nếu chọn chuyển khoản
        if (_selectedMethod == 'bank_transfer') ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          QrImageView(
                            data: 'PKA-HOME-DEMO-PAYMENT|REF:${widget.referenceCode}|AMT:${widget.amount.toInt()}',
                            version: QrVersions.auto,
                            size: 110.0,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DEMO ONLY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NGÂN HÀNG QUÂN ĐỘI (MB)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'STK: 88889999DEMO',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Tên: BQL CHUNG CƯ PKA-HOME',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Nội dung: ${widget.referenceCode}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '💡 Mã QR trên là dữ liệu mô phỏng nội bộ đồ án, không dùng để giao dịch thật.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Lựa chọn 2: Tiền mặt tại quầy
        InkWell(
          onTap: () {
            setState(() {
              _selectedMethod = 'cash';
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _selectedMethod == 'cash'
                  ? AppTheme.primary.withValues(alpha: 0.06)
                  : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedMethod == 'cash' ? AppTheme.primary : (isDark ? Colors.white12 : Colors.grey.shade200),
                width: _selectedMethod == 'cash' ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedMethod == 'cash' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: _selectedMethod == 'cash' ? AppTheme.primary : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tiền mặt tại văn phòng Ban Quản Lý',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Đến quầy nộp tiền trực tiếp và nhận biên nhận giấy',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.payments_outlined, color: AppTheme.primary, size: 24),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          onPressed: _isSubmitting ? null : _startPayment,
          child: _isSubmitting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'ĐANG GỬI THÔNG BÁO...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : const Text(
                  'GỬI THÔNG BÁO THANH TOÁN',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildProcessingStep(BuildContext context) {
    return Padding(
      key: const ValueKey('step_processing'),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Đang gửi thông báo thanh toán...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(widget.amount),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hệ thống đang ghi nhận yêu cầu vào sổ kế toán và chuyển đến BQL',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Bước hiển thị khi yêu cầu ở trạng thái PENDING (Chờ Ban Quản Lý xác nhận)
  Widget _buildPendingConfirmationStep(BuildContext context) {
    final txCode = _result?.transactionCode ?? 'PENDING-001';
    final dateStr = _dateFormat.format(_result?.paidAt ?? DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: Colors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top, color: Colors.orange, size: 48),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Đã gửi thông báo thanh toán',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Chờ Ban Quản Lý xác nhận',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _currencyFormat.format(widget.amount),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              _buildInfoRow('Mã yêu cầu', txCode, isHighlight: true),
              const Divider(height: 16),
              _buildInfoRow('Nội dung', widget.title),
              const Divider(height: 16),
              _buildInfoRow('Thời gian gửi', dateStr),
              const Divider(height: 16),
              _buildInfoRow(
                'Hình thức',
                _selectedMethod == 'bank_transfer'
                    ? 'Chuyển khoản (Mô phỏng)'
                    : 'Tiền mặt tại BQL',
              ),
              const Divider(height: 16),
              _buildInfoRow('Trạng thái', 'Chờ Ban Quản Lý đối soát'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            Navigator.pop(context, _result);
          },
          child: const Text(
            'ĐÃ HIỂU',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSuccessStep(BuildContext context) {
    final txCode = _result?.transactionCode ?? 'SUCCESS-001';
    final dateStr = _dateFormat.format(_result?.paidAt ?? DateTime.now());

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
              color: AppTheme.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: AppTheme.success, size: 54),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Thanh toán thành công',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.success),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _currencyFormat.format(widget.amount),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              _buildInfoRow('Mã giao dịch', txCode, isHighlight: true),
              const Divider(height: 16),
              _buildInfoRow('Nội dung', widget.title),
              const Divider(height: 16),
              _buildInfoRow('Thời gian', dateStr),
              const Divider(height: 16),
              _buildInfoRow(
                'Phương thức',
                _selectedMethod == 'bank_transfer' ? 'Chuyển khoản (Mô phỏng)' : 'Tiền mặt tại BQL',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            Navigator.pop(context, _result);
          },
          child: const Text(
            'HOÀN TẤT',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFailedStep(BuildContext context) {
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
              color: AppTheme.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: AppTheme.error, size: 54),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Giao dịch không thành công',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.error),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _errorMessage ?? 'Đã xảy ra sự cố trong quá trình gửi thông báo giao dịch.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('ĐÓNG', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : _startPayment,
                child: const Text('THỬ LẠI', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppTheme.primary : null,
            ),
          ),
        ),
      ],
    );
  }
}
