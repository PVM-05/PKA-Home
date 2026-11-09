import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
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

  Color _getCategoryColor(String category) {
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
    final announcement = widget.announcement;
    final dateFormat = DateFormat('dd/MM/yyyy - HH:mm');
    final formattedDate = dateFormat.format(announcement.createdAt);

    final catColor = _getCategoryColor(announcement.category);
    final catIcon = _getCategoryIcon(announcement.category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết thông báo'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thẻ tiêu đề và trạng thái
                AppCard(
                  padding: const EdgeInsets.all(20.0),
                  borderColor: announcement.isUrgent
                      ? AppTheme.error.withValues(alpha: 0.45)
                      : (announcement.isPinned
                          ? AppTheme.primary.withValues(alpha: 0.35)
                          : null),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Badge Danh mục
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: catColor.withValues(alpha: 0.3)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(catIcon, size: 14, color: catColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    announcement.categoryDisplayName.toUpperCase(),
                                    style: TextStyle(
                                      color: catColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (announcement.isPinned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.push_pin, size: 13, color: Colors.amber),
                                    SizedBox(width: 4),
                                    Text(
                                      'Đã ghim',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (announcement.isOngoing)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.radio_button_checked, size: 12, color: Colors.green.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Đang diễn ra',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        announcement.title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: announcement.isUrgent ? AppTheme.error : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                const Icon(Icons.access_time, size: 15, color: AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Ban Quản Lý',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Khung giờ sự kiện / bảo trì (nếu có)
                if (announcement.eventStartAt != null && announcement.eventEndAt != null) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    color: announcement.isOngoing ? Colors.orange.shade50 : Colors.blue.shade50,
                    borderColor: announcement.isOngoing ? Colors.orange.shade300 : Colors.blue.shade200,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 18,
                              color: announcement.isOngoing ? Colors.orange.shade900 : Colors.blue.shade900,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Khung thời gian thực hiện',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: announcement.isOngoing ? Colors.orange.shade900 : Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bắt đầu: ${DateFormat('HH:mm - dd/MM/yyyy').format(announcement.eventStartAt!)}\nKết thúc: ${DateFormat('HH:mm - dd/MM/yyyy').format(announcement.eventEndAt!)}',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: announcement.isOngoing ? Colors.orange.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Thẻ Hotline Kỹ thuật viên (nếu có)
                if (announcement.hotlineContact != null && announcement.hotlineContact!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    color: Colors.green.shade50,
                    borderColor: Colors.green.shade300,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 360;

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.phone_in_talk, color: Colors.green.shade800, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Hotline kỹ thuật viên trực ban',
                                          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          announcement.hotlineContact!,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.call, size: 16),
                                label: const Text('Gọi ngay', style: TextStyle(fontSize: 12)),
                                onPressed: () => _makePhoneCall(announcement.hotlineContact!),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.phone_in_talk, color: Colors.green.shade800, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Hotline kỹ thuật viên trực ban',
                                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    announcement.hotlineContact!,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.call, size: 16),
                              label: const Text('Gọi ngay', style: TextStyle(fontSize: 12)),
                              onPressed: () => _makePhoneCall(announcement.hotlineContact!),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Thẻ nội dung chi tiết
                AppCard(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.article_outlined, color: AppTheme.primary, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nội dung thông báo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        announcement.content,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppTheme.textPrimary,
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
