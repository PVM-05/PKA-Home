import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/announcement_model.dart';
import '../../../data/providers/announcement_provider.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/notification_provider.dart';
import '../../../data/repositories/announcement_repository.dart';

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

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'emergency':
        return AppTheme.error;
      case 'elevator_maintenance':
        return Colors.orange.shade800;
      case 'utility_outage':
        return Colors.deepOrange;
      case 'resident_meeting':
        return Colors.purple;
      case 'general':
      default:
        return AppTheme.primary;
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
            onPressed: () => _triggerRemindersScan(context, ref),
          ),
        ],
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có thông báo nào',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildAnnouncementCard(AnnouncementModel announcement) {
            final catColor = getCategoryColor(announcement.category);
            final catIcon = getCategoryIcon(announcement.category);

            return AppCard(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              borderColor: announcement.isUrgent
                  ? AppTheme.error.withValues(alpha: 0.45)
                  : (announcement.isPinned
                      ? AppTheme.primary.withValues(alpha: 0.35)
                      : null),
              onTap: () => _showDetailDialog(context, announcement),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade400),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.push_pin, size: 12, color: Colors.amber.shade900),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Đã ghim',
                                        style: context.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Badge Danh mục
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: catColor.withValues(alpha: 0.3)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(catIcon, size: 13, color: catColor),
                                    const SizedBox(width: 4),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.group_outlined, size: 13, color: AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      announcement.targetDisplayName,
                                      style: context.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Thời gian tạo
                            Text(
                              DateFormat('dd/MM HH:mm').format(announcement.createdAt),
                              style: context.labelSmall?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Nút thao tác
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_active_outlined, size: 18),
                            tooltip: 'Phát lại thông báo đẩy (Re-broadcast)',
                            color: AppTheme.primary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => _handleRebroadcast(context, ref, announcement),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Chỉnh sửa',
                            color: AppTheme.primary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => _showEditDialog(context, ref, announcement),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Xóa thông báo',
                            color: AppTheme.error,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => _confirmDelete(context, ref, announcement.id, announcement.title),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tiêu đề
                  Text(
                    announcement.title,
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: announcement.isUrgent ? AppTheme.error : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Nội dung
                  Text(
                    announcement.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary, height: 1.4),
                  ),

                  // Khung giờ sự kiện / bảo trì (nếu có)
                  if (announcement.eventStartAt != null && announcement.eventEndAt != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: announcement.isOngoing
                            ? Colors.orange.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: announcement.isOngoing
                              ? Colors.orange.shade300
                              : Colors.blue.shade200,
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
                                ? Colors.orange.shade800
                                : Colors.blue.shade800,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Thời gian: ${DateFormat('HH:mm dd/MM').format(announcement.eventStartAt!)} - ${DateFormat('HH:mm dd/MM').format(announcement.eventEndAt!)}${announcement.isOngoing ? " • Đang diễn ra" : ""}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: announcement.isOngoing
                                    ? Colors.orange.shade900
                                    : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Thống kê tỷ lệ đọc tin & Hotline (Tự động xuống hàng an toàn khi màn hình hẹp)
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
                            Icon(Icons.mark_email_read_outlined, size: 15, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Đã phát: ${announcement.broadcastCount} • Đã đọc: ${announcement.readCount} (${announcement.readRatioPercentageText})',
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (announcement.hotlineContact != null && announcement.hotlineContact!.isNotEmpty)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_in_talk, size: 13, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  announcement.hotlineContact!,
                                  style: context.labelSmall?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: announcement.readRatio,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        announcement.readRatio > 0.7
                            ? AppTheme.success
                            : (announcement.readRatio > 0.3
                                ? AppTheme.primary
                                : Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
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
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1300),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  for (int i = 0; i < announcements.length; i += 2)
                                    buildAnnouncementCard(announcements[i]),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  for (int i = 1; i < announcements.length; i += 2)
                                    buildAnnouncementCard(announcements[i]),
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
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: announcements.length,
                      itemBuilder: (context, index) =>
                          buildAnnouncementCard(announcements[index]),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 120),
          ],
        ),
        error: (error, stack) => Center(
          child: AppErrorCard(
            error: error,
            onRetry: () => ref.invalidate(announcementsStreamProvider),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'announcement_management_fab',
        icon: const Icon(Icons.campaign),
        label: const Text('Phát thông báo'),
        onPressed: () => _showCreateDialog(context, ref),
      ),
    );
  }

  void _handleRebroadcast(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel announcement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('Phát lại thông báo đẩy', style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn có chắc chắn muốn phát lại thông báo:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                announcement.title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tiến độ hiện tại: Đã phát ${announcement.broadcastCount} lần • Đã đọc ${announcement.readCount} (${announcement.readRatioPercentageText})',
              style: ctx.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hệ thống sẽ gửi Push Notification mới tới tất cả cư dân. Vui lòng không phát lại liên tục.',
                      style: ctx.labelSmall?.copyWith(color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Xác nhận phát lại'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await runAction(
      context,
      () async {
        final res = await ref
            .read(announcementRepositoryProvider)
            .broadcastAnnouncement(announcement.id);
        final count = res['broadcast_count'] ?? 0;
        return res['message']?.toString() ?? 'Đã phát lại thông báo đẩy tới $count cư dân.';
      },
      actionName: 'Phát lại thông báo đẩy',
    );
  }

  void _triggerRemindersScan(BuildContext context, WidgetRef ref) async {
    final activeBuilding = ref.read(activeBuildingProvider).value;
    final buildingName = activeBuilding?.name ?? 'Tòa nhà hiện tại';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.schedule_send_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('Quét nhắc nợ hóa đơn', style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hệ thống sẽ quét toàn bộ các hóa đơn chưa thanh toán hoặc quá hạn trong $buildingName và gửi thông báo nhắc nợ tự động tới từng cư dân có công nợ.',
              style: ctx.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mỗi cư dân có hóa đơn cần thanh toán sẽ nhận được thông báo đẩy trên ứng dụng kèm chi tiết công nợ.',
                      style: ctx.bodySmall?.copyWith(color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Bắt đầu quét & gửi'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await runAction(
      context,
      () async {
        final count = await ref
            .read(notificationRepositoryProvider)
            .triggerInvoiceRemindersScan(buildingId: activeBuilding?.id);
        return 'Đã quét và phát sinh $count thông báo nhắc nợ thành công.';
      },
      actionName: 'Quét nhắc nợ hóa đơn',
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa thông báo'),
        content: Text('Bạn có chắc chắn muốn xóa thông báo "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(announcementRepositoryProvider).deleteAnnouncement(id);
                if (context.mounted) {
                  AppSnackBar.showSuccess(context, 'Đã xóa thông báo thành công');
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.showError(context, formatErrorMessage(e));
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final targetValueController = TextEditingController();
    final apartmentController = TextEditingController();
    final hotlineController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String category = 'general';
    String targetType = 'all';
    bool isUrgent = false;
    bool isPinned = false;
    bool autoBroadcast = false;
    bool isSubmitting = false;
    bool showLivePreview = false;

    DateTime? eventStartAt;
    DateTime? eventEndAt;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.campaign, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tạo & Phát sóng Thông báo',
                      style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: showLivePreview ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    icon: Icon(showLivePreview ? Icons.edit_note : Icons.phone_android, size: 18),
                    label: Text(showLivePreview ? 'Soạn thảo' : 'Xem trước'),
                    onPressed: () => setState(() => showLivePreview = !showLivePreview),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: showLivePreview
                    ? _buildLivePreviewWidget(
                        context,
                        title: titleController.text,
                        content: contentController.text,
                        category: category,
                        isUrgent: isUrgent,
                        isPinned: isPinned,
                        eventStartAt: eventStartAt,
                        eventEndAt: eventEndAt,
                        hotline: hotlineController.text,
                      )
                    : SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Danh mục thông báo
                              DropdownButtonFormField<String>(
                                initialValue: category,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Danh mục thông báo *',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'general',
                                    child: Text('Thông báo chung', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'emergency',
                                    child: Text('Sự cố khẩn cấp (Cháy/Nổ/Sự cố gấp)', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'elevator_maintenance',
                                    child: Text('Bảo trì thang máy', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'utility_outage',
                                    child: Text('Cúp điện / Cắt nước sinh hoạt', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'resident_meeting',
                                    child: Text('Họp cụm cư dân / Hội nghị nhà chung cư', overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      category = val;
                                      if (val == 'emergency') isUrgent = true;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // 2. Tiêu đề
                              TextFormField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Tiêu đề thông báo *',
                                  hintText: 'VD: Thông báo bảo trì thang máy Tháp A',
                                  prefixIcon: Icon(Icons.title),
                                ),
                                maxLength: 100,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Vui lòng nhập tiêu đề thông báo'
                                    : null,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                              ),
                              const SizedBox(height: 12),

                              // 3. Đối tượng nhận
                              DropdownButtonFormField<String>(
                                initialValue: targetType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Đối tượng nhận thông báo',
                                  prefixIcon: Icon(Icons.group_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('Tất cả cư dân (Toàn tòa)', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'block',
                                    child: Text('Theo Block (A hoặc B)', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'floor',
                                    child: Text('Theo Tầng', overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'apartment',
                                    child: Text('Căn hộ cụ thể (VD: A0110)', overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => targetType = val);
                                },
                              ),
                              if (targetType == 'block') ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: targetValueController,
                                  decoration: const InputDecoration(
                                    labelText: 'Mã Block nhận tin *',
                                    hintText: 'VD: A hoặc B',
                                    prefixIcon: Icon(Icons.apartment_outlined),
                                  ),
                                  validator: (v) => (targetType == 'block' && (v == null || v.trim().isEmpty))
                                      ? 'Vui lòng nhập mã Block'
                                      : null,
                                ),
                              ],
                              if (targetType == 'floor') ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: targetValueController,
                                  decoration: const InputDecoration(
                                    labelText: 'Số tầng nhận tin *',
                                    hintText: 'VD: 05 hoặc 12',
                                    prefixIcon: Icon(Icons.layers_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => (targetType == 'floor' && (v == null || v.trim().isEmpty))
                                      ? 'Vui lòng nhập số tầng'
                                      : null,
                                ),
                              ],
                              if (targetType == 'apartment') ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: apartmentController,
                                  decoration: const InputDecoration(
                                    labelText: 'Mã căn hộ nhận tin *',
                                    hintText: 'VD: A0110',
                                    prefixIcon: Icon(Icons.door_front_door_outlined),
                                  ),
                                  validator: (v) => targetType == 'apartment'
                                      ? validateApartmentCode(v)
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 12),

                              // 4. Khung giờ sự kiện / bảo trì (Tùy chọn)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.play_circle_outline, size: 16),
                                      label: Text(
                                        eventStartAt == null
                                            ? 'Giờ bắt đầu'
                                            : DateFormat('HH:mm dd/MM').format(eventStartAt!),
                                        style: context.bodySmall,
                                      ),
                                      onPressed: () async {
                                        final picked = await _pickDateTime(context, eventStartAt);
                                        if (picked != null) {
                                          setState(() => eventStartAt = picked);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.stop_circle_outlined, size: 16),
                                      label: Text(
                                        eventEndAt == null
                                            ? 'Giờ kết thúc'
                                            : DateFormat('HH:mm dd/MM').format(eventEndAt!),
                                        style: context.bodySmall,
                                      ),
                                      onPressed: () async {
                                        final picked = await _pickDateTime(context, eventEndAt ?? eventStartAt);
                                        if (picked != null) {
                                          setState(() => eventEndAt = picked);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 5. Hotline liên hệ nhanh
                              TextFormField(
                                controller: hotlineController,
                                decoration: const InputDecoration(
                                  labelText: 'Hotline kỹ thuật viên trực ban (Tùy chọn)',
                                  hintText: 'VD: 0901234567',
                                  prefixIcon: Icon(Icons.phone_in_talk_outlined),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),

                              // 6. Nội dung
                              TextFormField(
                                controller: contentController,
                                decoration: const InputDecoration(
                                  labelText: 'Nội dung chi tiết *',
                                  prefixIcon: Icon(Icons.notes),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 4,
                                maxLength: 1000,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Vui lòng nhập nội dung thông báo'
                                    : null,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                              ),
                              const SizedBox(height: 8),

                              // 7. Tùy chọn nâng cao
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Ghim đầu bảng tin cư dân', style: context.bodyMedium),
                                value: isPinned,
                                activeColor: AppTheme.primary,
                                onChanged: (val) => setState(() => isPinned = val ?? false),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Đánh dấu Khẩn cấp (Hiển thị nổi bật)', style: context.bodyMedium),
                                value: isUrgent,
                                activeColor: AppTheme.error,
                                onChanged: (val) => setState(() => isUrgent = val ?? false),
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Phát sóng thông báo tức thì (Push Broadcast)', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                                subtitle: Text('Mặc định tắt. Bật nếu muốn gửi thông báo đẩy tới thiết bị cư dân ngay khi tạo.', style: context.labelSmall),
                                value: autoBroadcast,
                                activeTrackColor: AppTheme.primary,
                                onChanged: (val) => setState(() => autoBroadcast = val),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton.icon(
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 16),
                  label: const Text('Phát sóng'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          setState(() => isSubmitting = true);
                          try {
                            final repo = ref.read(announcementRepositoryProvider);
                            final targetVal = targetType == 'apartment'
                                ? apartmentController.text.trim().toUpperCase()
                                : (targetType == 'all'
                                    ? null
                                    : targetValueController.text.trim());

                            final res = await repo.createAnnouncement(
                              title: titleController.text.trim(),
                              content: contentController.text.trim(),
                              isUrgent: isUrgent,
                              targetType: targetType,
                              targetValue: targetVal,
                              targetApartment: targetType == 'apartment' ? targetVal : null,
                              category: category,
                              eventStartAt: eventStartAt,
                              eventEndAt: eventEndAt,
                              isPinned: isPinned,
                              hotlineContact: hotlineController.text.trim().isEmpty ? null : hotlineController.text.trim(),
                              autoBroadcast: autoBroadcast,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppSnackBar.showSuccess(
                                context,
                                res['message']?.toString() ?? 'Tạo và phát sóng thông báo thành công!',
                              );
                            }
                          } catch (e) {
                            setState(() => isSubmitting = false);
                            if (context.mounted) {
                              AppSnackBar.showError(context, formatErrorMessage(e));
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLivePreviewWidget(
    BuildContext context, {
    required String title,
    required String content,
    required String category,
    required bool isUrgent,
    required bool isPinned,
    DateTime? eventStartAt,
    DateTime? eventEndAt,
    String? hotline,
  }) {
    final catColor = getCategoryColor(category);
    final catIcon = getCategoryIcon(category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Mô phỏng hiển thị trên App Cư dân',
                style: context.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Thẻ xem trước
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUrgent ? AppTheme.error : (isPinned ? AppTheme.primary : Colors.grey.shade300),
                width: isUrgent || isPinned ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(catIcon, size: 12, color: catColor),
                          const SizedBox(width: 4),
                          Text(
                            category == 'emergency'
                                ? 'Khẩn cấp'
                                : (category == 'elevator_maintenance'
                                    ? 'Bảo trì thang máy'
                                    : (category == 'utility_outage'
                                        ? 'Cúp điện / nước'
                                        : (category == 'resident_meeting' ? 'Họp cư dân' : 'Thông báo'))),
                            style: context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: catColor),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text('Vừa xong', style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title.trim().isEmpty ? '(Chưa có tiêu đề)' : title,
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? AppTheme.error : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content.trim().isEmpty ? '(Chưa có nội dung mô tả chi tiết...)' : content,
                  maxLines: 3,
                  style: context.bodySmall?.copyWith(color: AppTheme.textSecondary, height: 1.3),
                ),
                if (eventStartAt != null && eventEndAt != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Khung giờ: ${DateFormat('HH:mm dd/MM').format(eventStartAt)} - ${DateFormat('HH:mm dd/MM').format(eventEndAt)}',
                      style: context.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                  ),
                ],
                if (hotline != null && hotline.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_in_talk, size: 12, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text('Hotline: $hotline', style: context.labelSmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return date;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showDetailDialog(BuildContext context, AnnouncementModel announcement) {
    final catColor = getCategoryColor(announcement.category);
    final catIcon = getCategoryIcon(announcement.category);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: catColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(catIcon, size: 13, color: catColor),
                      const SizedBox(width: 4),
                      Text(
                        announcement.categoryDisplayName,
                        style: ctx.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: catColor),
                      ),
                    ],
                  ),
                ),
                if (announcement.isPinned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Text(
                      'Đã ghim',
                      style: ctx.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement.title,
              style: ctx.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: announcement.isUrgent ? AppTheme.error : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_outlined, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Đối tượng nhận: ${announcement.targetDisplayName}',
                    style: ctx.bodyMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ngày đăng: ${DateFormat('dd/MM/yyyy HH:mm').format(announcement.createdAt)}',
                style: ctx.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              if (announcement.eventStartAt != null && announcement.eventEndAt != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Thời gian hiệu lực: ${DateFormat('HH:mm dd/MM/yyyy').format(announcement.eventStartAt!)} đến ${DateFormat('HH:mm dd/MM/yyyy').format(announcement.eventEndAt!)}',
                    style: ctx.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                ),
              ],
              if (announcement.hotlineContact != null && announcement.hotlineContact!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Hotline kỹ thuật: ${announcement.hotlineContact}',
                  style: ctx.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                announcement.content,
                style: ctx.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Tiến độ xem tin: Đã phát ${announcement.broadcastCount} cư dân • Đã đọc ${announcement.readCount} (${announcement.readRatioPercentageText})',
                style: ctx.bodySmall?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel announcement,
  ) {
    final titleController = TextEditingController(text: announcement.title);
    final contentController = TextEditingController(text: announcement.content);
    final targetValueController = TextEditingController(text: announcement.targetValue ?? '');
    final apartmentController = TextEditingController(text: announcement.targetApartment ?? announcement.targetValue ?? '');
    final hotlineController = TextEditingController(text: announcement.hotlineContact ?? '');
    final formKey = GlobalKey<FormState>();

    String category = announcement.category;
    String targetType = announcement.targetType;
    bool isUrgent = announcement.isUrgent;
    bool isPinned = announcement.isPinned;
    bool isSubmitting = false;

    DateTime? eventStartAt = announcement.eventStartAt;
    DateTime? eventEndAt = announcement.eventEndAt;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Chỉnh sửa thông báo'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Danh mục thông báo'),
                        items: const [
                          DropdownMenuItem(value: 'general', child: Text('Thông báo chung', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'emergency', child: Text('Khẩn cấp', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'elevator_maintenance', child: Text('Bảo trì thang máy', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'utility_outage', child: Text('Cúp điện / nước', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'resident_meeting', child: Text('Họp cư dân', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Tiêu đề *'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tiêu đề' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: hotlineController,
                        decoration: const InputDecoration(labelText: 'Hotline kỹ thuật viên'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contentController,
                        decoration: const InputDecoration(labelText: 'Nội dung *'),
                        maxLines: 4,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập nội dung' : null,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ghim đầu bảng tin'),
                        value: isPinned,
                        onChanged: (val) => setState(() => isPinned = val ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Đánh dấu Khẩn cấp'),
                        value: isUrgent,
                        onChanged: (val) => setState(() => isUrgent = val ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;
                          setState(() => isSubmitting = true);
                          try {
                            final targetVal = targetType == 'apartment'
                                ? apartmentController.text.trim().toUpperCase()
                                : (targetType == 'all' ? null : targetValueController.text.trim());

                            await ref.read(announcementRepositoryProvider).updateAnnouncement(
                              id: announcement.id,
                              title: titleController.text.trim(),
                              content: contentController.text.trim(),
                              isUrgent: isUrgent,
                              targetType: targetType,
                              targetValue: targetVal,
                              targetApartment: targetType == 'apartment' ? targetVal : null,
                              category: category,
                              eventStartAt: eventStartAt,
                              eventEndAt: eventEndAt,
                              isPinned: isPinned,
                              hotlineContact: hotlineController.text.trim().isEmpty ? null : hotlineController.text.trim(),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppSnackBar.showSuccess(context, 'Cập nhật thông báo thành công');
                            }
                          } catch (e) {
                            setState(() => isSubmitting = false);
                            if (context.mounted) {
                              AppSnackBar.showError(context, formatErrorMessage(e));
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
