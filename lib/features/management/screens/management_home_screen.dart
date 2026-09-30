import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/app_card.dart';
import '../widgets/stat_card.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/dashboard_providers.dart';
import '../../../data/providers/management_provider.dart';
import 'resident_management_screen.dart';
import 'invoice_management_screen.dart';
import 'issue_management_screen.dart';
import 'announcement_management_screen.dart';
import '../widgets/role_onboarding_dialog.dart';
import '../widgets/revenue_trend_chart.dart';
import '../../../core/widgets/maintenance_fund_card.dart';
import '../../../core/widgets/font_size_sheet.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/constants/permissions.dart';
import '../../../data/providers/role_delegation_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class ManagementHomeScreen extends ConsumerStatefulWidget {
  const ManagementHomeScreen({super.key});

  @override
  ConsumerState<ManagementHomeScreen> createState() => _ManagementHomeScreenState();
}

class _ManagementTab {
  final String key;
  final Widget screen;
  final NavigationDestination destination;

  const _ManagementTab({
    required this.key,
    required this.screen,
    required this.destination,
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
    final activeDelegations = ref.watch(activeDelegationsProvider).valueOrNull ?? [];
    final isAdmin = currentUser?.isAdmin ?? false;
    final canManageInvoices = AppPermissions.invoiceManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canManageIssues = AppPermissions.issueManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );

    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final pendingInvoicesAsync = ref.watch(pendingConfirmationInvoicesProvider);
    final pendingIssuesAsync = ref.watch(pendingIssuesCountProvider);
    
    int linkCount = pendingLinkReqAsync.value ?? 0;
    int invoiceCount = pendingInvoicesAsync.value ?? 0;
    int issueCount = pendingIssuesAsync.value ?? 0;

    final List<_ManagementTab> tabs = [
      _ManagementTab(
        key: 'dashboard',
        screen: _buildDashboard(
          currentUser,
          canManageInvoices: canManageInvoices,
          canManageIssues: canManageIssues,
        ),
        destination: const NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart, color: AppTheme.primary),
          label: 'Tổng quan',
        ),
      ),
      _ManagementTab(
        key: 'residents',
        screen: const ResidentManagementScreen(),
        destination: NavigationDestination(
          icon: linkCount > 0 ? Badge(label: Text('$linkCount'), child: const Icon(Icons.groups_outlined)) : const Icon(Icons.groups_outlined),
          selectedIcon: linkCount > 0 ? Badge(label: Text('$linkCount'), child: const Icon(Icons.groups, color: AppTheme.primary)) : const Icon(Icons.groups, color: AppTheme.primary),
          label: 'Cư dân',
        ),
      ),
      if (canManageInvoices)
        _ManagementTab(
          key: 'invoices',
          screen: const InvoiceManagementScreen(),
          destination: NavigationDestination(
            icon: invoiceCount > 0 ? Badge(label: Text('$invoiceCount'), child: const Icon(Icons.receipt_long_outlined)) : const Icon(Icons.receipt_long_outlined),
            selectedIcon: invoiceCount > 0 ? Badge(label: Text('$invoiceCount'), child: const Icon(Icons.receipt_long, color: AppTheme.primary)) : const Icon(Icons.receipt_long, color: AppTheme.primary),
            label: 'Hóa đơn',
          ),
        ),
      if (canManageIssues)
        _ManagementTab(
          key: 'issues',
          screen: const IssueManagementScreen(),
          destination: NavigationDestination(
            icon: issueCount > 0 ? Badge(label: Text('$issueCount'), child: const Icon(Icons.report_problem_outlined)) : const Icon(Icons.report_problem_outlined),
            selectedIcon: issueCount > 0 ? Badge(label: Text('$issueCount'), child: const Icon(Icons.report_problem, color: AppTheme.primary)) : const Icon(Icons.report_problem, color: AppTheme.primary),
            label: 'Phản ánh',
          ),
        ),
      _ManagementTab(
        key: 'announcements',
        screen: const AnnouncementManagementScreen(),
        destination: const NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications, color: AppTheme.primary),
          label: 'Thông báo',
        ),
      ),
    ];

    final currentIndex = _selectedIndex < tabs.length ? _selectedIndex : 0;

    return Scaffold(
      appBar: currentIndex == 0
          ? AppBar(
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
              context.push(AppRoutes.managementAuditTrail);
            },
            tooltip: 'Lịch sử hoạt động',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'password') {
                context.push(AppRoutes.changePassword);
              } else if (value == 'delegation') {
                context.push(AppRoutes.managementRoleDelegation);
              } else if (value == 'matrix') {
                context.push(AppRoutes.managementPermissionMatrix);
              } else if (value == 'serviceRatings') {
                context.push(AppRoutes.managementServiceRatings);
              } else if (value == 'fontSize') {
                showFontSizeBottomSheet(context, ref);
              } else if (value == 'theme') {
                _showManagementThemeModeSheet(context, ref);
              } else if (value == 'logout') {
                _showLogoutDialog(context);
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
                value: 'serviceRatings',
                child: Row(
                  children: [
                    Icon(Icons.star_rate_rounded, size: 20, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Đánh giá dịch vụ'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'fontSize',
                child: Row(
                  children: [
                    Icon(Icons.format_size_outlined, size: 20, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('Cỡ chữ hiển thị'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'password',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Đổi mật khẩu'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.brightness_6_outlined, size: 20, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text('Giao diện'),
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
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppTheme.error),
            tooltip: 'Đăng xuất',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ) : null,
      body: IndexedStack(
        index: currentIndex,
        children: tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _onItemTapped,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
        destinations: tabs.map((t) => t.destination).toList(),
      ),
    );
  }

  Widget _buildDashboard(
    UserModel? currentUser, {
    required bool canManageInvoices,
    required bool canManageIssues,
  }) {
    final isTechnician = currentUser?.isTechnician ?? false;
    final isAdmin = currentUser?.isAdmin ?? false;

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
        ref.invalidate(monthlyRevenueTrendProvider);
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
                      await context.push(AppRoutes.managementLinkRequests);
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
                    onTap: () => context.push(AppRoutes.managementRoleDelegation),
                  ),
                  const SizedBox(width: 12),
                ],
                if (canManageInvoices) ...[
                  _buildQuickAction(
                    context,
                    icon: Icons.receipt_long,
                    label: 'Lập hóa đơn',
                    color: AppTheme.secondary,
                    onTap: () => context.push(AppRoutes.managementCreateInvoice),
                  ),
                  const SizedBox(width: 12),
                ],
                if (canManageIssues) ...[
                  _buildQuickAction(
                    context,
                    icon: Icons.report_problem_outlined,
                    label: 'Xử lý sự cố',
                    color: Colors.orange,
                    onTap: () => context.push(AppRoutes.managementIssues),
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
                    onTap: () => context.push(AppRoutes.managementApartments),
                  ),
                  const SizedBox(width: 12),
                ],

                _buildQuickAction(
                  context,
                  icon: Icons.menu_book_outlined,
                  label: 'Cẩm nang',
                  color: Colors.indigo,
                   onTap: () => context.push(AppRoutes.managementHandbook),
                ),
                if (canManageIssues) ...[
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    context,
                    icon: Icons.star_rate_rounded,
                    label: 'Đánh giá DV',
                    color: Colors.amber.shade700,
                    onTap: () => context.push(AppRoutes.managementServiceRatings),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Widget Việc khẩn cấp
          Text('Phản ánh cần xử lý gấp', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppStatusColors.priorityHigh, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          allIssuesAsync.when(
            data: (issues) {
              final urgentIssues = issues.where((issue) => issue.priority == 'high' && issue.status == 'pending').toList();
              if (urgentIssues.isEmpty) {
                return AppCard(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppStatusColors.paid),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Không có sự cố khẩn cấp nào cần xử lý.',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: urgentIssues.length,
                itemBuilder: (context, index) {
                  final issue = urgentIssues[index];
                  return AppCard(
                    padding: EdgeInsets.zero,
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
          Text('Tổng quan trạng thái', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (!isTechnician || canManageInvoices) ...[
            _buildFinancialProgressCard(),
            const SizedBox(height: 16),
            const RevenueTrendChart(),
            const SizedBox(height: 16),
            const MaintenanceFundCard(isManagement: true),
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
              if (!isTechnician || canManageInvoices)
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
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final chartHeight = (120.0 * textScale).clamp(120.0, 160.0);

        return AppCard(
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
                SizedBox(
                  height: chartHeight,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: [
                              PieChartSectionData(
                                color: AppStatusColors.paid,
                                value: stats.paidTotal,
                                title: '',
                                radius: 25,
                              ),
                              PieChartSectionData(
                                color: AppStatusColors.unpaid,
                                value: stats.unpaidTotal,
                                title: '',
                                radius: 25,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(color: AppStatusColors.paid, label: 'Đã thu: ${formatCurrency.format(stats.paidTotal)}'),
                            const SizedBox(height: 8),
                            _buildLegendItem(color: AppStatusColors.unpaid, label: 'Còn nợ: ${formatCurrency.format(stats.unpaidTotal)}'),
                          ],
                        ),
                      ),
                    ],
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
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

void _showManagementThemeModeSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final currentMode = ref.watch(themeModeProvider);
          final entries = [
            (ThemeMode.system, 'Theo hệ thống', Icons.brightness_auto,
                'Tự động theo cài đặt thiết bị'),
            (ThemeMode.light, 'Sáng', Icons.light_mode,
                'Luôn dùng giao diện sáng'),
            (ThemeMode.dark, 'Tối', Icons.dark_mode,
                'Luôn dùng giao diện tối'),
          ];

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn giao diện',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...entries.map(
                  (entry) =>
                      // ignore: deprecated_member_use
                      RadioListTile<ThemeMode>(
                    value: entry.$1,
                    // ignore: deprecated_member_use
                    groupValue: currentMode,
                    // ignore: deprecated_member_use
                    onChanged: (mode) {
                      if (mode != null) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(mode);
                        Navigator.pop(ctx);
                      }
                    },
                    title: Row(
                      children: [
                        Icon(entry.$3, size: 20),
                        const SizedBox(width: 12),
                        Text(entry.$2),
                      ],
                    ),
                    subtitle: Text(entry.$4,
                        style: const TextStyle(fontSize: 12)),
                    activeColor: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}
