import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/announcement_model.dart';
import '../../../data/providers/announcement_provider.dart';
import '../widgets/announcement/announcement_dialogs.dart';

class AnnouncementManagementScreen extends ConsumerWidget {
  const AnnouncementManagementScreen({super.key});

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'elevator_maintenance':
        return Icons.elevator_outlined;
      case 'utility_outage':
        return Icons.power_off_outlined;
      case 'resident_meeting':
        return Icons.groups_outlined;
      case 'general':
      default:
        return Icons.campaign_outlined;
    }
  }

  static Color getCategoryColor(String category, [BuildContext? context]) {
    switch (category) {
      case 'emergency':
        return context != null
            ? AppTheme.getSemanticError(context)
            : AppTheme.error;
      case 'elevator_maintenance':
      case 'utility_outage':
        return context != null
            ? AppTheme.getSemanticWarning(context)
            : AppTheme.warning;
      case 'resident_meeting':
        return context != null
            ? AppTheme.getSemanticSecondary(context)
            : AppTheme.secondary;
      case 'general':
      default:
        return context != null
            ? Theme.of(context).colorScheme.primary
            : AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_send_outlined),
            tooltip: 'Quét nhắc nợ hóa đơn',
            onPressed: () =>
                AnnouncementDialogs.triggerRemindersScan(context, ref),
          ),
        ],
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return ListView(
              padding: AppSpacing.p16,
              children: const [
                AppEmptyState(
                  icon: Icons.notifications_none_outlined,
                  title: 'Chưa có thông báo nào',
                  description:
                      'Bấm nút "Phát thông báo" bên dưới để tạo và gửi thông báo tới cư dân.',
                ),
              ],
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              if (isDesktop) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(announcementsStreamProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.p24,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1300),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  for (
                                    int i = 0;
                                    i < announcements.length;
                                    i += 2
                                  )
                                    _buildAnnouncementCard(
                                      context,
                                      ref,
                                      announcements[i],
                                    ),
                                ],
                              ),
                            ),
                            AppSpacing.w16,
                            Expanded(
                              child: Column(
                                children: [
                                  for (
                                    int i = 1;
                                    i < announcements.length;
                                    i += 2
                                  )
                                    _buildAnnouncementCard(
                                      context,
                                      ref,
                                      announcements[i],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(announcementsStreamProvider);
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView.builder(
                      padding: AppSpacing.p16,
                      itemCount: announcements.length,
                      itemBuilder: (context, index) => _buildAnnouncementCard(
                        context,
                        ref,
                        announcements[index],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 120),
          ],
        ),
        error: (error, _) => ListView(
          padding: AppSpacing.p16,
          children: [
            AppErrorCard(
              error: error,
              onRetry: () => ref.invalidate(announcementsStreamProvider),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'announcement_management_fab',
        icon: const Icon(Icons.campaign),
        label: const Text('Phát thông báo'),
        onPressed: () => AnnouncementDialogs.showCreateDialog(context, ref),
      ),
    );
  }

  Widget _buildAnnouncementCard(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel announcement,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final catColor = getCategoryColor(announcement.category, context);
    final catIcon = getCategoryIcon(announcement.category);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: AppSpacing.p16,
      borderColor: announcement.isUrgent
          ? errorColor.withValues(alpha: 0.45)
          : (announcement.isPinned
                ? colorScheme.primary.withValues(alpha: 0.35)
                : null),
      onTap: () => AnnouncementDialogs.showDetailDialog(context, announcement),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hàng 1: Chip danh mục & Ghim & Đối tượng + Nút thao tác
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (announcement.isPinned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: warningColor.withValues(alpha: 0.12),
                          borderRadius: AppRadius.r6,
                          border: Border.all(
                            color: warningColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.push_pin,
                                size: 12,
                                color: warningColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Đã ghim',
                                style: context.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: warningColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Badge Danh mục
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.r6,
                        border: Border.all(
                          color: catColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catIcon, size: 13, color: catColor),
                            AppSpacing.w4,
                            Text(
                              announcement.categoryDisplayName,
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Badge Phạm vi
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.r6,
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            AppSpacing.w4,
                            Text(
                              announcement.targetDisplayName,
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Thời gian tạo
                    Text(
                      DateFormat('dd/MM HH:mm').format(announcement.createdAt),
                      style: context.labelSmall?.tabularFigures().copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.w4,
              // Nút thao tác
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                    ),
                    tooltip: 'Phát lại thông báo đẩy',
                    color: colorScheme.primary,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => AnnouncementDialogs.handleRebroadcast(
                      context,
                      ref,
                      announcement,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Chỉnh sửa',
                    color: colorScheme.primary,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => AnnouncementDialogs.showEditDialog(
                      context,
                      ref,
                      announcement,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Xóa thông báo',
                    color: errorColor,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => AnnouncementDialogs.confirmDelete(
                      context,
                      ref,
                      announcement.id,
                      announcement.title,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppSpacing.h12,

          // Tiêu đề
          Text(
            announcement.title,
            style: context.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: announcement.isUrgent ? errorColor : colorScheme.onSurface,
            ),
          ),
          AppSpacing.h6,

          // Nội dung
          Text(
            announcement.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),

          // Khung giờ sự kiện / bảo trì (nếu có)
          if (announcement.eventStartAt != null &&
              announcement.eventEndAt != null) ...[
            AppSpacing.h12,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: announcement.isOngoing
                    ? warningColor.withValues(alpha: 0.1)
                    : colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(
                  color: announcement.isOngoing
                      ? warningColor.withValues(alpha: 0.35)
                      : colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    announcement.isOngoing
                        ? Icons.access_time_filled
                        : Icons.event_available,
                    size: 15,
                    color: announcement.isOngoing
                        ? warningColor
                        : colorScheme.primary,
                  ),
                  AppSpacing.w6,
                  Expanded(
                    child: Text(
                      'Thời gian: ${DateFormat('HH:mm dd/MM').format(announcement.eventStartAt!)} - ${DateFormat('HH:mm dd/MM').format(announcement.eventEndAt!)}${announcement.isOngoing ? " • Đang diễn ra" : ""}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.bodySmall?.tabularFigures().copyWith(
                        fontWeight: FontWeight.w600,
                        color: announcement.isOngoing
                            ? warningColor
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          AppSpacing.h12,
          const Divider(height: 1),
          AppSpacing.h8,

          // Thống kê tỷ lệ đọc tin & Hotline
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.w6,
                    Text(
                      'Đã phát: ${announcement.broadcastCount} • Đã đọc: ${announcement.readCount} (${announcement.readRatioPercentageText})',
                      style: context.labelSmall?.tabularFigures().copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (announcement.hotlineContact != null &&
                  announcement.hotlineContact!.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.r6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_in_talk,
                          size: 13,
                          color: colorScheme.primary,
                        ),
                        AppSpacing.w4,
                        Text(
                          announcement.hotlineContact!,
                          style: context.labelSmall?.tabularFigures().copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.h6,
          ClipRRect(
            borderRadius: AppRadius.r4,
            child: LinearProgressIndicator(
              value: announcement.readRatio,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                announcement.readRatio > 0.7
                    ? successColor
                    : (announcement.readRatio > 0.3
                          ? colorScheme.primary
                          : warningColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
