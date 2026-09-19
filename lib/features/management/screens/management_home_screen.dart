import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../widgets/stat_card.dart';
import '../../../data/models/user_model.dart';
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
import 'role_delegation_screen.dart';
import 'permission_matrix_screen.dart';
import '../widgets/role_onboarding_dialog.dart';

class ManagementHomeScreen extends ConsumerStatefulWidget {
  const ManagementHomeScreen({super.key});

  @override
  ConsumerState<ManagementHomeScreen> createState() => _ManagementHomeScreenState();
}

class _ManagementTab {
  final String key;
  final Widget screen;
  final BottomNavigationBarItem item;

  const _ManagementTab({
    required this.key,
    required this.screen,
    required this.item,
  });
}

class _ManagementHomeScreenState extends ConsumerState<ManagementHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(authProvider).valueOrNull;
      if (currentUser != null && mounted) {
        RoleOnboardingDialog.checkAndShow(context, currentUser);
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case 'admin':
      case 'management':
        return AppTheme.primary;
      case 'accountant':
        return Colors.purple;
      case 'technician':
        return Colors.orange;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value;
    final isAdmin = currentUser?.isAdmin ?? true;
    final isAccountant = currentUser?.isAccountant ?? false;
    final isTechnician = currentUser?.isTechnician ?? false;

    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final pendingInvoicesAsync = ref.watch(pendingConfirmationInvoicesProvider);
    final pendingIssuesAsync = ref.watch(pendingIssuesCountProvider);
    
    int linkCount = pendingLinkReqAsync.value ?? 0;
    int invoiceCount = pendingInvoicesAsync.value ?? 0;
    int issueCount = pendingIssuesAsync.value ?? 0;

    final List<_ManagementTab> tabs = [
      _ManagementTab(
        key: 'dashboard',
        screen: _buildDashboard(currentUser),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Tổng quan',
        ),
      ),
      _ManagementTab(
        key: 'residents',
        screen: const ResidentManagementScreen(),
        item: BottomNavigationBarItem(
          icon: linkCount > 0 ? Badge(label: Text('$linkCount'), child: const Icon(Icons.groups_outlined)) : const Icon(Icons.groups_outlined),
          activeIcon: linkCount > 0 ? Badge(label: Text('$linkCount'), child: const Icon(Icons.groups)) : const Icon(Icons.groups),
          label: 'Cư dân',
        ),
      ),
      if (isAdmin || isAccountant)
        _ManagementTab(
          key: 'invoices',
          screen: const InvoiceManagementScreen(),
          item: BottomNavigationBarItem(
            icon: invoiceCount > 0 ? Badge(label: Text('$invoiceCount'), child: const Icon(Icons.receipt_long_outlined)) : const Icon(Icons.receipt_long_outlined),
            activeIcon: invoiceCount > 0 ? Badge(label: Text('$invoiceCount'), child: const Icon(Icons.receipt_long)) : const Icon(Icons.receipt_long),
            label: 'Hóa đơn',
          ),
        ),
      if (isAdmin || isTechnician)
        _ManagementTab(
          key: 'issues',
          screen: const IssueManagementScreen(),
          item: BottomNavigationBarItem(
            icon: issueCount > 0 ? Badge(label: Text('$issueCount'), child: const Icon(Icons.report_problem_outlined)) : const Icon(Icons.report_problem_outlined),
            activeIcon: issueCount > 0 ? Badge(label: Text('$issueCount'), child: const Icon(Icons.report_problem)) : const Icon(Icons.report_problem),
            label: 'Phản ánh',
          ),
        ),
      _ManagementTab(
        key: 'announcements',
        screen: const AnnouncementManagementScreen(),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Thông báo',
        ),
      ),
    ];

    final currentIndex = _selectedIndex < tabs.length ? _selectedIndex : 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Ban Quản Lý',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (currentUser != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getRoleBadgeColor(currentUser.role).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getRoleBadgeColor(currentUser.role).withValues(alpha: 0.5)),
                ),
                child: Text(
                  currentUser.roleDisplayName,
                  style: TextStyle(
                    color: _getRoleBadgeColor(currentUser.role),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
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
              } else if (value == 'delegation') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoleDelegationScreen()),
                );
              } else if (value == 'matrix') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PermissionMatrixScreen()),
                );
              } else if (value == 'logout') {
                ref.read(authProvider.notifier).logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              if (isAdmin)
                const PopupMenuItem(
                  value: 'delegation',
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_outlined, size: 20, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Quản lý ủy quyền'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'matrix',
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('Bảng phân quyền'),
                  ],
                ),
              ),
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
        index: currentIndex,
        children: tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        items: tabs.map((t) => t.item).toList(),
      ),
    );
  }

  Widget _buildDashboard(UserModel? currentUser) {
    final isTechnician = currentUser?.isTechnician ?? false;
    final isAccountant = currentUser?.isAccountant ?? false;
    final isAdmin = currentUser?.isAdmin ?? true;

    final pendingIssuesAsync = ref.watch(pendingIssuesCountProvider);
    final unpaidInvoicesAsync = ref.watch(unpaidInvoicesTotalProvider);
    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final allIssuesAsync = ref.watch(allIssuesProvider);

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(pendingIssuesCountProvider);
        ref.invalidate(pendingLinkRequestsCountProvider);
        ref.invalidate(pendingConfirmationInvoicesProvider);
        ref.invalidate(allIssuesProvider);
        ref.invalidate(financialStatsProvider);
        ref.invalidate(apartmentsStreamProvider);
        ref.invalidate(totalResidentsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                if (isAdmin) ...[
                  _buildQuickAction(
                    context,
                    icon: Icons.person_add,
                    label: 'Duyệt liên kết',
                    color: AppTheme.primary,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LinkRequestManagementScreen()));
                      ref.invalidate(pendingLinkRequestsCountProvider);
                      ref.invalidate(residentsProvider);
                    },
                    badgeCount: pendingLinkReqAsync.value ?? 0,
                  ),
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    context,
                    icon: Icons.vpn_key_outlined,
                    label: 'Ủy quyền',
                    color: Colors.purple,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleDelegationScreen())),
                  ),
                  const SizedBox(width: 12),
                ],
                if (isAdmin || isAccountant) ...[
                  _buildQuickAction(
                    context,
                    icon: Icons.receipt_long,
                    label: 'Lập hóa đơn',
                    color: AppTheme.secondary,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateInvoiceScreen())),
                  ),
                  const SizedBox(width: 12),
                ],
                if (isAdmin || isTechnician) ...[
                  _buildQuickAction(
                    context,
                    icon: Icons.report_problem_outlined,
                    label: 'Xử lý sự cố',
                    color: Colors.orange,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IssueManagementScreen())),
                    badgeCount: pendingIssuesAsync.value ?? 0,
                  ),
                  const SizedBox(width: 12),
                ],
                if (isAdmin) ...[
                  _buildQuickAction(
                    context,
                    icon: Icons.domain,
                    label: 'Căn hộ',
                    color: Colors.teal,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApartmentManagementScreen())),
                  ),
                  const SizedBox(width: 12),
                ],

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
                        Expanded(
                          child: Text(
                            'Không có sự cố khẩn cấp nào cần xử lý.',
                            style: TextStyle(color: AppStatusColors.paid, fontWeight: FontWeight.bold),
                          ),
                        ),
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
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IssueManagementScreen()));
                        },
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
          if (!isTechnician) ...[
            _buildFinancialProgressCard(),
            const SizedBox(height: 16),
          ],
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              pendingIssuesAsync.isLoading
                  ? const StatCardSkeleton()
                  : StatCard(
                      title: 'Phản ánh mới',
                      value: pendingIssuesAsync.when(
                        data: (count) => '$count',
                        loading: () => '...',
                        error: (_, _) => 'Lỗi',
                      ),
                      icon: Icons.warning_amber_outlined,
                      color: AppStatusColors.pending,
                    ),
              if (!isTechnician)
                unpaidInvoicesAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Tổng nợ phí',
                        value: unpaidInvoicesAsync.when(
                          data: (total) => '${(total / 1000000).toStringAsFixed(1)} Tr',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.attach_money,
                        color: AppStatusColors.unpaid,
                      )
              else
                ref.watch(emptyApartmentsProvider).isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Căn hộ trống',
                        value: ref.watch(emptyApartmentsProvider).when(
                          data: (count) => '$count',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.meeting_room_outlined,
                        color: Colors.amber.shade700,
                      ),
              ref.watch(totalApartmentsProvider).isLoading
                  ? const StatCardSkeleton()
                  : StatCard(
                      title: 'Tổng số Căn hộ',
                      value: ref.watch(totalApartmentsProvider).when(
                        data: (count) => '$count',
                        loading: () => '...',
                        error: (_, _) => 'Lỗi',
                      ),
                      icon: Icons.domain,
                      color: AppTheme.primary,
                    ),
              ref.watch(totalResidentsProvider).isLoading
                  ? const StatCardSkeleton()
                  : StatCard(
                      title: 'Tổng Cư dân',
                      value: ref.watch(totalResidentsProvider).when(
                        data: (count) => '$count',
                        loading: () => '...',
                        error: (_, _) => 'Lỗi',
                      ),
                      icon: Icons.groups,
                      color: AppStatusColors.paid,
                    ),
              ref.watch(occupancyRateProvider).isLoading
                  ? const StatCardSkeleton()
                  : StatCard(
                      title: 'Tỷ lệ lấp đầy',
                      value: ref.watch(occupancyRateProvider).when(
                        data: (rate) => '${(rate * 100).toStringAsFixed(1)}%',
                        loading: () => '...',
                        error: (_, _) => 'Lỗi',
                      ),
                      icon: Icons.pie_chart_outline,
                      color: AppTheme.secondary,
                    ),
              if (!isTechnician)
                pendingLinkReqAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Chờ liên kết',
                        value: pendingLinkReqAsync.when(
                          data: (count) => '$count',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.link,
                        color: Colors.teal,
                      )
              else
                allIssuesAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Sự cố đang xử lý',
                        value: allIssuesAsync.when(
                          data: (issues) => '${issues.where((i) => i.status == 'in_progress').length}',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.build_circle_outlined,
                        color: Colors.orange,
                      ),
            ],
          ),
        ],
      ),
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
                    Expanded(
                      child: Row(
                        children: const [
                          Icon(Icons.pie_chart_outline, color: AppTheme.primary, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tiến độ thu phí tòa nhà',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Còn nợ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency.format(stats.unpaidTotal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppStatusColors.unpaid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Căn đã đóng', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${stats.paidCount}/${stats.paidCount + stats.unpaidCount}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
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
