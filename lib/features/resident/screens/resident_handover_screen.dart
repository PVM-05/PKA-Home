import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
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

  Color _getStatusColor(BuildContext context, String status) {
    switch (status) {
      case 'confirmed':
        return AppStatusColors.getPaid(context);
      case 'pending_resident':
        return AppTheme.getSemanticWarning(context);
      case 'disputed':
        return AppTheme.getSemanticError(context);
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveResidentId =
        residentId ?? ref.watch(authProvider).value?.id ?? 'res-01';
    final handoversAsync = ref.watch(
      residentHandoversProvider(effectiveResidentId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên bản bàn giao căn hộ'),
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(residentHandoversProvider(effectiveResidentId));
        },
        child: handoversAsync.when(
          data: (handovers) {
            if (handovers.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 64,
                ),
                children: const [
                  AppEmptyState(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Bạn chưa có biên bản bàn giao nào',
                    description:
                        'Biên bản nhận nhà hoặc trả nhà từ Ban Quản Lý sẽ hiển thị tại đây để bạn kiểm tra và ký xác nhận.',
                  ),
                ],
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppSpacing.p16,
                  itemCount: handovers.length,
                  separatorBuilder: (_, _) => AppSpacing.h12,
                  itemBuilder: (context, index) =>
                      _buildHandoverCard(context, handovers[index]),
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
                onRetry: () => ref.invalidate(
                  residentHandoversProvider(effectiveResidentId),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandoverCard(BuildContext context, ApartmentHandoverModel item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(context, item.status);
    final actionColor = item.isPendingResident
        ? AppTheme.getSemanticWarning(context)
        : colorScheme.primary;

    return AppCard(
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
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.18 : 0.08,
                    ),
                    borderRadius: AppRadius.r8,
                  ),
                  child: Text(
                    item.reportCode,
                    style: context.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              AppSpacing.w8,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: AppRadius.r8,
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
          AppSpacing.h12,
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
          AppSpacing.h6,
          Text(
            'Đại diện BQL: ${item.staffName ?? 'Ban Quản Lý'} • Ngày: ${item.handoverDate.day}/${item.handoverDate.month}/${item.handoverDate.year}',
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.h12,
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
                      color: actionColor,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppSpacing.w4,
                Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: actionColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
