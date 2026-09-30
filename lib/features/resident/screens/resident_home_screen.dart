import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_card.dart';
import '../widgets/apartment_switcher_chip.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/announcement_provider.dart';
import '../../../data/providers/resident_invoice_provider.dart';
import '../../../data/providers/resident_issue_provider.dart';
import 'resident_invoice_screen.dart';
import 'resident_issue_screen.dart';
import 'resident_profile_screen.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/announcement_model.dart';
import '../../../data/providers/link_request_provider.dart';
import '../../../core/widgets/maintenance_fund_card.dart';
import '../../../data/providers/notification_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ResidentHomeScreen extends ConsumerStatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  ConsumerState<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends ConsumerState<ResidentHomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showNotificationToast({
    required IconData icon,
    required String message,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
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
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lắng nghe cập nhật hóa đơn thời gian thực
    ref.listen<AsyncValue<List<InvoiceModel>>>(residentInvoiceProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevList = previous!.value!;
        final nextList = next.value!;
        for (final nextInv in nextList) {
          final prevInv = prevList.cast<InvoiceModel?>().firstWhere(
                (p) => p?.id == nextInv.id,
                orElse: () => null,
              );
          if (prevInv != null && prevInv.status != nextInv.status && nextInv.status == 'paid') {
            _showNotificationToast(
              icon: Icons.check_circle,
              message: 'Hóa đơn kỳ ${nextInv.period} đã được Ban Quản Lý xác nhận thanh toán thành công!',
              backgroundColor: AppTheme.success,
            );
          }
        }
      }
    });

    // 2. Lắng nghe cập nhật phản ánh sự cố thời gian thực
    ref.listen<AsyncValue<List<IssueModel>>>(residentIssueProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevList = previous!.value!;
        final nextList = next.value!;
        for (final nextIssue in nextList) {
          final prevIssue = prevList.cast<IssueModel?>().firstWhere(
                (p) => p?.id == nextIssue.id,
                orElse: () => null,
              );
          if (prevIssue != null && prevIssue.status != nextIssue.status) {
            if (nextIssue.status == 'in_progress') {
              _showNotificationToast(
                icon: Icons.engineering,
                message: 'Phản ánh "${nextIssue.description}" đang được Ban Quản Lý xử lý.',
                backgroundColor: AppTheme.primary,
              );
            } else if (nextIssue.status == 'resolved') {
              _showNotificationToast(
                icon: Icons.verified,
                message: 'Phản ánh "${nextIssue.description}" đã được giải quyết hoàn tất!',
                backgroundColor: AppTheme.success,
              );
            }
          }
        }
      }
    });

    // 3. Lắng nghe thông báo mới đăng thời gian thực
    ref.listen<AsyncValue<List<AnnouncementModel>>>(announcementsStreamProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevList = previous!.value!;
        final nextList = next.value!;
        if (nextList.length > prevList.length) {
          final newest = nextList.first;
          _showNotificationToast(
            icon: newest.isUrgent ? Icons.warning_amber_rounded : Icons.campaign,
            message: newest.isUrgent ? 'THÔNG BÁO KHẨN: ${newest.title}' : 'Thông báo mới: ${newest.title}',
            backgroundColor: newest.isUrgent ? AppTheme.error : AppTheme.primary,
            duration: const Duration(seconds: 5),
          );
        }
      }
    });

    // 4. Lắng nghe phê duyệt liên kết căn hộ thời gian thực
    ref.listen<ResidentLinkStatus>(residentLinkProvider, (previous, next) {
      if (previous?.status == LinkStatus.pending && next.status == LinkStatus.linked) {
        _showNotificationToast(
          icon: Icons.apartment,
          message: 'Yêu cầu liên kết căn hộ đã được Ban Quản Lý phê duyệt thành công!',
          backgroundColor: AppTheme.success,
        );
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          const ResidentInvoiceScreen(),
          const ResidentIssueScreen(),
          const ResidentProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.primary),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppTheme.primary),
            label: 'Hóa đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: AppTheme.primary),
            label: 'Phản ánh',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.primary),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final user = ref.watch(authProvider).value;
    final announcementsAsync = ref.watch(announcementsStreamProvider);
    final invoiceAsync = ref.watch(residentInvoiceProvider);
    final issueAsync = ref.watch(residentIssueProvider);
    final fullName = user?.fullName ?? 'Cư dân';

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(residentInvoiceProvider);
        ref.invalidate(residentIssueProvider);
        ref.invalidate(announcementsStreamProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
          expandedHeight: 140,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: AppTheme.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            AppAvatar(
                              name: fullName,
                              size: 46,
                              fontSize: 18,
                              onTap: () => _onItemTapped(3),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Xin chào,',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Consumer(
                            builder: (context, ref, _) {
                              final unreadCount = ref.watch(unreadNotificationsCountProvider);
                              return IconButton(
                                icon: Badge(
                                  isLabelVisible: unreadCount > 0,
                                  label: Text('$unreadCount'),
                                  backgroundColor: AppStatusColors.unpaid,
                                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                                ),
                                tooltip: 'Thông báo',
                                onPressed: () {
                                  context.push(AppRoutes.residentNotifications);
                                },
                              );
                            },
                          ),
                          const ApartmentSwitcherChip(),
                          IconButton(
                            icon: const Icon(Icons.logout_outlined, color: Colors.white, size: 24),
                            tooltip: 'Đăng xuất',
                            onPressed: () => _showLogoutDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickAction(Icons.payment, 'Thanh toán', () => _onItemTapped(1))
                        .animate().fade(duration: 300.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
                    _buildQuickAction(Icons.build_circle_outlined, 'Báo sự cố', () => _onItemTapped(2))
                        .animate().fade(duration: 300.ms, delay: 100.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
                    _buildQuickAction(
                      Icons.emergency_outlined,
                      'Hotline',
                      () => context.push(AppRoutes.residentHandbook, extra: 0),
                    ).animate().fade(duration: 300.ms, delay: 200.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
                    _buildQuickAction(
                      Icons.menu_book_outlined,
                      'Cẩm nang',
                      () => context.push(AppRoutes.residentHandbook, extra: 1),
                    ).animate().fade(duration: 300.ms, delay: 300.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Dịch vụ & Tiện ích Cư dân
                _buildResidentServicesSection(context),
                const SizedBox(height: 24),
                
                // Invoice Summary Card
                const Text(
                  'Tổng quan hóa đơn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                invoiceAsync.when(
                  data: (invoices) {
                    final unpaidInvoices = invoices.where((i) => i.status == 'unpaid' || i.status == 'pending_confirmation').toList();
                    final totalUnpaid = unpaidInvoices.fold<double>(0, (sum, item) => sum + item.totalAmount);
                    final unpaidCount = unpaidInvoices.length;

                    return AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tổng tiền cần đóng',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ').format(totalUnpaid),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: totalUnpaid > 0 ? AppStatusColors.unpaid : AppTheme.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (totalUnpaid > 0 ? AppTheme.error : AppTheme.success).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  totalUnpaid > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                  color: totalUnpaid > 0 ? AppTheme.error : AppTheme.success,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            totalUnpaid > 0
                                ? '( $unpaidCount hóa đơn chưa thanh toán )'
                                : '( Đã thanh toán đầy đủ các kỳ phí )',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: totalUnpaid > 0 ? AppTheme.textSecondary : AppTheme.success,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (totalUnpaid > 0)
                            ElevatedButton.icon(
                              onPressed: () => _onItemTapped(1),
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text(
                                'THANH TOÁN NGAY',
                                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => _onItemTapped(1),
                              icon: const Icon(Icons.receipt_long, size: 18),
                              label: const Text(
                                'XEM HÓA ĐƠN',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms, delay: 100.ms).slideX(begin: 0.1, curve: Curves.easeOut);
                  },
                  loading: () => const InvoiceCardSkeleton(),
                  error: (err, st) => AppErrorCard(
                    error: err,
                    onRetry: () => ref.invalidate(residentInvoiceProvider),
                  ),
                ),
                const SizedBox(height: 16),
                const MaintenanceFundCard(),
                
                const SizedBox(height: 24),
                
                // Latest Issue Status
                const Text(
                  'Tiến độ phản ánh',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                issueAsync.when(
                  data: (issues) {
                    if (issues.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Không có phản ánh nào gần đây.', style: TextStyle(color: AppTheme.textSecondary)),
                      );
                    }
                    final latestIssue = issues.first;
                    Color statusColor;
                    String statusText;
                    IconData statusIcon;
                    switch (latestIssue.status) {
                      case 'resolved':
                        statusColor = AppTheme.success;
                        statusText = 'Đã xử lý';
                        statusIcon = Icons.check_circle;
                        break;
                      case 'in_progress':
                        statusColor = AppTheme.primary;
                        statusText = 'Đang xử lý';
                        statusIcon = Icons.engineering;
                        break;
                      default:
                        statusColor = AppTheme.warning;
                        statusText = 'Chờ tiếp nhận';
                        statusIcon = Icons.pending_actions;
                    }
                    return AppCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        title: Text(latestIssue.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        onTap: () => _onItemTapped(2),
                      ),
                    ).animate().fade(duration: 400.ms, delay: 200.ms).slideX(begin: 0.1, curve: Curves.easeOut);
                  },
                  loading: () => const ListItemSkeleton(),
                  error: (err, st) => AppErrorCard(
                    error: err,
                    onRetry: () => ref.invalidate(residentIssueProvider),
                  ),
                ),

                const SizedBox(height: 24),
                
                // Announcements
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thông báo mới nhất',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    announcementsAsync.maybeWhen(
                      data: (announcements) => announcements.length > 3
                          ? TextButton(
                              onPressed: () => context.push(AppRoutes.residentNotifications),
                              child: const Text('Xem tất cả'),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                announcementsAsync.when(
                  data: (announcements) {
                    if (announcements.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'Không có thông báo nào.',
                            style: TextStyle(color: AppTheme.textSecondary),
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
                          date: '${announcement.createdAt.day.toString().padLeft(2, '0')}/${announcement.createdAt.month.toString().padLeft(2, '0')}/${announcement.createdAt.year}',
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
                  loading: () => Column(
                    children: const [
                      ListItemSkeleton(),
                      ListItemSkeleton(),
                    ],
                  ),
                  error: (error, stack) => AppErrorCard(
                    error: error,
                    onRetry: () => ref.invalidate(announcementsStreamProvider),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildResidentServicesSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;

    final services = [
      {
        'title': 'Đăng ký gửi xe',
        'subtitle': 'Quản lý phương tiện & thẻ',
        'icon': Icons.directions_car_filled_outlined,
        'color': const Color(0xFF1E88E5),
        'onTap': () => context.push(AppRoutes.residentVehicles),
      },
      {
        'title': 'Tiện ích chung',
        'subtitle': 'BBQ, Hồ bơi, Thể thao',
        'icon': Icons.pool_outlined,
        'color': const Color(0xFF26A69A),
        'onTap': () => context.push(AppRoutes.residentHandbook, extra: 2),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dịch vụ & Tiện ích',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: services.map((s) {
            final color = s['color'] as Color;
            return Expanded(
              child: Card(
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white12
                        : color.withValues(alpha: 0.2),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: s['onTap'] as VoidCallback,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(s['icon'] as IconData, color: color, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['title'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s['subtitle'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          }).toList(),
        ).animate().fade(duration: 350.ms, delay: 150.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

