import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/handover_pdf_builder.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/signature_pad_dialog.dart';
import '../../../data/models/apartment_handover_model.dart';
import '../../../data/models/handover_item_model.dart';
import '../../../data/providers/handover_provider.dart';

class ResidentHandoverDetailScreen extends ConsumerStatefulWidget {
  final String handoverId;

  const ResidentHandoverDetailScreen({
    super.key,
    required this.handoverId,
  });

  @override
  ConsumerState<ResidentHandoverDetailScreen> createState() =>
      _ResidentHandoverDetailScreenState();
}

class _ResidentHandoverDetailScreenState
    extends ConsumerState<ResidentHandoverDetailScreen> {
  bool _isActionLoading = false;

  Future<void> _openResidentSignaturePad() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (_) => const SignaturePadDialog(
        title: 'Chữ ký Cư dân',
        signerRole: 'Cư dân / Người nhận bàn giao',
      ),
    );

    if (bytes != null && mounted) {
      setState(() => _isActionLoading = true);
      try {
        final repo = ref.read(handoverRepositoryProvider);
        await repo.signByResident(widget.handoverId, bytes);
        ref.invalidate(handoverDetailProvider(widget.handoverId));
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            'Xác nhận bàn giao thành công!',
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, 'Lỗi ký xác nhận: $e');
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _openDisputeDialog() async {
    final disputeController = TextEditingController();

    try {
      final disputeText = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final colorScheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: const Text('Gửi ý kiến / Khiếu nại biên bản'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nếu bạn thấy thông tin kiểm kê hoặc chỉ số chưa chính xác, hãy nhập phản hồi để BQL kiểm tra lại:',
                  style: ctx.bodyMedium,
                ),
                AppSpacing.h12,
                TextField(
                  controller: disputeController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung phản ánh',
                    hintText:
                        'VD: Chỉ số nước ghi nhầm, bồn rửa mặt đã bị xước từ trước...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textError,
                  foregroundColor: colorScheme.onError,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () {
                  final text = disputeController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.of(ctx).pop(text);
                },
                child: const Text('Gửi khiếu nại'),
              ),
            ],
          );
        },
      );

      if (disputeText == null || disputeText.isEmpty || !mounted) return;

      setState(() => _isActionLoading = true);
      try {
        final repo = ref.read(handoverRepositoryProvider);
        await repo.disputeByResident(widget.handoverId, disputeText);
        ref.invalidate(handoverDetailProvider(widget.handoverId));
        if (mounted) {
          AppSnackBar.showWarning(
            context,
            'Đã gửi phản hồi khiếu nại tới BQL!',
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, 'Lỗi gửi khiếu nại: $e');
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    } finally {
      disputeController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(handoverDetailProvider(widget.handoverId));
    final handoverData = detailAsync.valueOrNull;
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết biên bản bàn giao'),
        elevation: 0.5,
        actions: [
          if (handoverData != null)
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Xuất file PDF',
              onPressed: () async {
                try {
                  final pdfBytes =
                      await HandoverPdfBuilder.buildHandoverReportPdf(
                        handover: handoverData,
                        items: handoverData.items,
                      );
                  await Printing.layoutPdf(
                    onLayout: (format) async => pdfBytes,
                    name: 'Bien_ban_ban_giao_${handoverData.reportCode}.pdf',
                  );
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.showError(context, 'Lỗi tạo PDF: $e');
                  }
                }
              },
            ),
        ],
      ),
      body: detailAsync.when(
        data: (handover) {
          if (handover == null) {
            return const Center(
              child: Padding(
                padding: AppSpacing.p24,
                child: AppEmptyState(
                  icon: Icons.assignment_late_outlined,
                  title: 'Không tìm thấy thông tin biên bản bàn giao',
                  description:
                      'Biên bản có thể đã bị thu hồi hoặc chưa được phân quyền xem.',
                ),
              ),
            );
          }

          if (isDesktop) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: AppSpacing.p24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildOverviewCard(context, handover),
                              AppSpacing.h16,
                              _buildMetersCard(context, handover),
                              if (handover.handoverType == 'move_out') ...[
                                AppSpacing.h16,
                                _buildDepositCard(context, handover),
                              ],
                              AppSpacing.h16,
                              _buildActionSection(context, handover),
                            ],
                          ),
                        ),
                      ),
                      AppSpacing.w24,
                      Expanded(
                        flex: 7,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildItemsSectionHeader(context, handover),
                              AppSpacing.h12,
                              _buildItemsList(context, handover),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: AppSpacing.p16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOverviewCard(context, handover),
                    AppSpacing.h16,
                    _buildMetersCard(context, handover),
                    if (handover.handoverType == 'move_out') ...[
                      AppSpacing.h16,
                      _buildDepositCard(context, handover),
                    ],
                    AppSpacing.h16,
                    _buildItemsSectionHeader(context, handover),
                    AppSpacing.h12,
                    _buildItemsList(context, handover),
                    AppSpacing.h24,
                    _buildActionSection(context, handover),
                    AppSpacing.h32,
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 3, itemHeight: 130)],
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: AppSpacing.p24,
            child: AppErrorCard(
              error: err,
              onRetry: () =>
                  ref.invalidate(handoverDetailProvider(widget.handoverId)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    ApartmentHandoverModel handover,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = AppTheme.getSemanticError(context);

    Color statusColor = colorScheme.onSurfaceVariant;
    if (handover.isConfirmed) statusColor = AppStatusColors.getPaid(context);
    if (handover.isPendingResident) {
      statusColor = AppTheme.getSemanticWarning(context);
    }
    if (handover.isDisputed) statusColor = errorColor;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  handover.reportCode,
                  style: context.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.w8,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: AppRadius.r8,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      handover.statusDisplayName,
                      style: context.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h8,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Căn hộ: ${handover.apartmentCode ?? 'A0110'}',
                style: context.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '• Loại: ${handover.handoverTypeDisplayName}',
                style: context.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          AppSpacing.h4,
          Text(
            'Nhân viên BQL: ${handover.staffName ?? 'Ban Quản Lý'} • Ngày: ${handover.handoverDate.day}/${handover.handoverDate.month}/${handover.handoverDate.year}',
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (handover.residentNotes != null &&
              handover.residentNotes!.isNotEmpty) ...[
            AppSpacing.h8,
            Container(
              padding: AppSpacing.p8,
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: AppRadius.r8,
              ),
              child: Text(
                'Ý kiến phản hồi: ${handover.residentNotes}',
                style: context.labelSmall?.copyWith(color: errorColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetersCard(
    BuildContext context,
    ApartmentHandoverModel handover,
  ) {
    final warningColor = AppTheme.getSemanticWarning(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chỉ số đồng hồ chốt bàn giao',
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h12,
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 280;
              final elecBox = _buildMeterBox(
                context: context,
                icon: Icons.bolt,
                color: warningColor,
                label: 'Chỉ số điện: ${handover.initialElectricityReading} kWh',
              );
              final waterBox = _buildMeterBox(
                context: context,
                icon: Icons.water_drop,
                color: primaryColor,
                label: 'Chỉ số nước: ${handover.initialWaterReading} m³',
              );

              if (isVeryNarrow) {
                return Column(
                  children: [
                    elecBox,
                    AppSpacing.h8,
                    waterBox,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: elecBox),
                  AppSpacing.w8,
                  Expanded(child: waterBox),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMeterBox({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: AppRadius.r8,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          AppSpacing.h4,
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: context.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositCard(
    BuildContext context,
    ApartmentHandoverModel handover,
  ) {
    final errorColor = AppTheme.getSemanticError(context);
    final successColor = AppStatusColors.getPaid(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chiết tính hoàn trả tiền đặt cọc',
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h12,
          Row(
            children: [
              const Expanded(child: Text('Tiền cọc ban đầu:')),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatCurrency(handover.depositHeld),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          Row(
            children: [
              const Expanded(child: Text('Khấu trừ hư hại thiết bị:')),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '-${_formatCurrency(handover.totalDeduction)}',
                  style: TextStyle(
                    color: errorColor,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Số tiền thực nhận lại:',
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatCurrency(handover.depositRefundCalculated),
                  style: context.titleMedium?.copyWith(
                    color: successColor,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSectionHeader(
    BuildContext context,
    ApartmentHandoverModel handover,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Danh sách hạng mục kiểm kê',
            style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        AppSpacing.w8,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: AppRadius.r8,
          ),
          child: Text(
            '${handover.items.length} hạng mục',
            style: context.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    ApartmentHandoverModel handover,
  ) {
    if (handover.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('Không có hạng mục kiểm kê nào trong biên bản'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: handover.items.length,
      separatorBuilder: (_, _) => AppSpacing.h8,
      itemBuilder: (context, index) =>
          _buildItemCard(context, handover.items[index]),
    );
  }

  Widget _buildItemCard(BuildContext context, HandoverItemModel item) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    final successColor = AppStatusColors.getPaid(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.w8,
              Chip(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                label: Text(
                  item.roomAreaDisplayName,
                  style: context.labelSmall,
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Tình trạng: ${item.conditionDisplayName}',
                style: context.bodySmall?.copyWith(
                  color: item.hasDamage ? errorColor : successColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (item.repairCost > 0)
                Text(
                  'Phí: ${_formatCurrency(item.repairCost)}',
                  style: context.bodySmall?.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty) ...[
            AppSpacing.h4,
            Text(
              'Ghi chú: ${item.note}',
              style: context.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    ApartmentHandoverModel handover,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = AppStatusColors.getPaid(context);
    final errorColor = AppTheme.getSemanticError(context);

    if (handover.isConfirmed) {
      return Container(
        padding: AppSpacing.p16,
        decoration: BoxDecoration(
          color: successColor.withValues(alpha: isDark ? 0.14 : 0.10),
          borderRadius: AppRadius.r12,
          border: Border.all(
            color: successColor.withValues(alpha: isDark ? 0.45 : 0.30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: successColor, size: 24),
            AppSpacing.w8,
            Flexible(
              child: Text(
                'Biên bản đã được hai bên ký xác nhận thành công',
                style: context.bodyMedium?.copyWith(
                  color: successColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (handover.isPendingResident) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _isActionLoading ? null : _openResidentSignaturePad,
            icon: const Icon(Icons.draw),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Ký tên xác nhận',
                style: context.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
            ),
          ),
          AppSpacing.h8,
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: errorColor,
              side: BorderSide(color: errorColor.withValues(alpha: 0.6)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
            ),
            onPressed: _isActionLoading ? null : _openDisputeDialog,
            icon: Icon(
              Icons.feedback_outlined,
              color: errorColor,
              size: 18,
            ),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Có ý kiến / Khiếu nại',
                style: TextStyle(
                  color: errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }
}
