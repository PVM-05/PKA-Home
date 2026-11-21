import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vivona/core/router/route_names.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/widgets/app_card.dart';
import 'package:vivona/core/widgets/app_error_card.dart';
import 'package:vivona/core/widgets/app_skeleton_shimmer.dart';
import 'package:vivona/data/models/announcement_model.dart';
import 'package:vivona/features/resident/widgets/notification_card.dart';

class ResidentHomeAnnouncementsCard extends StatelessWidget {
  final AsyncValue<List<AnnouncementModel>> announcementsAsync;
  final VoidCallback onRetry;

  const ResidentHomeAnnouncementsCard({
    super.key,
    required this.announcementsAsync,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Thông báo mới nhất',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            announcementsAsync.maybeWhen(
              data: (announcements) => announcements.length > 3
                  ? TextButton(
                      onPressed: () => context.push(
                        AppRoutes.residentNotifications,
                      ),
                      child: const Text('Xem tất cả'),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        AppSpacing.h8,
        announcementsAsync.when(
          data: (announcements) {
            if (announcements.isEmpty) {
              return AppCard(
                padding: AppSpacing.p16,
                child: Center(
                  child: Text(
                    'Không có thông báo nào.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            final top3Announcements = announcements.take(3).toList();
            return Column(
              children: top3Announcements.map((announcement) {
                return NotificationCard(
                  title: announcement.title,
                  content: announcement.content,
                  date:
                      '${announcement.createdAt.day.toString().padLeft(2, '0')}/${announcement.createdAt.month.toString().padLeft(2, '0')}/${announcement.createdAt.year}',
                  onTap: () {
                    context.push(
                      AppRoutes.residentAnnouncementDetail,
                      extra: announcement,
                    );
                  },
                );
              }).toList(),
            );
          },
          loading: () => AppSkeletonShimmer.cardList(
            count: 2,
            itemHeight: 74,
            borderRadius: AppRadius.r16,
          ),
          error: (error, stack) => AppErrorCard(
            error: error,
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }
}
