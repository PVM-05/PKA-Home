import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/apartment_handover_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/handover_provider.dart';
import 'resident_handover_detail_screen.dart';

class ResidentHandoverScreen extends ConsumerWidget {
  final String? residentId;

  const ResidentHandoverScreen({
    super.key,
    this.residentId,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppStatusColors.paid;
      case 'pending_resident':
        return AppTheme.warning;
      case 'disputed':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveResidentId =
        residentId ?? ref.watch(authProvider).value?.id ?? 'res-01';
    final handoversAsync =
        ref.watch(residentHandoversProvider(effectiveResidentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên bản bàn giao căn hộ'),
        elevation: 0.5,
      ),
      body: handoversAsync.when(
        data: (handovers) {
          if (handovers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bạn chưa có biên bản bàn giao nào',
                    style: context.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: handovers.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = handovers[index];
                  return _buildHandoverCard(context, item);
                },
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
      ),
    );
  }

  Widget _buildHandoverCard(BuildContext context, ApartmentHandoverModel item) {
    final statusColor = _getStatusColor(item.status);

    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ResidentHandoverDetailScreen(handoverId: item.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.reportCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.statusDisplayName,
                        style: context.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Căn hộ: ${item.apartmentCode ?? 'A0110'}',
                  style: context.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    item.handoverTypeDisplayName,
                    style: context.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Đại diện BQL: ${item.staffName ?? 'Ban Quản Lý'} • Ngày: ${item.handoverDate.day}/${item.handoverDate.month}/${item.handoverDate.year}',
              style: context.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.isPendingResident
                          ? 'Bấm để kiểm tra & ký tên'
                          : 'Xem chi tiết biên bản',
                      style: context.bodySmall?.copyWith(
                        color: item.isPendingResident
                            ? AppTheme.warning
                            : AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 13,
                    color: item.isPendingResident
                        ? AppTheme.warning
                        : AppTheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
