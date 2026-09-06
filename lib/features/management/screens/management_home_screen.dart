import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/dashboard_providers.dart';
import '../../../data/providers/management_provider.dart';
import 'resident_management_screen.dart';
import 'invoice_management_screen.dart';
import 'issue_management_screen.dart';
import 'link_request_management_screen.dart';
import 'announcement_management_screen.dart';
import 'apartment_management_screen.dart';
import '../../auth/screens/change_password_screen.dart';
import 'audit_trail_screen.dart';
import 'create_invoice_screen.dart';
import 'handbook_management_screen.dart';

class ManagementHomeScreen extends ConsumerStatefulWidget {
  const ManagementHomeScreen({super.key});

  @override
  ConsumerState<ManagementHomeScreen> createState() => _ManagementHomeScreenState();
}

class _ManagementHomeScreenState extends ConsumerState<ManagementHomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final pendingInvoicesAsync = ref.watch(pendingConfirmationInvoicesProvider);
    final pendingIssuesAsync = ref.watch(pendingIssuesCountProvider);
    
    int linkCount = pendingLinkReqAsync.value ?? 0;
    int invoiceCount = pendingInvoicesAsync.value ?? 0;
    int issueCount = pendingIssuesAsync.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ban Quản Lý'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuditTrailScreen()),
              );
            },
            tooltip: 'Lịch sử hoạt động',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'password') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                );
              } else if (value == 'logout') {
                ref.read(authProvider.notifier).logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'password',
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Đổi mật khẩu'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_outlined, size: 20, color: AppTheme.error),
                    SizedBox(width: 8),
                    Text('Đăng xuất', style: TextStyle(color: AppTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          const ResidentManagementScreen(),
          const InvoiceManagementScreen(),
          const IssueManagementScreen(),
          const AnnouncementManagementScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: linkCount > 0 ? Badge(label: Text('$linkCount'), child: const Icon(Icons.groups_outlined)) : const Icon(Icons.groups_outlined),
            activeIcon: linkCount > 0 ? Badge(label: Text('$linkCount'), child: const Icon(Icons.groups)) : const Icon(Icons.groups),
            label: 'Cư dân',
          ),
          BottomNavigationBarItem(
            icon: invoiceCount > 0 ? Badge(label: Text('$invoiceCount'), child: const Icon(Icons.receipt_long_outlined)) : const Icon(Icons.receipt_long_outlined),
            activeIcon: invoiceCount > 0 ? Badge(label: Text('$invoiceCount'), child: const Icon(Icons.receipt_long)) : const Icon(Icons.receipt_long),
            label: 'Hóa đơn',
          ),
          BottomNavigationBarItem(
            icon: issueCount > 0 ? Badge(label: Text('$issueCount'), child: const Icon(Icons.report_problem_outlined)) : const Icon(Icons.report_problem_outlined),
            activeIcon: issueCount > 0 ? Badge(label: Text('$issueCount'), child: const Icon(Icons.report_problem)) : const Icon(Icons.report_problem),
            label: 'Phản ánh',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Thông báo',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final pendingIssuesAsync = ref.watch(pendingIssuesCountProvider);
    final unpaidInvoicesAsync = ref.watch(unpaidInvoicesTotalProvider);
    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final allIssuesAsync = ref.watch(allIssuesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions
          Text('Thao tác nhanh', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickAction(
                  context,
                  icon: Icons.person_add,
                  label: 'Duyệt liên kết',
                  color: AppTheme.primary,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkRequestManagementScreen())),
                  badgeCount: pendingLinkReqAsync.value ?? 0,
                ),
                const SizedBox(width: 12),
                _buildQuickAction(
                  context,
                  icon: Icons.receipt_long,
                  label: 'Lập hóa đơn',
                  color: AppTheme.secondary,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateInvoiceScreen())),
                ),
                const SizedBox(width: 12),
                _buildQuickAction(
                  context,
                  icon: Icons.domain,
                  label: 'Căn hộ',
                  color: Colors.teal,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApartmentManagementScreen())),
                ),
                const SizedBox(width: 12),
                _buildQuickAction(
                  context,
                  icon: Icons.menu_book_outlined,
                  label: 'Cẩm nang',
                  color: Colors.indigo,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HandbookManagementScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Widget Việc khẩn cấp
          Text('Việc khẩn cấp', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppStatusColors.priorityHigh)),
          const SizedBox(height: 12),
          allIssuesAsync.when(
            data: (issues) {
              final urgentIssues = issues.where((issue) => issue.priority == 'high' && issue.status == 'pending').toList();
              if (urgentIssues.isEmpty) {
                return Card(
                  color: AppStatusColors.paid.withValues(alpha: 0.1),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppStatusColors.paid)),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppStatusColors.paid),
                        SizedBox(width: 12),
                        Text('Không có sự cố khẩn cấp nào cần xử lý.', style: TextStyle(color: AppStatusColors.paid, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: urgentIssues.length,
                itemBuilder: (context, index) {
                  final issue = urgentIssues[index];
                  return Card(
                    color: AppStatusColors.priorityHigh.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppStatusColors.priorityHigh),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.warning, color: AppStatusColors.priorityHigh),
                      title: Text('Căn hộ ${issue.apartment?.code ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppStatusColors.priorityHigh)),
                      subtitle: Text(issue.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppStatusColors.priorityHigh, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                        onPressed: () => _onItemTapped(3), // Navigate to issues tab
                        child: const Text('Xem ngay'),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Text('Lỗi tải dữ liệu', style: TextStyle(color: AppTheme.error)),
          ),
          const SizedBox(height: 24),

          // Tổng quan (Stat Cards)
          Text('Tổng quan hệ thống', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildFinancialProgressCard(),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              StatCard(
                title: 'Phản ánh mới',
                value: pendingIssuesAsync.when(
                  data: (count) => '$count',
                  loading: () => '...',
                  error: (_, _) => 'Lỗi',
                ),
                icon: Icons.warning_amber_outlined,
                color: AppStatusColors.pending,
              ),
              StatCard(
                title: 'Tổng nợ phí',
                value: unpaidInvoicesAsync.when(
                  data: (total) => '${(total / 1000000).toStringAsFixed(1)} Tr',
                  loading: () => '...',
                  error: (_, _) => 'Lỗi',
                ),
                icon: Icons.attach_money,
                color: AppStatusColors.unpaid,
              ),
              StatCard(
                title: 'Tổng số Căn hộ',
                value: ref.watch(totalApartmentsProvider).when(
                  data: (count) => '$count',
                  loading: () => '...',
                  error: (_, _) => 'Lỗi',
                ),
                icon: Icons.domain,
                color: AppTheme.primary,
              ),
              StatCard(
                title: 'Tổng Cư dân',
                value: ref.watch(totalResidentsProvider).when(
                  data: (count) => '$count',
                  loading: () => '...',
                  error: (_, _) => 'Lỗi',
                ),
                icon: Icons.groups,
                color: AppStatusColors.paid,
              ),
              StatCard(
                title: 'Tỷ lệ lấp đầy',
                value: ref.watch(occupancyRateProvider).when(
                  data: (rate) => '${(rate * 100).toStringAsFixed(1)}%',
                  loading: () => '...',
                  error: (_, _) => 'Lỗi',
                ),
                icon: Icons.pie_chart_outline,
                color: AppTheme.secondary,
              ),
              StatCard(
                title: 'Chờ liên kết',
                value: pendingLinkReqAsync.when(
                  data: (count) => '$count',
                  loading: () => '...',
                  error: (_, _) => 'Lỗi',
                ),
                icon: Icons.link,
                color: Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialProgressCard() {
    final statsAsync = ref.watch(financialStatsProvider);
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return statsAsync.when(
      data: (stats) {
        final percent = (stats.collectionRate * 100).toInt();
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart_outline, color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tiến độ thu phí tòa nhà',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppStatusColors.paid.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$percent% Đã thu',
                        style: const TextStyle(
                          color: AppStatusColors.paid,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: stats.collectionRate,
                    minHeight: 8,
                    backgroundColor: AppStatusColors.unpaid.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppStatusColors.paid),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đã thu', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency.format(stats.paidTotal),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppStatusColors.paid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Còn nợ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency.format(stats.unpaidTotal),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppStatusColors.unpaid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Căn đã đóng', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.paidCount}/${stats.paidCount + stats.unpaidCount}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickAction(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap, int badgeCount = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 32),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppStatusColors.unpaid, shape: BoxShape.circle),
                      child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
