import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/utils/network_error_handler.dart';
import 'package:vivona/data/models/meter_reading_submission_model.dart';
import 'package:vivona/data/providers/meter_reading_provider.dart';

class MeterAnomalyDialogResult {
  final bool proceed;
  final String? explanation;

  const MeterAnomalyDialogResult({
    required this.proceed,
    this.explanation,
  });
}

Future<MeterAnomalyDialogResult> showMeterAnomalyConfirmDialog({
  required BuildContext context,
  required bool isDanger,
  required List<String> reasons,
}) async {
  final explanationController = TextEditingController();
  String? residentExplanation;

  try {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        final errorColor = AppTheme.getSemanticError(ctx);
        final warningColor = AppTheme.getSemanticWarning(ctx);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.r16,
          ),
          title: Row(
            children: [
              Icon(
                isDanger ? Icons.error_outline : Icons.warning_amber_rounded,
                color: isDanger ? errorColor : warningColor,
                size: 28,
              ),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  isDanger
                      ? 'Cảnh Báo Tiêu Thụ Tăng Vọt Nguy Hiểm'
                      : 'Cảnh Báo Tiêu Thụ Bất Thường',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDanger
                      ? 'Hệ thống AI phát hiện mức tiêu thụ tăng vọt bất thường (>300% so với trung bình các kỳ trước):'
                      : 'Hệ thống AI/OCR phát hiện mức tiêu thụ kỳ này có dấu hiệu tăng cao bất thường so với tháng trước:',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h12,
                ...reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $r',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDanger ? errorColor : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (isDanger) ...[
                  AppSpacing.h12,
                  TextField(
                    controller: explanationController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Giải trình lý do tăng cao (Bắt buộc) *',
                      hintText:
                          'VD: Lắp thêm thiết bị, gia đình có khách đông, sửa chữa...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  AppSpacing.h12,
                  Text(
                    'Bạn đã kiểm tra đối chiếu kỹ chữ số trên mặt công tơ thực tế chưa?',
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kiểm tra lại công tơ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDanger ? AppTheme.textError : AppTheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () {
                if (isDanger && explanationController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Vui lòng nhập giải trình lý do tiêu thụ tăng cao đột biến.',
                      ),
                      backgroundColor: AppTheme.textError,
                    ),
                  );
                  return;
                }
                residentExplanation = explanationController.text.trim();
                Navigator.pop(ctx, true);
              },
              child: const Text('Tôi đã kiểm tra & Tiếp tục gửi'),
            ),
          ],
        );
      },
    );

    return MeterAnomalyDialogResult(
      proceed: proceed == true,
      explanation: residentExplanation,
    );
  } finally {
    explanationController.dispose();
  }
}

Future<void> showEditMeterSubmissionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required MeterReadingSubmissionModel item,
}) async {
  final elecController = TextEditingController(
    text: item.electricReading.toString(),
  );
  final waterController = TextEditingController(
    text: item.waterReading.toString(),
  );
  final formKey = GlobalKey<FormState>();

  bool clearElectricImg = false;
  bool clearWaterImg = false;
  bool isSaving = false;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final theme = Theme.of(dialogCtx);
          final colorScheme = theme.colorScheme;
          final textTheme = theme.textTheme;
          final isDark = theme.brightness == Brightness.dark;
          final warningColor = AppTheme.getSemanticWarning(dialogCtx);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.r16,
            ),
            title: Row(
              children: [
                Icon(Icons.edit_note, color: colorScheme.primary),
                AppSpacing.w8,
                Expanded(child: Text('Sửa Chỉ Số Kỳ ${item.period}')),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn có thể điều chỉnh lại chỉ số điện nước khi phiếu đang chờ Ban Quản Lý phê duyệt.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.h16,
                    TextFormField(
                      controller: elecController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Chỉ số điện (kWh) *',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bolt, color: warningColor),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập chỉ số điện';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num < 0) {
                          return 'Chỉ số điện phải là số không âm';
                        }
                        return null;
                      },
                    ),
                    AppSpacing.h12,
                    TextFormField(
                      controller: waterController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Chỉ số nước (m³) *',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.water_drop,
                          color: colorScheme.primary,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập chỉ số nước';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num < 0) {
                          return 'Chỉ số nước phải là số không âm';
                        }
                        return null;
                      },
                    ),
                    AppSpacing.h12,
                    if (item.electricImageUrl != null)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Xóa ảnh công tơ điện đã gửi',
                          style: textTheme.bodyMedium,
                        ),
                        value: clearElectricImg,
                        onChanged: (val) => setDialogState(
                          () => clearElectricImg = val ?? false,
                        ),
                      ),
                    if (item.waterImageUrl != null)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Xóa ảnh công tơ nước đã gửi',
                          style: textTheme.bodyMedium,
                        ),
                        value: clearWaterImg,
                        onChanged: (val) => setDialogState(
                          () => clearWaterImg = val ?? false,
                        ),
                      ),
                    AppSpacing.h8,
                    Container(
                      padding: AppSpacing.p12,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.14 : 0.08,
                        ),
                        borderRadius: AppRadius.r8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          AppSpacing.w8,
                          Expanded(
                            child: Text(
                              'Hệ thống sẽ giữ nguyên ảnh công tơ trước đó nếu bạn không chủ động xóa.',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Đóng'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        final newElec = double.parse(
                          elecController.text.trim(),
                        );
                        final newWater = double.parse(
                          waterController.text.trim(),
                        );

                        setDialogState(() => isSaving = true);

                        try {
                          await ref
                              .read(meterReadingRepositoryProvider)
                              .updatePendingSubmission(
                                submissionId: item.id,
                                electricReading: newElec,
                                waterReading: newWater,
                                clearElectricImage: clearElectricImg,
                                clearWaterImage: clearWaterImg,
                              );

                          ref.invalidate(residentMeterReadingsProvider);

                          if (context.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cập nhật chỉ số điện nước thành công!',
                                ),
                                backgroundColor: AppTheme.textSuccess,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  NetworkErrorHandler.getMessage(e),
                                ),
                                backgroundColor: AppTheme.textError,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Lưu thay đổi'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    elecController.dispose();
    waterController.dispose();
  }
}

Future<void> showCancelMeterSubmissionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required MeterReadingSubmissionModel item,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final colorScheme = Theme.of(dialogCtx).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        title: const Text('Hủy Phiếu Khai Báo'),
        content: Text(
          'Bạn có chắc chắn muốn hủy phiếu khai báo chỉ số kỳ ${item.period} không? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Không'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textError,
              foregroundColor: colorScheme.onError,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(meterReadingRepositoryProvider)
                    .cancelPendingSubmission(item.id);
                ref.invalidate(residentMeterReadingsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã hủy phiếu khai báo chỉ số.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(NetworkErrorHandler.getMessage(e)),
                      backgroundColor: AppTheme.textError,
                    ),
                  );
                }
              }
            },
            child: const Text('Xác nhận hủy'),
          ),
        ],
      );
    },
  );
}
