import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/network_error_handler.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_storage_image.dart';
import '../../../../data/models/building_utility_rate_model.dart';
import '../../../../data/models/meter_reading_submission_model.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/meter_reading_provider.dart';

class _BatchRowData {
  final TextEditingController aptController = TextEditingController();
  final TextEditingController electricController = TextEditingController();
  final TextEditingController waterController = TextEditingController();

  void dispose() {
    aptController.dispose();
    electricController.dispose();
    waterController.dispose();
  }
}

String _formatConsumed(double v) {
  if (v == v.roundToDouble()) {
    return v.toInt().toString();
  }
  return v.toStringAsFixed(1);
}

Future<void> showMeterBatchRecordDialog({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback onSuccessRefresh,
}) async {
  final now = DateTime.now();
  final defaultPeriod = '${now.month.toString().padLeft(2, '0')}/${now.year}';
  final periodController = TextEditingController(text: defaultPeriod);
  final formKey = GlobalKey<FormState>();
  final rows = <_BatchRowData>[_BatchRowData()];

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final theme = Theme.of(dialogCtx);
          final colorScheme = theme.colorScheme;
          final errorColor = AppTheme.getSemanticError(dialogCtx);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: Row(
              children: [
                Icon(Icons.flash_on, color: colorScheme.primary, size: 26),
                AppSpacing.w8,
                Expanded(
                  child: Text(
                    'Trạm Chốt Số Tiện Ích Theo Tầng',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kỹ thuật viên nhập đồng thời chỉ số điện và nước cho các căn hộ trong kỳ chốt số:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.h12,
                      TextFormField(
                        controller: periodController,
                        decoration: const InputDecoration(
                          labelText: 'Kỳ chốt số (MM/yyyy)',
                          hintText: 'VD: 11/2026',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_month, size: 20),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập kỳ chốt số';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.h16,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Danh sách căn hộ',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Thêm căn hộ'),
                            onPressed: () {
                              setDialogState(() {
                                rows.add(_BatchRowData());
                              });
                            },
                          ),
                        ],
                      ),
                      AppSpacing.h8,
                      Builder(
                        builder: (innerCtx) {
                          final isCompact =
                              MediaQuery.sizeOf(innerCtx).width < 500;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: rows.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final row = entry.value;

                              if (isCompact) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: AppSpacing.p12,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    borderRadius: AppRadius.r8,
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: row.aptController,
                                              decoration: InputDecoration(
                                                labelText: 'Căn hộ #${idx + 1}',
                                                hintText: 'A0110',
                                                border:
                                                    const OutlineInputBorder(),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 10,
                                                    ),
                                              ),
                                              validator: (val) {
                                                if (val == null ||
                                                    val.trim().isEmpty) {
                                                  return 'Cần mã căn';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          if (rows.length > 1) ...[
                                            AppSpacing.w4,
                                            IconButton(
                                              tooltip: 'Xóa dòng',
                                              icon: Icon(
                                                Icons.remove_circle_outline,
                                                color: errorColor,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setDialogState(() {
                                                  final removed = rows.removeAt(
                                                    idx,
                                                  );
                                                  removed.dispose();
                                                });
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                      AppSpacing.h8,
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller:
                                                  row.electricController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Điện (kWh)',
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 10,
                                                    ),
                                              ),
                                              validator: (val) {
                                                if (val == null ||
                                                    double.tryParse(
                                                          val.trim(),
                                                        ) ==
                                                        null) {
                                                  return 'Nhập số';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          AppSpacing.w8,
                                          Expanded(
                                            child: TextFormField(
                                              controller: row.waterController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Nước (m³)',
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 10,
                                                    ),
                                              ),
                                              validator: (val) {
                                                if (val == null ||
                                                    double.tryParse(
                                                          val.trim(),
                                                        ) ==
                                                        null) {
                                                  return 'Nhập số';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: row.aptController,
                                        decoration: InputDecoration(
                                          labelText: 'Căn hộ #${idx + 1}',
                                          hintText: 'A0110',
                                          border: const OutlineInputBorder(),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 12,
                                              ),
                                        ),
                                        validator: (val) {
                                          if (val == null ||
                                              val.trim().isEmpty) {
                                            return 'Cần mã căn';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    AppSpacing.w8,
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: row.electricController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Điện (kWh)',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 12,
                                          ),
                                        ),
                                        validator: (val) {
                                          if (val == null ||
                                              double.tryParse(val.trim()) ==
                                                  null) {
                                            return 'Nhập số';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    AppSpacing.w8,
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: row.waterController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Nước (m³)',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 12,
                                          ),
                                        ),
                                        validator: (val) {
                                          if (val == null ||
                                              double.tryParse(val.trim()) ==
                                                  null) {
                                            return 'Nhập số';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    if (rows.length > 1)
                                      IconButton(
                                        tooltip: 'Xóa dòng',
                                        icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: errorColor,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            final removed = rows.removeAt(idx);
                                            removed.dispose();
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                  shape: AppRadius.shapeSm,
                ),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final payload = rows
                        .map(
                          (r) => {
                            'apartment_code': r.aptController.text.trim(),
                            'electric_reading': double.parse(
                              r.electricController.text.trim(),
                            ),
                            'water_reading': double.parse(
                              r.waterController.text.trim(),
                            ),
                          },
                        )
                        .toList();

                    Navigator.pop(ctx, {
                      'period': periodController.text.trim(),
                      'payload': payload,
                    });
                  }
                },
                child: const Text('Xác nhận chốt số'),
              ),
            ],
          );
        },
      );
    },
  );

  if (result == null || !context.mounted) return;

  try {
    final period = result['period'] as String;
    final payload = result['payload'] as List<Map<String, dynamic>>;

    final res = await ref
        .read(meterReadingRepositoryProvider)
        .batchRecordReadings(period: period, readings: payload);

    onSuccessRefresh();

    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        res['message'] as String? ?? 'Đã chốt số hàng loạt thành công!',
      );
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, NetworkErrorHandler.getMessage(e));
    }
  }
}

Future<void> showMeterApproveDialog({
  required BuildContext context,
  required WidgetRef ref,
  required MeterReadingSubmissionModel item,
  required VoidCallback onSuccessRefresh,
}) async {
  final user = ref.read(authProvider).valueOrNull;
  if (user == null) return;

  bool generateInvoice = true;
  final defaultDueDate = DateTime.now().add(const Duration(days: 10));

  final rates = ref.read(buildingUtilityRatesProvider).valueOrNull ?? [];
  BuildingUtilityRateModel? elecRate;
  BuildingUtilityRateModel? waterRate;
  for (final r in rates) {
    if (r.utilityType == 'electricity') elecRate = r;
    if (r.utilityType == 'water') waterRate = r;
  }

  final double elecConsumed = item.effectiveElectricConsumed;
  final double waterConsumed = item.effectiveWaterConsumed;

  final double estElec = elecRate != null
      ? elecRate.calculateTotal(elecConsumed)
      : (elecConsumed * 3500 * 1.08);
  final double estWater = waterRate != null
      ? waterRate.calculateTotal(waterConsumed)
      : (waterConsumed * 25000 * 1.15);
  final double estTotal = estElec + estWater;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final theme = Theme.of(dialogCtx);
          final colorScheme = theme.colorScheme;
          final successColor = AppTheme.getSemanticSuccess(dialogCtx);
          final warningColor = AppTheme.getSemanticWarning(dialogCtx);
          final errorColor = AppTheme.getSemanticError(dialogCtx);
          final anomalyColor = item.isDangerAnomaly ? errorColor : warningColor;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: successColor,
                  size: 28,
                ),
                AppSpacing.w8,
                Expanded(
                  child: Text(
                    'Phê Duyệt Chỉ Số - Căn ${item.apartmentCode ?? ''}',
                    style: theme.textTheme.titleLarge?.copyWith(
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
                    'Kỳ: ${item.period} • Người gửi: ${item.submitterName ?? 'Cư dân'}',
                  ),
                  AppSpacing.h12,
                  if (item.hasAnomaly) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: AppSpacing.p12,
                      decoration: BoxDecoration(
                        color: anomalyColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: anomalyColor.withValues(alpha: 0.4),
                        ),
                        borderRadius: AppRadius.r8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.isDangerAnomaly
                                ? Icons.error_outline
                                : Icons.warning_amber_rounded,
                            color: anomalyColor,
                            size: 20,
                          ),
                          AppSpacing.w8,
                          Expanded(
                            child: Text(
                              'Cảnh báo ${item.anomalySeverityDisplayName}: ${item.anomalyReason ?? ''}. Đề nghị kỹ thuật kiểm tra thực tế trước khi phát hành hóa đơn!',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: anomalyColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: AppSpacing.p12,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.r12,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Tiêu thụ điện: ${_formatConsumed(elecConsumed)} kWh (Chỉ số: ${item.previousElectricReading ?? 0} → ${item.electricReading})',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)
                              .tabularFigures(),
                        ),
                        AppSpacing.h6,
                        Text(
                          '• Tiêu thụ nước: ${_formatConsumed(waterConsumed)} m³ (Chỉ số: ${item.previousWaterReading ?? 0} → ${item.waterReading})',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)
                              .tabularFigures(),
                        ),
                        AppSpacing.h8,
                        const Divider(height: 1),
                        AppSpacing.h8,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Ước tính phí tiện ích:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'vi_VN',
                                symbol: 'đ',
                              ).format(estTotal),
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  )
                                  .tabularFigures(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h16,
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Tự động tạo hóa đơn tháng cho căn hộ này',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Tính phí điện, nước theo chỉ số mới và phát hành công nợ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: generateInvoice,
                    activeColor: colorScheme.primary,
                    onChanged: (val) {
                      setDialogState(() {
                        generateInvoice = val ?? true;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                  shape: AppRadius.shapeSm,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xác nhận duyệt'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final res = await ref
        .read(meterReadingRepositoryProvider)
        .approveReading(
          submissionId: item.id,
          generateInvoice: generateInvoice,
          dueDate: defaultDueDate,
        );

    onSuccessRefresh();

    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        res['message'] as String? ?? 'Đã phê duyệt chỉ số thành công!',
      );
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, NetworkErrorHandler.getMessage(e));
    }
  }
}

Future<void> showMeterRejectDialog({
  required BuildContext context,
  required WidgetRef ref,
  required MeterReadingSubmissionModel item,
  required VoidCallback onSuccessRefresh,
}) async {
  final reasonController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final colorScheme = theme.colorScheme;
      final errorColor = AppTheme.getSemanticError(ctx);

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: errorColor, size: 28),
            AppSpacing.w8,
            Expanded(
              child: Text(
                'Từ Chối Chỉ Số - Căn ${item.apartmentCode ?? ''}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                  'Vui lòng nhập lý do từ chối để cư dân nắm được và thực hiện khai báo lại:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h12,
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'VD: Ảnh chụp đồng hồ nước bị mờ, không rõ 2 số cuối...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập lý do từ chối';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              minimumSize: const Size(0, 48),
              shape: AppRadius.shapeSm,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      );
    },
  );

  final reason = reasonController.text.trim();

  if (confirmed != true || !context.mounted) return;

  try {
    final res = await ref
        .read(meterReadingRepositoryProvider)
        .rejectReading(submissionId: item.id, reason: reason);

    onSuccessRefresh();

    if (context.mounted) {
      AppSnackBar.showInfo(
        context,
        res['message'] as String? ?? 'Đã từ chối chỉ số.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, NetworkErrorHandler.getMessage(e));
    }
  }
}

void showMeterImageDialog({
  required BuildContext context,
  required String title,
  required String imageUrl,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final colorScheme = theme.colorScheme;

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            AppStorageImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: const Padding(
                padding: AppSpacing.p32,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: Padding(
                padding: AppSpacing.p32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.h8,
                    Text(
                      'Không thể tải ảnh minh chứng',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
