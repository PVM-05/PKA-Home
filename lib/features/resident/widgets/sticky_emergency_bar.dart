import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/route_names.dart';
import '../../../data/providers/announcement_provider.dart';

/// Widget banner nổi bật hiển thị các thông báo khẩn cấp hoặc bảo trì đang diễn ra
class StickyEmergencyBar extends ConsumerWidget {
  const StickyEmergencyBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencies = ref.watch(activeEmergencyAnnouncementsProvider);
    if (emergencies.isEmpty) {
      return const SizedBox.shrink();
    }

    final topEmergency = emergencies.first;
    final isEmergency = topEmergency.category == 'emergency' || topEmergency.isUrgent;
    final isElevator = topEmergency.category == 'elevator_maintenance';
    final isUtility = topEmergency.category == 'utility_outage';

    final Color bgColor = isEmergency
        ? Colors.red.shade50
        : (isElevator
            ? Colors.orange.shade50
            : (isUtility ? Colors.deepOrange.shade50 : Colors.amber.shade50));
    final Color borderColor = isEmergency
        ? Colors.red.shade400
        : (isElevator
            ? Colors.orange.shade400
            : (isUtility ? Colors.deepOrange.shade400 : Colors.amber.shade600));
    final Color textColor = isEmergency
        ? Colors.red.shade900
        : (isElevator
            ? Colors.orange.shade900
            : (isUtility ? Colors.deepOrange.shade900 : Colors.amber.shade900));
    final IconData icon = isEmergency
        ? Icons.warning_amber_rounded
        : (isElevator
            ? Icons.elevator_outlined
            : (isUtility ? Icons.power_off_outlined : Icons.campaign_outlined));

    String timeText = '';
    if (topEmergency.eventStartAt != null && topEmergency.eventEndAt != null) {
      timeText = ' (${DateFormat('HH:mm').format(topEmergency.eventStartAt!)} - ${DateFormat('HH:mm dd/MM').format(topEmergency.eventEndAt!)})';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      topEmergency.categoryDisplayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: textColor,
                      ),
                    ),
                    if (topEmergency.isOngoing) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: textColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Đang diễn ra',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${topEmergency.title}$timeText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: textColor.withValues(alpha: 0.1),
              foregroundColor: textColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              context.push(
                AppRoutes.residentAnnouncementDetail,
                extra: topEmergency,
              );
            },
            child: const Text(
              'Chi tiết',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

