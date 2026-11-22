import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/announcement_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/repositories/announcement_repository.dart';

class ResidentAnnouncementDetailScreen extends ConsumerStatefulWidget {
  final AnnouncementModel announcement;

  const ResidentAnnouncementDetailScreen({
    super.key,
    required this.announcement,
  });

  @override
  ConsumerState<ResidentAnnouncementDetailScreen> createState() =>
      _ResidentAnnouncementDetailScreenState();
}

class _ResidentAnnouncementDetailScreenState
    extends ConsumerState<ResidentAnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  void _markAsRead() {
    final user = ref.read(authProvider).valueOrNull;
    if (user != null && user.id.isNotEmpty) {
      ref
          .read(announcementRepositoryProvider)
          .markAnnouncementAsRead(widget.announcement.id, user.id);
    }
  }

  Color _getCategoryColor(BuildContext context, String category) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (category) {
      case 'emergency':
        return AppTheme.getSemanticError(context);
      case 'elevator_maintenance':
      case 'utility_outage':
        return AppTheme.getSemanticWarning(context);
      case 'resident_meeting':
        return AppTheme.getSemanticSecondary(context);
      case 'general':
      default:
        return colorScheme.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final announcement = widget.announcement;
    final dateFormat = DateFormat('dd/MM/yyyy - HH:mm');
    final formattedDate = dateFormat.format(announcement.createdAt);

    final catColor = _getCategoryColor(context, announcement.category);
    final catIcon = _getCategoryIcon(announcement.category);
    final errorColor = AppTheme.getSemanticError(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final successColor = AppTheme.getSemanticSuccess(context);
    final scheduleAccent = announcement.isOngoing
        ? warningColor
        : colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết thông báo'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: AppSpacing.p20,
                  borderColor: announcement.isUrgent
                      ? errorColor.withValues(alpha: isDark ? 0.55 : 0.45)
                      : (announcement.isPinned
                            ? colorScheme.primary.withValues(
                                alpha: isDark ? 0.45 : 0.35,
                              )
                            : null),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withValues(
                                alpha: isDark ? 0.18 : 0.10,
                              ),
                              borderRadius: AppRadius.r8,
                              border: Border.all(
                                color: catColor.withValues(
                                  alpha: isDark ? 0.45 : 0.30,
                                ),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(catIcon, size: 14, color: catColor),
                                  AppSpacing.w6,
                                  Text(
                                    announcement.categoryDisplayName
                                        .toUpperCase(),
                                    style: context.labelSmall?.copyWith(
                                      color: catColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (announcement.isPinned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: warningColor.withValues(
                                  alpha: isDark ? 0.18 : 0.10,
                                ),
                                borderRadius: AppRadius.r8,
                                border: Border.all(
                                  color: warningColor.withValues(
                                    alpha: isDark ? 0.45 : 0.35,
                                  ),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.push_pin,
                                      size: 13,
                                      color: warningColor,
                                    ),
                                    AppSpacing.w4,
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
                          if (announcement.isOngoing)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: successColor.withValues(
                                  alpha: isDark ? 0.18 : 0.10,
                                ),
                                borderRadius: AppRadius.r8,
                                border: Border.all(
                                  color: successColor.withValues(
                                    alpha: isDark ? 0.45 : 0.35,
                                  ),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.radio_button_checked,
                                      size: 12,
                                      color: successColor,
                                    ),
                                    AppSpacing.w4,
                                    Text(
                                      'Đang diễn ra',
                                      style: context.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      AppSpacing.h12,
                      Text(
                        announcement.title,
                        style: context.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: announcement.isUrgent
                              ? errorColor
                              : colorScheme.onSurface,
                        ),
                      ),
                      AppSpacing.h12,
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
                                  Icons.access_time,
                                  size: 15,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                AppSpacing.w6,
                                Text(
                                  formattedDate,
                                  style: context.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: isDark ? 0.18 : 0.08,
                              ),
                              borderRadius: AppRadius.r8,
                            ),
                            child: Text(
                              'Ban Quản Lý',
                              style: context.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (announcement.eventStartAt != null &&
                    announcement.eventEndAt != null) ...[
                  AppSpacing.h16,
                  AppCard(
                    color: scheduleAccent.withValues(
                      alpha: isDark ? 0.14 : 0.08,
                    ),
                    borderColor: scheduleAccent.withValues(
                      alpha: isDark ? 0.45 : 0.30,
                    ),
                    padding: AppSpacing.p16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 18,
                              color: scheduleAccent,
                            ),
                            AppSpacing.w8,
                            Expanded(
                              child: Text(
                                'Khung thời gian thực hiện',
                                style: context.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheduleAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.h8,
                        Text(
                          'Bắt đầu: ${DateFormat('HH:mm - dd/MM/yyyy').format(announcement.eventStartAt!)}\nKết thúc: ${DateFormat('HH:mm - dd/MM/yyyy').format(announcement.eventEndAt!)}',
                          style: context.bodySmall?.copyWith(
                            height: 1.45,
                            color: colorScheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (announcement.hotlineContact != null &&
                    announcement.hotlineContact!.isNotEmpty) ...[
                  AppSpacing.h16,
                  AppCard(
                    color: successColor.withValues(alpha: isDark ? 0.14 : 0.08),
                    borderColor: successColor.withValues(
                      alpha: isDark ? 0.45 : 0.30,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 360;
                        final hotlineInfo = Row(
                          children: [
                            Container(
                              padding: AppSpacing.p8,
                              decoration: BoxDecoration(
                                color: successColor.withValues(
                                  alpha: isDark ? 0.22 : 0.14,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phone_in_talk,
                                color: successColor,
                                size: 20,
                              ),
                            ),
                            AppSpacing.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hotline kỹ thuật viên trực ban',
                                    style: context.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  AppSpacing.h4,
                                  Text(
                                    announcement.hotlineContact!,
                                    style: context.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: successColor,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final callButton = ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.textSuccess,
                            foregroundColor: colorScheme.onPrimary,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.r12,
                            ),
                          ),
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text(
                            'Gọi ngay',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () =>
                              _makePhoneCall(announcement.hotlineContact!),
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              hotlineInfo,
                              AppSpacing.h12,
                              callButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: hotlineInfo),
                            AppSpacing.w8,
                            callButton,
                          ],
                        );
                      },
                    ),
                  ),
                ],

                AppSpacing.h16,

                AppCard(
                  padding: AppSpacing.p20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          AppSpacing.w8,
                          Expanded(
                            child: Text(
                              'Nội dung thông báo',
                              style: context.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        announcement.content,
                        style: context.bodyMedium?.copyWith(
                          height: 1.6,
                          color: colorScheme.onSurface,
                        ),
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
}
