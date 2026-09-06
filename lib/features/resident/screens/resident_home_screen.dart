import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/announcement_provider.dart';
import '../../../data/providers/resident_invoice_provider.dart';
import '../../../data/providers/resident_issue_provider.dart';
import 'resident_invoice_screen.dart';
import 'resident_issue_screen.dart';
import 'resident_profile_screen.dart';
import 'resident_announcement_detail_screen.dart';
import 'resident_handbook_screen.dart';

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

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Hóa đơn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Phản ánh',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
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

    return CustomScrollView(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Xin chào,',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.apartment, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'PKA Home',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
                    _buildQuickAction(Icons.payment, 'Thanh toán', () => _onItemTapped(1)),
                    _buildQuickAction(Icons.build_circle_outlined, 'Báo sự cố', () => _onItemTapped(2)),
                    _buildQuickAction(
                      Icons.emergency_outlined,
                      'Hotline',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResidentHandbookScreen(initialTabIndex: 0),
                        ),
                      ),
                    ),
                    _buildQuickAction(
                      Icons.menu_book_outlined,
                      'Cẩm nang',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResidentHandbookScreen(initialTabIndex: 1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Invoice Summary Card
                const Text(
                  'Tổng quan tài chính',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                invoiceAsync.when(
                  data: (invoices) {
                    final unpaidInvoices = invoices.where((i) => i.status == 'unpaid' || i.status == 'pending_confirmation').toList();
                    final totalUnpaid = unpaidInvoices.fold<double>(0, (sum, item) => sum + item.totalAmount);
                    return Card(
                      elevation: 2,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: totalUnpaid > 0 
                                ? [Colors.orange.shade50, Colors.white]
                                : [Colors.green.shade50, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cần thanh toán',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(totalUnpaid),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: totalUnpaid > 0 ? AppTheme.error : AppTheme.success,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: totalUnpaid > 0 ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                totalUnpaid > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                color: totalUnpaid > 0 ? AppTheme.error : AppTheme.success,
                                size: 32,
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, st) => Text('Lỗi: $err'),
                ),
                
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
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Không có phản ánh nào gần đây.', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
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
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, st) => Text('Lỗi: $err'),
                ),

                const SizedBox(height: 24),
                
                // Announcements
                const Text(
                  'Thông báo mới nhất',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                announcementsAsync.when(
                  data: (announcements) {
                    if (announcements.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Không có thông báo nào.'),
                      );
                    }
                    return Column(
                      children: announcements.map((announcement) {
                        return NotificationCard(
                          title: announcement.title,
                          content: announcement.content,
                          date: '${announcement.createdAt.day}/${announcement.createdAt.month}/${announcement.createdAt.year}',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ResidentAnnouncementDetailScreen(
                                  announcement: announcement,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Lỗi tải thông báo: $error')),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
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
