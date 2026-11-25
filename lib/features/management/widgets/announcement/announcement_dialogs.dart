import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/action_runner.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../data/models/announcement_model.dart';
import '../../../../data/providers/building_provider.dart';
import '../../../../data/providers/notification_provider.dart';
import '../../../../data/repositories/announcement_repository.dart';
import '../../screens/announcement_management_screen.dart';

/// Các hộp thoại tạo mới, chỉnh sửa, chi tiết và phát sóng thông báo cho BQL
class AnnouncementDialogs {
  const AnnouncementDialogs._();

  static Future<void> handleRebroadcast(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel announcement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final warningColor = AppTheme.getSemanticWarning(ctx);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.send_rounded, color: colorScheme.primary),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Phát lại thông báo đẩy',
                  style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                  'Bạn có chắc chắn muốn phát lại thông báo:',
                  style: ctx.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                AppSpacing.h6,
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.r8,
                  ),
                  child: Text(
                    announcement.title,
                    style: ctx.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                AppSpacing.h12,
                Text(
                  'Tiến độ hiện tại: Đã phát ${announcement.broadcastCount} lần • Đã đọc ${announcement.readCount} (${announcement.readRatioPercentageText})',
                  style: ctx.bodySmall?.tabularFigures().copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h12,
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: warningColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.r8,
                    border: Border.all(
                      color: warningColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: warningColor, size: 18),
                      AppSpacing.w8,
                      Expanded(
                        child: Text(
                          'Hệ thống sẽ gửi Push Notification mới tới tất cả cư dân. Vui lòng không phát lại liên tục.',
                          style: ctx.labelSmall?.copyWith(color: warningColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 44),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Xác nhận phát lại'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await runAction(
      context,
      () async {
        final res = await ref
            .read(announcementRepositoryProvider)
            .broadcastAnnouncement(announcement.id);
        final count = res['broadcast_count'] ?? 0;
        return res['message']?.toString() ??
            'Đã phát lại thông báo đẩy tới $count cư dân.';
      },
      actionName: 'Phát lại thông báo đẩy',
    );
  }

  static Future<void> triggerRemindersScan(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final activeBuilding = ref.read(activeBuildingProvider).value;
    final buildingName = activeBuilding?.name ?? 'Tòa nhà hiện tại';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.schedule_send_rounded, color: colorScheme.primary),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Quét nhắc nợ hóa đơn',
                  style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                  'Hệ thống sẽ quét toàn bộ các hóa đơn chưa thanh toán hoặc quá hạn trong $buildingName và gửi thông báo nhắc nợ tự động tới từng cư dân có công nợ.',
                  style: ctx.bodyMedium,
                ),
                AppSpacing.h12,
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: AppRadius.r8,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      AppSpacing.w8,
                      Expanded(
                        child: Text(
                          'Mỗi cư dân có hóa đơn cần thanh toán sẽ nhận được thông báo đẩy trên ứng dụng kèm chi tiết công nợ.',
                          style: ctx.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 44),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Bắt đầu quét & gửi'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
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

  static void confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final errorColor = AppTheme.getSemanticError(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: const Text('Xóa thông báo'),
          content: Text('Bạn có chắc chắn muốn xóa thông báo "$title"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size(0, 44),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref
                      .read(announcementRepositoryProvider)
                      .deleteAnnouncement(id);
                  if (context.mounted) {
                    AppSnackBar.showSuccess(
                      context,
                      'Đã xóa thông báo thành công',
                    );
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
        );
      },
    );
  }

  static void showCreateDialog(BuildContext context, WidgetRef ref) {
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
            final colorScheme = Theme.of(context).colorScheme;
            final errorColor = AppTheme.getSemanticError(context);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
              title: Row(
                children: [
                  Icon(Icons.campaign, color: colorScheme.primary),
                  AppSpacing.w8,
                  Expanded(
                    child: Text(
                      'Tạo & Phát sóng Thông báo',
                      style: context.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: showLivePreview
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    icon: Icon(
                      showLivePreview ? Icons.edit_note : Icons.phone_android,
                      size: 18,
                    ),
                    label: Text(showLivePreview ? 'Soạn thảo' : 'Xem trước'),
                    onPressed: () =>
                        setState(() => showLivePreview = !showLivePreview),
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
                                    child: Text(
                                      'Thông báo chung',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'emergency',
                                    child: Text(
                                      'Sự cố khẩn cấp (Cháy/Nổ/Sự cố gấp)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'elevator_maintenance',
                                    child: Text(
                                      'Bảo trì thang máy',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'utility_outage',
                                    child: Text(
                                      'Cúp điện / Cắt nước sinh hoạt',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'resident_meeting',
                                    child: Text(
                                      'Họp cụm cư dân / Hội nghị nhà chung cư',
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                              AppSpacing.h12,
                              TextFormField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Tiêu đề thông báo *',
                                  hintText:
                                      'VD: Thông báo bảo trì thang máy Tháp A',
                                  prefixIcon: Icon(Icons.title),
                                ),
                                maxLength: 100,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Vui lòng nhập tiêu đề thông báo'
                                    : null,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                              ),
                              AppSpacing.h12,
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
                                    child: Text(
                                      'Tất cả cư dân (Toàn tòa)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'block',
                                    child: Text(
                                      'Theo Block (A hoặc B)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'floor',
                                    child: Text(
                                      'Theo Tầng',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'apartment',
                                    child: Text(
                                      'Căn hộ cụ thể (VD: A0110)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => targetType = val);
                                  }
                                },
                              ),
                              if (targetType == 'block') ...[
                                AppSpacing.h12,
                                TextFormField(
                                  controller: targetValueController,
                                  decoration: const InputDecoration(
                                    labelText: 'Mã Block nhận tin *',
                                    hintText: 'VD: A hoặc B',
                                    prefixIcon: Icon(Icons.apartment_outlined),
                                  ),
                                  validator: (v) =>
                                      (targetType == 'block' &&
                                          (v == null || v.trim().isEmpty))
                                      ? 'Vui lòng nhập mã Block'
                                      : null,
                                ),
                              ],
                              if (targetType == 'floor') ...[
                                AppSpacing.h12,
                                TextFormField(
                                  controller: targetValueController,
                                  decoration: const InputDecoration(
                                    labelText: 'Số tầng nhận tin *',
                                    hintText: 'VD: 05 hoặc 12',
                                    prefixIcon: Icon(Icons.layers_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      (targetType == 'floor' &&
                                          (v == null || v.trim().isEmpty))
                                      ? 'Vui lòng nhập số tầng'
                                      : null,
                                ),
                              ],
                              if (targetType == 'apartment') ...[
                                AppSpacing.h12,
                                TextFormField(
                                  controller: apartmentController,
                                  decoration: const InputDecoration(
                                    labelText: 'Mã căn hộ nhận tin *',
                                    hintText: 'VD: A0110',
                                    prefixIcon: Icon(
                                      Icons.door_front_door_outlined,
                                    ),
                                  ),
                                  validator: (v) => targetType == 'apartment'
                                      ? validateApartmentCode(v)
                                      : null,
                                ),
                              ],
                              AppSpacing.h12,
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                        size: 16,
                                      ),
                                      label: Text(
                                        eventStartAt == null
                                            ? 'Giờ bắt đầu'
                                            : DateFormat(
                                                'HH:mm dd/MM',
                                              ).format(eventStartAt!),
                                        style: context.bodySmall
                                            ?.tabularFigures(),
                                      ),
                                      onPressed: () async {
                                        final picked = await _pickDateTime(
                                          context,
                                          eventStartAt,
                                        );
                                        if (picked != null) {
                                          setState(() => eventStartAt = picked);
                                        }
                                      },
                                    ),
                                  ),
                                  AppSpacing.w8,
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.stop_circle_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        eventEndAt == null
                                            ? 'Giờ kết thúc'
                                            : DateFormat(
                                                'HH:mm dd/MM',
                                              ).format(eventEndAt!),
                                        style: context.bodySmall
                                            ?.tabularFigures(),
                                      ),
                                      onPressed: () async {
                                        final picked = await _pickDateTime(
                                          context,
                                          eventEndAt ?? eventStartAt,
                                        );
                                        if (picked != null) {
                                          setState(() => eventEndAt = picked);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              AppSpacing.h12,
                              TextFormField(
                                controller: hotlineController,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Hotline kỹ thuật viên trực ban (Tùy chọn)',
                                  hintText: 'VD: 0901234567',
                                  prefixIcon: Icon(
                                    Icons.phone_in_talk_outlined,
                                  ),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              AppSpacing.h12,
                              TextFormField(
                                controller: contentController,
                                decoration: const InputDecoration(
                                  labelText: 'Nội dung chi tiết *',
                                  prefixIcon: Icon(Icons.notes),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 4,
                                maxLength: 1000,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Vui lòng nhập nội dung thông báo'
                                    : null,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                              ),
                              AppSpacing.h8,
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Ghim đầu bảng tin cư dân',
                                  style: context.bodyMedium,
                                ),
                                value: isPinned,
                                activeColor: colorScheme.primary,
                                onChanged: (val) =>
                                    setState(() => isPinned = val ?? false),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Đánh dấu Khẩn cấp (Hiển thị nổi bật)',
                                  style: context.bodyMedium,
                                ),
                                value: isUrgent,
                                activeColor: errorColor,
                                onChanged: (val) =>
                                    setState(() => isUrgent = val ?? false),
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Phát sóng thông báo đẩy tức thì',
                                  style: context.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Mặc định tắt. Bật nếu muốn gửi thông báo đẩy tới thiết bị cư dân ngay khi tạo.',
                                  style: context.labelSmall,
                                ),
                                value: autoBroadcast,
                                activeTrackColor: colorScheme.primary,
                                onChanged: (val) =>
                                    setState(() => autoBroadcast = val),
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
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  icon: isSubmitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
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
                            final repo = ref.read(
                              announcementRepositoryProvider,
                            );
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
                              targetApartment: targetType == 'apartment'
                                  ? targetVal
                                  : null,
                              category: category,
                              eventStartAt: eventStartAt,
                              eventEndAt: eventEndAt,
                              isPinned: isPinned,
                              hotlineContact:
                                  hotlineController.text.trim().isEmpty
                                  ? null
                                  : hotlineController.text.trim(),
                              autoBroadcast: autoBroadcast,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppSnackBar.showSuccess(
                                context,
                                res['message']?.toString() ??
                                    'Tạo và phát sóng thông báo thành công!',
                              );
                            }
                          } catch (e) {
                            setState(() => isSubmitting = false);
                            if (context.mounted) {
                              AppSnackBar.showError(
                                context,
                                formatErrorMessage(e),
                              );
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

  static Widget _buildLivePreviewWidget(
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
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    final catColor = AnnouncementManagementScreen.getCategoryColor(
      category,
      context,
    );
    final catIcon = AnnouncementManagementScreen.getCategoryIcon(category);

    return Container(
      padding: AppSpacing.p16,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_android,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              AppSpacing.w6,
              Text(
                'Mô phỏng hiển thị trên App Cư dân',
                style: context.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppRadius.r12,
              border: Border.all(
                color: isUrgent
                    ? errorColor
                    : (isPinned
                          ? colorScheme.primary
                          : colorScheme.outlineVariant),
                width: isUrgent || isPinned ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.r4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(catIcon, size: 12, color: catColor),
                          AppSpacing.w4,
                          Text(
                            category == 'emergency'
                                ? 'Khẩn cấp'
                                : (category == 'elevator_maintenance'
                                      ? 'Bảo trì thang máy'
                                      : (category == 'utility_outage'
                                            ? 'Cúp điện / nước'
                                            : (category == 'resident_meeting'
                                                  ? 'Họp cư dân'
                                                  : 'Thông báo'))),
                            style: context.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: catColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Vừa xong',
                      style: context.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                AppSpacing.h8,
                Text(
                  title.trim().isEmpty ? '(Chưa có tiêu đề)' : title,
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? errorColor : colorScheme.onSurface,
                  ),
                ),
                AppSpacing.h4,
                Text(
                  content.trim().isEmpty
                      ? '(Chưa có nội dung mô tả chi tiết...)'
                      : content,
                  maxLines: 3,
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                if (eventStartAt != null && eventEndAt != null) ...[
                  AppSpacing.h8,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.r6,
                    ),
                    child: Text(
                      'Khung giờ: ${DateFormat('HH:mm dd/MM').format(eventStartAt)} - ${DateFormat('HH:mm dd/MM').format(eventEndAt)}',
                      style: context.labelSmall?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                if (hotline != null && hotline.isNotEmpty) ...[
                  AppSpacing.h8,
                  Row(
                    children: [
                      Icon(
                        Icons.phone_in_talk,
                        size: 12,
                        color: colorScheme.primary,
                      ),
                      AppSpacing.w4,
                      Text(
                        'Hotline: $hotline',
                        style: context.labelSmall?.tabularFigures().copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  static Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? initial,
  ) async {
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

  static void showDetailDialog(
    BuildContext context,
    AnnouncementModel announcement,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final warningColor = AppTheme.getSemanticWarning(ctx);
        final errorColor = AppTheme.getSemanticError(ctx);
        final catColor = AnnouncementManagementScreen.getCategoryColor(
          announcement.category,
          ctx,
        );
        final catIcon = AnnouncementManagementScreen.getCategoryIcon(
          announcement.category,
        );

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(catIcon, size: 13, color: catColor),
                        AppSpacing.w4,
                        Text(
                          announcement.categoryDisplayName,
                          style: ctx.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (announcement.isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: warningColor.withValues(alpha: 0.12),
                        borderRadius: AppRadius.r6,
                        border: Border.all(
                          color: warningColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Đã ghim',
                        style: ctx.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: warningColor,
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.h8,
              Text(
                announcement.title,
                style: ctx.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: announcement.isUrgent
                      ? errorColor
                      : colorScheme.onSurface,
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
                    Icon(
                      Icons.group_outlined,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    AppSpacing.w6,
                    Expanded(
                      child: Text(
                        'Đối tượng nhận: ${announcement.targetDisplayName}',
                        style: ctx.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.h6,
                Text(
                  'Ngày đăng: ${DateFormat('dd/MM/yyyy HH:mm').format(announcement.createdAt)}',
                  style: ctx.bodySmall?.tabularFigures().copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (announcement.eventStartAt != null &&
                    announcement.eventEndAt != null) ...[
                  AppSpacing.h12,
                  Container(
                    padding: AppSpacing.p8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.r8,
                    ),
                    child: Text(
                      'Thời gian hiệu lực: ${DateFormat('HH:mm dd/MM/yyyy').format(announcement.eventStartAt!)} đến ${DateFormat('HH:mm dd/MM/yyyy').format(announcement.eventEndAt!)}',
                      style: ctx.bodySmall?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                if (announcement.hotlineContact != null &&
                    announcement.hotlineContact!.isNotEmpty) ...[
                  AppSpacing.h8,
                  Text(
                    'Hotline kỹ thuật: ${announcement.hotlineContact}',
                    style: ctx.bodySmall?.tabularFigures().copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
                AppSpacing.h12,
                const Divider(height: 1),
                AppSpacing.h12,
                Text(
                  announcement.content,
                  style: ctx.bodyMedium?.copyWith(height: 1.5),
                ),
                AppSpacing.h16,
                const Divider(height: 1),
                AppSpacing.h8,
                Text(
                  'Tiến độ xem tin: Đã phát ${announcement.broadcastCount} cư dân • Đã đọc ${announcement.readCount} (${announcement.readRatioPercentageText})',
                  style: ctx.bodySmall?.tabularFigures().copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
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
        );
      },
    );
  }

  static void showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AnnouncementModel announcement,
  ) {
    final titleController = TextEditingController(text: announcement.title);
    final contentController = TextEditingController(text: announcement.content);
    final targetValueController = TextEditingController(
      text: announcement.targetValue ?? '',
    );
    final apartmentController = TextEditingController(
      text: announcement.targetApartment ?? announcement.targetValue ?? '',
    );
    final hotlineController = TextEditingController(
      text: announcement.hotlineContact ?? '',
    );
    final formKey = GlobalKey<FormState>();

    String category = announcement.category;
    String targetType = announcement.targetType;
    bool isUrgent = announcement.isUrgent;
    bool isPinned = announcement.isPinned;
    bool isSubmitting = false;

    final DateTime? eventStartAt = announcement.eventStartAt;
    final DateTime? eventEndAt = announcement.eventEndAt;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
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
                        decoration: const InputDecoration(
                          labelText: 'Danh mục thông báo',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'general',
                            child: Text(
                              'Thông báo chung',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'emergency',
                            child: Text(
                              'Khẩn cấp',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'elevator_maintenance',
                            child: Text(
                              'Bảo trì thang máy',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'utility_outage',
                            child: Text(
                              'Cúp điện / nước',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'resident_meeting',
                            child: Text(
                              'Họp cư dân',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => category = val);
                        },
                      ),
                      AppSpacing.h12,
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề *',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập tiêu đề'
                            : null,
                      ),
                      AppSpacing.h12,
                      TextFormField(
                        controller: hotlineController,
                        decoration: const InputDecoration(
                          labelText: 'Hotline kỹ thuật viên',
                        ),
                      ),
                      AppSpacing.h12,
                      TextFormField(
                        controller: contentController,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung *',
                        ),
                        maxLines: 4,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập nội dung'
                            : null,
                      ),
                      AppSpacing.h8,
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ghim đầu bảng tin'),
                        value: isPinned,
                        onChanged: (val) =>
                            setState(() => isPinned = val ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Đánh dấu Khẩn cấp'),
                        value: isUrgent,
                        onChanged: (val) =>
                            setState(() => isUrgent = val ?? false),
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
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setState(() => isSubmitting = true);
                          try {
                            final targetVal = targetType == 'apartment'
                                ? apartmentController.text.trim().toUpperCase()
                                : (targetType == 'all'
                                      ? null
                                      : targetValueController.text.trim());

                            await ref
                                .read(announcementRepositoryProvider)
                                .updateAnnouncement(
                                  id: announcement.id,
                                  title: titleController.text.trim(),
                                  content: contentController.text.trim(),
                                  isUrgent: isUrgent,
                                  targetType: targetType,
                                  targetValue: targetVal,
                                  targetApartment: targetType == 'apartment'
                                      ? targetVal
                                      : null,
                                  category: category,
                                  eventStartAt: eventStartAt,
                                  eventEndAt: eventEndAt,
                                  isPinned: isPinned,
                                  hotlineContact:
                                      hotlineController.text.trim().isEmpty
                                      ? null
                                      : hotlineController.text.trim(),
                                );
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppSnackBar.showSuccess(
                                context,
                                'Cập nhật thông báo thành công',
                              );
                            }
                          } catch (e) {
                            setState(() => isSubmitting = false);
                            if (context.mounted) {
                              AppSnackBar.showError(
                                context,
                                formatErrorMessage(e),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
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
