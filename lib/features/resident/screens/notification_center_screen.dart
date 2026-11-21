import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
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
            icon: const Icon(Icons.done_all, color: AppTheme.primary),
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
      body: Column(
        children: [
          // Thanh lọc danh mục
          _buildFilterChips(activeFilter),

          // Nội dung danh sách
          Expanded(
            child: notificationsAsync.when(
              data: (allNotifications) {
                if (allNotifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Chưa có thông báo nào',
                            style: context.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bạn sẽ nhận được thông báo tự động khi có hóa đơn mới, lịch nhắc hạn thanh toán hoặc thông báo khẩn cấp từ Ban Quản Lý.',
                            textAlign: TextAlign.center,
                            style: context.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (filteredNotifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'Không có thông báo nào phù hợp với bộ lọc đã chọn',
                        style: context.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredNotifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filteredNotifications[index];
                    return _NotificationCard(notification: item);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Lỗi tải thông báo: $err',
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(String activeFilter) {
    final filters = [
      {'key': 'ALL', 'label': 'Tất cả'},
      {'key': 'UNREAD', 'label': 'Chưa đọc'},
      {'key': 'INVOICE', 'label': 'Hóa đơn & Phí'},
      {'key': 'BUILDING', 'label': 'Tòa nhà'},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = activeFilter == filter['key'];
          return ChoiceChip(
            label: Text(
              filter['label']!,
              style: context.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            selected: isSelected,
            selectedColor: AppTheme.primary,
            backgroundColor: Colors.grey.shade100,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppTheme.primary : Colors.grey.shade300,
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

  Color _getIconColor() {
    switch (notification.type) {
      case 'invoice_overdue':
        return AppTheme.error;
      case 'invoice_due_today':
        return AppTheme.warning;
      case 'invoice_due_soon':
      case 'invoice_due_reminder':
        return AppStatusColors.unpaid;
      case 'new_invoice':
        return AppTheme.primary;
      case 'equipment_maintenance':
        return AppTheme.warning;
      case 'issue_update':
        return AppTheme.secondary;
      default:
        return AppTheme.secondary;
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
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = _getIconColor();
    final isUnread = !notification.isRead;
    final badgeText = _getStatusBadgeText();

    final cardBgColor = isUnread
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerLow;

    final borderColor = isUnread
        ? iconColor.withValues(alpha: 0.5)
        : theme.colorScheme.outlineVariant;

    return Card(
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isUnread ? 1.5 : 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon loại thông báo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIconData(), color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Nội dung thông báo
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
                                  ? (isDark
                                        ? Colors.white
                                        : AppTheme.textPrimary)
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: iconColor.withValues(alpha: 0.3),
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
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: context.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white60
                            : (isUnread
                                  ? AppTheme.textSecondary
                                  : Colors.grey.shade600),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatNotificationTime(notification.createdAt),
                      style: context.labelSmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
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
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal());
    }
  }
}
