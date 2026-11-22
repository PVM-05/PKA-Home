import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/notification_provider.dart';

/// Màn hình Trung tâm Thông báo & Nhắc nhở dành cho Cư dân.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final filteredNotifications = ref.watch(filteredNotificationsProvider);
    final activeFilter = ref.watch(notificationFilterTypeProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thông báo & Nhắc nhở',
          style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(Icons.done_all, color: colorScheme.primary),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: user == null
                ? null
                : () async {
                    await ref
                        .read(notificationRepositoryProvider)
                        .markAllAsRead(user.id);
                    if (context.mounted) {
                      AppSnackBar.showSuccess(
                        context,
                        'Đã đánh dấu tất cả thông báo là đã đọc',
                      );
                    }
                  },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            children: [
              _buildFilterChips(context, activeFilter),
              Expanded(
                child: notificationsAsync.when(
                  data: (allNotifications) {
                    if (allNotifications.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.notifications_none,
                        title: 'Chưa có thông báo nào',
                        description:
                            'Bạn sẽ nhận được thông báo tự động khi có hóa đơn mới, lịch nhắc hạn thanh toán hoặc thông báo khẩn cấp từ Ban Quản Lý.',
                      );
                    }

                    if (filteredNotifications.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.filter_list_off_outlined,
                        title: 'Không có thông báo phù hợp',
                        description:
                            'Không có thông báo nào phù hợp với bộ lọc đã chọn.',
                      );
                    }

                    return ListView.separated(
                      padding: AppSpacing.p16,
                      itemCount: filteredNotifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _NotificationCard(
                        notification: filteredNotifications[index],
                      ),
                    );
                  },
                  loading: () => ListView(
                    padding: AppSpacing.p16,
                    children: [
                      AppSkeletonShimmer.cardList(count: 4, itemHeight: 96),
                    ],
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: AppSpacing.p16,
                      child: AppErrorCard(
                        error: err,
                        onRetry: () =>
                            ref.invalidate(notificationsStreamProvider),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, String activeFilter) {
    final colorScheme = Theme.of(context).colorScheme;
    const filters = [
      {'key': 'ALL', 'label': 'Tất cả'},
      {'key': 'UNREAD', 'label': 'Chưa đọc'},
      {'key': 'INVOICE', 'label': 'Hóa đơn & Phí'},
      {'key': 'BUILDING', 'label': 'Tòa nhà'},
    ];

    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => AppSpacing.w8,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = activeFilter == filter['key'];
          return ChoiceChip(
            materialTapTargetSize: MaterialTapTargetSize.padded,
            label: Text(
              filter['label']!,
              style: context.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            selected: isSelected,
            selectedColor: AppTheme.primary,
            backgroundColor: colorScheme.surfaceContainerLow,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            onSelected: (selected) {
              if (selected) {
                ref.read(notificationFilterTypeProvider.notifier).state =
                    filter['key']!;
              }
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  Color _getIconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (notification.type) {
      case 'invoice_overdue':
        return AppTheme.getSemanticError(context);
      case 'invoice_due_today':
      case 'equipment_maintenance':
        return AppTheme.getSemanticWarning(context);
      case 'invoice_due_soon':
      case 'invoice_due_reminder':
        return AppStatusColors.getUnpaid(context);
      case 'new_invoice':
        return colorScheme.primary;
      case 'issue_update':
      default:
        return AppTheme.getSemanticSecondary(context);
    }
  }

  IconData _getIconData() {
    switch (notification.type) {
      case 'invoice_overdue':
        return Icons.warning_amber_rounded;
      case 'invoice_due_today':
      case 'invoice_due_soon':
      case 'invoice_due_reminder':
        return Icons.alarm_outlined;
      case 'new_invoice':
        return Icons.receipt_long_outlined;
      case 'equipment_maintenance':
        return Icons.build_circle_outlined;
      case 'issue_update':
        return Icons.support_agent_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String? _getStatusBadgeText() {
    switch (notification.type) {
      case 'invoice_overdue':
        return 'Quá hạn';
      case 'invoice_due_today':
        return 'Hạn hôm nay';
      case 'invoice_due_soon':
        return 'Sắp đến hạn';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = _getIconColor(context);
    final isUnread = !notification.isRead;
    final badgeText = _getStatusBadgeText();

    final cardBgColor = isUnread
        ? colorScheme.surface
        : colorScheme.surfaceContainerLow;

    final borderColor = isUnread
        ? iconColor.withValues(alpha: isDark ? 0.6 : 0.45)
        : colorScheme.outlineVariant;

    return Card(
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.r16,
        side: BorderSide(color: borderColor, width: isUnread ? 1.5 : 1.0),
      ),
      child: InkWell(
        borderRadius: AppRadius.r16,
        onTap: () async {
          if (isUnread) {
            await ref
                .read(notificationRepositoryProvider)
                .markAsRead(notification.id);
          }
          if (!context.mounted) return;

          final currentUser = ref.read(authProvider).valueOrNull;
          final targetRoute = ref
              .read(pushNotificationServiceProvider)
              .resolveRouteFromNotification(
                {'type': notification.type},
                currentUser?.role,
              );
          if (targetRoute.isNotEmpty) {
            context.push(targetRoute);
          }
        },
        child: Padding(
          padding: AppSpacing.p16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(_getIconData(), color: iconColor, size: 22),
              ),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: context.titleSmall?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isUnread
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.78,
                                    ),
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          AppSpacing.w6,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(
                                alpha: isDark ? 0.18 : 0.10,
                              ),
                              borderRadius: AppRadius.r8,
                              border: Border.all(
                                color: iconColor.withValues(
                                  alpha: isDark ? 0.45 : 0.30,
                                ),
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: context.labelSmall?.copyWith(
                                color: iconColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isUnread) ...[
                          AppSpacing.w6,
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    AppSpacing.h6,
                    Text(
                      notification.body,
                      style: context.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    AppSpacing.h8,
                    Text(
                      _formatNotificationTime(notification.createdAt),
                      style: context.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 7) {
      try {
        return timeago.format(dateTime, locale: 'vi');
      } catch (_) {
        return timeago.format(dateTime);
      }
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal());
  }
}
