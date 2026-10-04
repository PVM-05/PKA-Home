import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/notification_provider.dart';
import 'resident_invoice_screen.dart';
import 'resident_issue_screen.dart';

/// Màn hình Trung tâm Thông báo & Nhắc nhở dành cho Cư dân.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thông báo & Nhắc nhở',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: AppTheme.primary),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: user == null
                ? null
                : () async {
                    await ref.read(notificationRepositoryProvider).markAllAsRead(user.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
                          backgroundColor: AppStatusColors.paid,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
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
                    const Text(
                      'Chưa có thông báo nào',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bạn sẽ nhận được thông báo tự động khi có hóa đơn mới, lịch nhắc hạn thanh toán hoặc thông báo khẩn cấp từ Ban Quản Lý.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = notifications[index];
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
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  Color _getIconColor() {
    switch (notification.type) {
      case 'invoice_due_reminder':
        return AppStatusColors.unpaid;
      case 'new_invoice':
        return AppTheme.primary;
      case 'equipment_maintenance':
        return const Color(0xFFE65100);
      case 'issue_update':
        return const Color(0xFF00897B);
      default:
        return AppTheme.secondary;
    }
  }

  IconData _getIconData() {
    switch (notification.type) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = _getIconColor();
    final isUnread = !notification.isRead;

    final cardBgColor = isUnread
        ? (isDark ? theme.colorScheme.surface : Colors.white)
        : (isDark ? theme.colorScheme.surface.withValues(alpha: 0.6) : Colors.grey.shade50);

    final borderColor = isUnread
        ? AppTheme.primary.withValues(alpha: 0.4)
        : (isDark ? theme.dividerColor.withValues(alpha: 0.2) : Colors.grey.shade200);

    return Card(
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
          width: isUnread ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (isUnread) {
            await ref.read(notificationRepositoryProvider).markAsRead(notification.id);
          }
          if (!context.mounted) return;

          if (notification.type == 'invoice_due_reminder' || notification.type == 'new_invoice') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ResidentInvoiceScreen()),
            );
          } else if (notification.type == 'issue_update') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ResidentIssueScreen()),
            );
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                              color: isUnread
                                  ? (isDark ? Colors.white : AppTheme.textPrimary)
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : (isUnread ? AppTheme.textSecondary : Colors.grey.shade600),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatNotificationTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 11,
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
      return timeago.format(dateTime, locale: 'vi');
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal());
    }
  }
}
