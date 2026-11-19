import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/handover_pdf_builder.dart';
import '../../../core/widgets/app_card.dart';
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

  void _openResidentSignaturePad() async {
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
          AppSnackBar.showError(
            context,
            'Lỗi ký xác nhận: $e',
          );
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  void _openDisputeDialog() {
    final disputeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi ý kiến / Khiếu nại biên bản'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nếu bạn thấy thông tin kiểm kê hoặc chỉ số chưa chính xác, hãy nhập phản hồi để BQL kiểm tra lại:',
              style: ctx.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: disputeController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nội dung phản ánh',
                hintText:
                    'VD: Chỉ số nước ghi nhầm, bồn rửa mặt đã bị xước từ trước...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = disputeController.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop();

              setState(() => _isActionLoading = true);
              try {
                final repo = ref.read(handoverRepositoryProvider);
                await repo.disputeByResident(widget.handoverId, text);
                ref.invalidate(handoverDetailProvider(widget.handoverId));
                if (mounted) {
                  AppSnackBar.showWarning(
                    context,
                    'Đã gửi phản hồi khiếu nại tới BQL!',
                  );
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(
                    context,
                    'Lỗi gửi khiếu nại: $e',
                  );
                }
              } finally {
                if (mounted) setState(() => _isActionLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Gửi khiếu nại'),
          ),
        ],
      ),
    );
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
              child: Text('Không tìm thấy thông tin biên bản bàn giao'),
            );
          }

          if (isDesktop) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cột trái: Thông tin tổng quan, Chỉ số, Bảng cọc, Chữ ký
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildOverviewCard(handover),
                              const SizedBox(height: 16),
                              _buildMetersCard(handover),
                              if (handover.handoverType == 'move_out') ...[
                                const SizedBox(height: 16),
                                _buildDepositCard(handover),
                              ],
                              const SizedBox(height: 16),
                              _buildActionSection(handover),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Cột phải: Danh sách hạng mục kiểm kê
                      Expanded(
                        flex: 7,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildItemsSectionHeader(handover),
                              const SizedBox(height: 12),
                              _buildItemsList(handover),
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

          // Mobile layout (< 900dp)
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOverviewCard(handover),
                    const SizedBox(height: 16),
                    _buildMetersCard(handover),
                    if (handover.handoverType == 'move_out') ...[
                      const SizedBox(height: 16),
                      _buildDepositCard(handover),
                    ],
                    const SizedBox(height: 16),
                    _buildItemsSectionHeader(handover),
                    const SizedBox(height: 12),
                    _buildItemsList(handover),
                    const SizedBox(height: 24),
                    _buildActionSection(handover),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }

  Widget _buildOverviewCard(ApartmentHandoverModel handover) {
    Color statusColor = AppTheme.textSecondary;
    if (handover.isConfirmed) statusColor = AppStatusColors.paid;
    if (handover.isPendingResident) statusColor = AppTheme.warning;
    if (handover.isDisputed) statusColor = AppTheme.error;

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
                    color: AppTheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 4),
          Text(
            'Nhân viên BQL: ${handover.staffName ?? 'Ban Quản Lý'} • Ngày: ${handover.handoverDate.day}/${handover.handoverDate.month}/${handover.handoverDate.year}',
            style: context.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (handover.residentNotes != null &&
              handover.residentNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Ý kiến phản hồi: ${handover.residentNotes}',
                style: context.labelSmall?.copyWith(
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetersCard(ApartmentHandoverModel handover) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chỉ số đồng hồ chốt bàn giao',
            style: context.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 280;
              if (isVeryNarrow) {
                return Column(
                  children: [
                    _buildMeterBox(
                      icon: Icons.bolt,
                      color: Colors.amber.shade800,
                      label:
                          'Chỉ số điện: ${handover.initialElectricityReading} kWh',
                    ),
                    const SizedBox(height: 8),
                    _buildMeterBox(
                      icon: Icons.water_drop,
                      color: Colors.blue.shade700,
                      label:
                          'Chỉ số nước: ${handover.initialWaterReading} m³',
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildMeterBox(
                      icon: Icons.bolt,
                      color: Colors.amber.shade800,
                      label:
                          'Chỉ số điện: ${handover.initialElectricityReading} kWh',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMeterBox(
                      icon: Icons.water_drop,
                      color: Colors.blue.shade700,
                      label:
                          'Chỉ số nước: ${handover.initialWaterReading} m³',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMeterBox({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: context.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositCard(ApartmentHandoverModel handover) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chiết tính hoàn trả tiền đặt cọc',
            style: context.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('Tiền cọc ban đầu:')),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatCurrency(handover.depositHeld),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(child: Text('Khấu trừ hư hại thiết bị:')),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '-${_formatCurrency(handover.totalDeduction)}',
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
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
                    color: AppStatusColors.paid,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSectionHeader(ApartmentHandoverModel handover) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Danh sách hạng mục kiểm kê',
            style: context.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${handover.items.length} hạng mục',
            style: context.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(ApartmentHandoverModel handover) {
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
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = handover.items[index];
        return _buildItemCard(item);
      },
    );
  }

  Widget _buildItemCard(HandoverItemModel item) {
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
              const SizedBox(width: 8),
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
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Tình trạng: ${item.conditionDisplayName}',
                style: context.bodySmall?.copyWith(
                  color: item.hasDamage
                      ? AppTheme.error
                      : AppStatusColors.paid,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (item.repairCost > 0)
                Text(
                  'Phí: ${_formatCurrency(item.repairCost)}',
                  style: context.bodySmall?.copyWith(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú: ${item.note}',
              style: context.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionSection(ApartmentHandoverModel handover) {
    if (handover.isConfirmed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppStatusColors.paid.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppStatusColors.paid.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: AppStatusColors.paid, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Biên bản đã được hai bên ký xác nhận thành công',
                style: TextStyle(
                  color: AppStatusColors.paid,
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
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isActionLoading ? null : _openDisputeDialog,
            icon: const Icon(
              Icons.feedback_outlined,
              color: AppTheme.error,
              size: 18,
            ),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Có ý kiến / Khiếu nại',
                style: TextStyle(color: AppTheme.error),
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
