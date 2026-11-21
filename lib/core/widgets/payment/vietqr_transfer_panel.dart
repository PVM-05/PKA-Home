import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';

class VietQrTransferPanel extends StatelessWidget {
  final bool hasBankConfig;
  final bool hasValidMemo;
  final String vietQrString;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final String cleanMemo;
  final double amount;

  const VietQrTransferPanel({
    super.key,
    required this.hasBankConfig,
    required this.hasValidMemo,
    required this.vietQrString,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountName,
    required this.cleanMemo,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasBankConfig) {
      return const _PaymentWarningBanner(
        icon: Icons.warning_amber_rounded,
        message:
            'Ban Quản Lý chưa cấu hình tài khoản nhận tiền cho tòa nhà này. Vui lòng liên hệ trực tiếp BQL để được hướng dẫn thanh toán hoặc chọn phương thức Tiền mặt.',
      );
    }

    if (!hasValidMemo) {
      return const _PaymentWarningBanner(
        icon: Icons.warning_amber_rounded,
        message:
            'Khoản phí này chưa có mã thanh toán hợp lệ từ hệ thống máy chủ để đối soát tự động. Vui lòng liên hệ BQL hoặc chọn phương thức Tiền mặt.',
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentBlue = AppTheme.getSemanticSecondary(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 290;
              final qrBox = Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // Nền trắng bắt buộc để camera app ngân hàng quét QR chính xác ở cả Dark Mode
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: QrImageView(
                  key: ValueKey('vietqr_$vietQrString'),
                  data: vietQrString,
                  version: QrVersions.auto,
                  size: 112.0,
                ),
              );

              final infoColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bankName,
                    style: context.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'STK: $bankAccountNumber',
                    style: context.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tên: $bankAccountName',
                    style: context.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nội dung: $cleanMemo',
                    style: context.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accentBlue,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    qrBox,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: infoColumn),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  qrBox,
                  const SizedBox(width: 14),
                  Expanded(child: infoColumn),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _CopyChip(
                label: 'Sao chép STK',
                onPressed: () => _copyToClipboard(
                  context,
                  value: bankAccountNumber,
                  message: 'Đã sao chép số tài khoản vào bộ nhớ tạm',
                ),
              ),
              _CopyChip(
                label: 'Sao chép Nội dung',
                onPressed: () => _copyToClipboard(
                  context,
                  value: cleanMemo,
                  message: 'Đã sao chép nội dung chuyển khoản vào bộ nhớ tạm',
                ),
              ),
              _CopyChip(
                label: 'Sao chép Số tiền',
                onPressed: () => _copyToClipboard(
                  context,
                  value: amount.toInt().toString(),
                  message: 'Đã sao chép số tiền vào bộ nhớ tạm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Quét mã QR bằng ứng dụng ngân hàng bất kỳ để chuyển tiền nhanh 24/7.',
            textAlign: TextAlign.center,
            style: context.labelSmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          // Radar tín hiệu Realtime CDC SePay Webhook
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.4 : 0.24,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sync, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Hệ thống đang lắng nghe biến động số dư. Màn hình tự gạch nợ sau 2-3s.',
                    style: context.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
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

  void _copyToClipboard(
    BuildContext context, {
    required String value,
    required String message,
  }) {
    AppHaptics.selection();
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class VnpayInfoPanel extends StatelessWidget {
  final bool hasVnpayConfig;

  const VnpayInfoPanel({super.key, required this.hasVnpayConfig});

  @override
  Widget build(BuildContext context) {
    if (!hasVnpayConfig) {
      return const _PaymentWarningBanner(
        icon: Icons.info_outline,
        message:
            'Tòa nhà hiện chưa kích hoạt cổng thanh toán trực tuyến VNPay. Quý cư dân vui lòng sử dụng phương thức chuyển khoản VietQR hoặc nộp tiền mặt.',
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.4 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cổng thanh toán bảo mật VNPay 2.1.0',
                  style: context.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Giao dịch được bảo mật bởi chữ ký số HMAC-SHA512 và xác thực mã OTP qua ngân hàng. Hệ thống tự động gạch nợ ngay khi giao dịch thành công.',
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentWarningBanner extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PaymentWarningBanner({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warningColor = AppTheme.getSemanticWarning(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warningColor.withValues(alpha: isDark ? 0.45 : 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: warningColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _CopyChip({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ActionChip(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      avatar: Icon(Icons.copy_rounded, size: 15, color: colorScheme.primary),
      label: Text(
        label,
        style: context.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      backgroundColor: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : colorScheme.surface,
      side: BorderSide(
        color: colorScheme.primary.withValues(alpha: isDark ? 0.45 : 0.3),
      ),
      onPressed: onPressed,
    );
  }
}
