import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/widgets/adaptive_management_scaffold.dart';
import '../../../core/widgets/building_switcher_dropdown.dart';
import '../../../core/widgets/font_size_sheet.dart';
import '../../../core/widgets/maintenance_fund_card.dart';
import '../../../core/widgets/pdpl_consent_dialog.dart';
import '../../../core/widgets/sync_status_bar.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/dashboard_providers.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/meter_reading_provider.dart';
import '../../../data/providers/notification_provider.dart';
import '../../../data/providers/role_delegation_provider.dart';
import '../widgets/home/management_financial_progress_card.dart';
import '../widgets/home/management_kpi_and_stats_sections.dart';
import '../widgets/home/management_quick_actions_section.dart';
import '../widgets/home/management_recent_transactions_card.dart';
import '../widgets/home/management_urgent_work_section.dart';
import '../widgets/management_theme_mode_sheet.dart';
import '../widgets/revenue_trend_chart.dart';
import '../widgets/role_onboarding_dialog.dart';
import 'accounting_web_workstation_screen.dart';
import 'invoice_management_screen.dart';
import 'issue_management_screen.dart';
import 'resident_management_screen.dart';

class ManagementHomeScreen extends ConsumerStatefulWidget {
  const ManagementHomeScreen({super.key});

  @override
  ConsumerState<ManagementHomeScreen> createState() =>
      _ManagementHomeScreenState();
}

class _ManagementTab {
  final String key;
  final Widget screen;
  final AdaptiveNavigationItem adaptiveItem;

  const _ManagementTab({
    required this.key,
    required this.screen,
    required this.adaptiveItem,
  });
}

class _ManagementHomeScreenState extends ConsumerState<ManagementHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PdplConsentManager.showConsentDialogIfNeeded(context);
      final currentUser = ref.read(authProvider).valueOrNull;
      if (currentUser != null && mounted) {
        RoleOnboardingDialog.checkAndShow(context, currentUser);
      }
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      AppHaptics.light();
      setState(() => _selectedIndex = index);
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textError,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authProvider.notifier).logout();
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationToast({
    required IconData icon,
    required String message,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: colorScheme.onPrimary, size: 22),
            AppSpacing.w12,
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
      ),
    );
  }

  Color _getRoleBadgeColor(BuildContext context, String role) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (role) {
      case 'admin':
      case 'management':
        return colorScheme.primary;
      case 'accountant':
        return AppTheme.getSemanticSecondary(context);
      case 'technician':
        return AppTheme.getSemanticWarning(context);
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = AppTheme.getSemanticError(context);

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      rawIssuesStreamProvider,
      (previous, next) {
        if (previous?.hasValue == true && next.hasValue) {
          final prevIds = previous!.value!
              .map((i) => i['id'] as String)
              .toSet();
          final newlyAdded = next.value!
              .where((i) => !prevIds.contains(i['id']))
              .toList();
          for (final issue in newlyAdded) {
            final desc =
                (issue['description'] as String?) ??
                'Phản ánh sự cố mới từ cư dân';
            final isUrgent =
                issue['priority'] == 'high' || issue['priority'] == 'urgent';

            _showNotificationToast(
              icon: isUrgent
                  ? Icons.warning_amber_rounded
                  : Icons.report_problem,
              message: isUrgent ? 'SỰ CỐ KHẨN: $desc' : 'Sự cố mới: $desc',
              backgroundColor: isUrgent
                  ? AppTheme.textError
                  : AppTheme.textWarning,
              duration: const Duration(seconds: 5),
            );
          }
        }
      },
    );

    ref.listen<AsyncValue<int>>(pendingConfirmationInvoicesProvider, (
      previous,
      next,
    ) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevCount = previous!.value!;
        final nextCount = next.value!;
        if (nextCount > prevCount) {
          _showNotificationToast(
            icon: Icons.payments,
            message:
                'Cư dân vừa gửi xác nhận chuyển khoản! Đang chờ BQL đối soát.',
            backgroundColor: AppTheme.textSuccess,
          );
          ref
              .read(pushNotificationServiceProvider)
              .showSystemNotification(
                id: 'payment_confirm_${DateTime.now().millisecondsSinceEpoch}'
                    .hashCode,
                title: 'Xác nhận thanh toán mới',
                body:
                    'Có cư dân vừa hoàn tất chuyển khoản hóa đơn và gửi xác nhận. Vui lòng kiểm tra đối soát.',
                payload: {'type': 'new_invoice'},
              );
        }
      }
    });

    ref.listen<AsyncValue<int>>(pendingLinkRequestsCountProvider, (
      previous,
      next,
    ) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevCount = previous!.value!;
        final nextCount = next.value!;
        if (nextCount > prevCount) {
          _showNotificationToast(
            icon: Icons.person_add_alt_1,
            message:
                'Có yêu cầu liên kết căn hộ mới từ cư dân đang chờ phê duyệt.',
            backgroundColor: AppTheme.primary,
          );
          ref
              .read(pushNotificationServiceProvider)
              .showSystemNotification(
                id: 'link_request_${DateTime.now().millisecondsSinceEpoch}'
                    .hashCode,
                title: 'Yêu cầu liên kết căn hộ mới',
                body:
                    'Có cư dân vừa gửi yêu cầu liên kết căn hộ. Vui lòng vào duyệt.',
                payload: {'type': 'link_request'},
              );
        }
      }
    });

    ref.listen<AsyncValue<List<NotificationModel>>>(
      notificationsStreamProvider,
      (previous, next) {
        if (previous?.hasValue == true && next.hasValue) {
          final prevIds = previous!.value!.map((n) => n.id).toSet();
          final newNotifs = next.value!.where(
            (n) => !prevIds.contains(n.id) && !n.isRead,
          );
          for (final notif in newNotifs) {
            ref
                .read(pushNotificationServiceProvider)
                .showSystemNotification(
                  id: notif.id.hashCode,
                  title: notif.title,
                  body: notif.body,
                  payload: notif.toJson(),
                );
          }
        }
      },
    );

    final currentUser = ref.watch(authProvider).value;
    final activeDelegations =
        ref.watch(activeDelegationsProvider).valueOrNull ?? [];
    final canManageInvoices = AppPermissions.invoiceManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canManageIssues = AppPermissions.issueManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canManageMeterReadings = AppPermissions.meterReadingManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canManageHandbook = AppPermissions.handbookManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canManageAmenities = AppPermissions.amenityManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canManageEquipment = AppPermissions.equipmentManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canApproveVehicles = AppPermissions.vehicleApproval.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canViewPaymentTransactions = AppPermissions.paymentTransactions
        .allows(currentUser?.role, activeDelegations: activeDelegations);
    final canViewAuditTrail = AppPermissions.auditTrail.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );
    final canManageResidents = AppPermissions.residentManagement.allows(
      currentUser?.role,
      activeDelegations: activeDelegations,
    );

    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final pendingInvoicesAsync = ref.watch(pendingConfirmationInvoicesProvider);
    final pendingIssuesAsync = ref.watch(pendingIssuesCountProvider);

    final linkCount = pendingLinkReqAsync.value ?? 0;
    final invoiceCount = pendingInvoicesAsync.value ?? 0;
    final issueCount = pendingIssuesAsync.value ?? 0;

    final tabs = <_ManagementTab>[
      _ManagementTab(
        key: 'dashboard',
        screen: _buildDashboard(
          currentUser,
          canManageInvoices: canManageInvoices,
          canManageIssues: canManageIssues,
          canManageMeterReadings: canManageMeterReadings,
          canManageHandbook: canManageHandbook,
          canManageAmenities: canManageAmenities,
          canManageEquipment: canManageEquipment,
          canApproveVehicles: canApproveVehicles,
          canViewPaymentTransactions: canViewPaymentTransactions,
          canViewAuditTrail: canViewAuditTrail,
        ),
        adaptiveItem: const AdaptiveNavigationItem(
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: 'Tổng quan',
        ),
      ),
      if (canManageResidents)
        _ManagementTab(
          key: 'residents',
          screen: const ResidentManagementScreen(),
          adaptiveItem: AdaptiveNavigationItem(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            label: 'Cư dân',
            badgeCount: linkCount > 0 ? linkCount : null,
          ),
        ),
      if (canManageInvoices)
        _ManagementTab(
          key: 'invoices',
          screen: const InvoiceManagementScreen(),
          adaptiveItem: AdaptiveNavigationItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: 'Hóa đơn',
            badgeCount: invoiceCount > 0 ? invoiceCount : null,
          ),
        ),
      if (canManageInvoices)
        _ManagementTab(
          key: 'workstation',
          screen: const AccountingWebWorkstationScreen(),
          adaptiveItem: const AdaptiveNavigationItem(
            icon: Icons.table_chart_outlined,
            selectedIcon: Icons.table_chart,
            label: 'Đối soát',
          ),
        ),
      if (canManageIssues)
        _ManagementTab(
          key: 'issues',
          screen: const IssueManagementScreen(),
          adaptiveItem: AdaptiveNavigationItem(
            icon: Icons.report_problem_outlined,
            selectedIcon: Icons.report_problem,
            label: 'Phản ánh',
            badgeCount: issueCount > 0 ? issueCount : null,
          ),
        ),
    ];

    final currentIndex = _selectedIndex < tabs.length ? _selectedIndex : 0;
    final roleColor = _getRoleBadgeColor(context, currentUser?.role ?? '');

    return AdaptiveManagementScaffold(
      selectedIndex: currentIndex,
      onDestinationSelected: _onItemTapped,
      destinations: tabs.map((t) => t.adaptiveItem).toList(),
      appBar: currentIndex == 0
          ? AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text('Ban Quản Lý', overflow: TextOverflow.ellipsis),
                  ),
                  if (currentUser != null &&
                      MediaQuery.sizeOf(context).width >= 360) ...[
                    AppSpacing.w6,
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(
                            alpha: isDark ? 0.2 : 0.14,
                          ),
                          borderRadius: AppRadius.r12,
                          border: Border.all(
                            color: roleColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          currentUser.roleDisplayName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: roleColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width < 360
                        ? 100
                        : 135,
                  ),
                  child: const BuildingSwitcherDropdown(),
                ),
                if (MediaQuery.sizeOf(context).width >= 360)
                  Builder(
                    builder: (context) {
                      final unreadNotifs = ref.watch(
                        unreadNotificationsCountProvider,
                      );
                      return IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: 'Hộp thư thông báo',
                        onPressed: () {
                          context.push(AppRoutes.managementNotifications);
                        },
                        icon: Badge(
                          isLabelVisible: unreadNotifs > 0,
                          label: Text(
                            unreadNotifs > 99 ? '99+' : '$unreadNotifs',
                          ),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                      );
                    },
                  ),
                if (canViewAuditTrail &&
                    MediaQuery.sizeOf(context).width >= 400)
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
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
                    } else if (value == 'fontSize') {
                      showFontSizeBottomSheet(context, ref);
                    } else if (value == 'theme') {
                      showManagementThemeModeSheet(context, ref);
                    } else if (value == 'logout') {
                      _showLogoutDialog(context);
                    }
                  },
                  itemBuilder: (BuildContext ctx) {
                    final cs = Theme.of(ctx).colorScheme;
                    final err = AppTheme.getSemanticError(ctx);
                    return [
                      PopupMenuItem(
                        value: 'fontSize',
                        child: Row(
                          children: [
                            Icon(
                              Icons.format_size_outlined,
                              size: 20,
                              color: cs.primary,
                            ),
                            AppSpacing.w8,
                            const Text('Cỡ chữ hiển thị'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'password',
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 20),
                            AppSpacing.w8,
                            Text('Đổi mật khẩu'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'theme',
                        child: Row(
                          children: [
                            Icon(
                              Icons.brightness_6_outlined,
                              size: 20,
                              color: cs.primary,
                            ),
                            AppSpacing.w8,
                            const Text('Giao diện'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_outlined, size: 20, color: err),
                            AppSpacing.w8,
                            Text('Đăng xuất', style: TextStyle(color: err)),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = MediaQuery.sizeOf(context).width < 600;
                    if (isSmall) return const SizedBox.shrink();
                    return IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(Icons.logout_outlined, color: errorColor),
                      tooltip: 'Đăng xuất',
                      onPressed: () => _showLogoutDialog(context),
                    );
                  },
                ),
              ],
            )
          : null,
      sidebarHeader: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: AppSpacing.p8,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.2 : 0.1,
                ),
                borderRadius: AppRadius.r8,
              ),
              child: Icon(
                Icons.apartment_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            AppSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VIVONA',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currentUser?.roleDisplayName ?? 'Ban Quản Lý',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: roleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      sidebarFooter: Padding(
        padding: AppSpacing.p16,
        child: OutlinedButton.icon(
          onPressed: () => _showLogoutDialog(context),
          icon: Icon(Icons.logout, size: 18, color: errorColor),
          label: Text('Đăng xuất', style: TextStyle(color: errorColor)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: errorColor),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
      body: Column(
        children: [
          const SyncStatusBar(),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: tabs.map((t) => t.screen).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(
    UserModel? currentUser, {
    required bool canManageInvoices,
    required bool canManageIssues,
    required bool canManageMeterReadings,
    required bool canManageHandbook,
    required bool canManageAmenities,
    required bool canManageEquipment,
    required bool canApproveVehicles,
    required bool canViewPaymentTransactions,
    required bool canViewAuditTrail,
  }) {
    final isTechnician = currentUser?.isTechnician ?? false;
    final isAdmin = currentUser?.isAdmin ?? false;

    final pendingIssuesAsync = ref.watch(pendingIssuesCountProvider);
    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final allIssuesAsync = ref.watch(allIssuesProvider);
    final pendingMeterReadingsAsync = ref.watch(
      pendingMeterReadingsCountProvider,
    );
    final pendingConfirmationAsync = ref.watch(
      pendingConfirmationInvoicesProvider,
    );

    final quickActions = ManagementQuickActionsSection(
      currentUser: currentUser,
      isAdmin: isAdmin,
      canManageInvoices: canManageInvoices,
      canManageIssues: canManageIssues,
      canManageMeterReadings: canManageMeterReadings,
      canManageHandbook: canManageHandbook,
      canManageAmenities: canManageAmenities,
      canManageEquipment: canManageEquipment,
      canApproveVehicles: canApproveVehicles,
      canViewPaymentTransactions: canViewPaymentTransactions,
      canViewAuditTrail: canViewAuditTrail,
      pendingLinkReqAsync: pendingLinkReqAsync,
      pendingIssuesAsync: pendingIssuesAsync,
      pendingMeterReadingsAsync: pendingMeterReadingsAsync,
    );

    final kpiStrip = ManagementInteractiveKpiStrip(
      pendingInvoicesAsync: pendingConfirmationAsync,
      pendingIssuesAsync: pendingIssuesAsync,
      pendingMeterReadingsAsync: pendingMeterReadingsAsync,
      pendingLinkReqAsync: pendingLinkReqAsync,
    );

    final urgentWork = ManagementUrgentWorkSection(
      allIssuesAsync: allIssuesAsync,
      pendingConfirmationAsync: pendingConfirmationAsync,
      pendingLinkReqAsync: pendingLinkReqAsync,
      pendingMeterReadingsAsync: pendingMeterReadingsAsync,
      isAdmin: isAdmin,
      canManageInvoices: canManageInvoices,
      canManageMeterReadings: canManageMeterReadings,
    );

    final apartmentStats = ManagementApartmentResidentStats(
      isTechnician: isTechnician,
      pendingLinkReqAsync: pendingLinkReqAsync,
    );

    final opsStats = ManagementOpsStats(
      pendingIssuesAsync: pendingIssuesAsync,
      allIssuesAsync: allIssuesAsync,
    );

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(rawInvoicesStream);
        ref.invalidate(pendingIssuesCountProvider);
        ref.invalidate(pendingLinkRequestsCountProvider);
        ref.invalidate(pendingConfirmationInvoicesProvider);
        ref.invalidate(allIssuesProvider);
        ref.invalidate(financialStatsProvider);
        ref.invalidate(monthlyRevenueTrendProvider);
        ref.invalidate(apartmentsStreamProvider);
        ref.invalidate(totalResidentsProvider);
        ref.invalidate(pendingMeterReadingsCountProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.p16,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 65,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            kpiStrip,
                            AppSpacing.h24,
                            urgentWork,
                            AppSpacing.h24,
                            apartmentStats,
                            AppSpacing.h24,
                            if (!isTechnician || canManageInvoices) ...[
                              Text(
                                'Tài chính & Thu phí',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              AppSpacing.h12,
                              const ManagementFinancialProgressCard(),
                              AppSpacing.h16,
                              const RevenueTrendChart(),
                              AppSpacing.h24,
                            ],
                            opsStats,
                          ],
                        ),
                      ),
                      AppSpacing.w24,
                      Expanded(
                        flex: 35,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            quickActions,
                            AppSpacing.h24,
                            const MaintenanceFundCard(isManagement: true),
                            AppSpacing.h24,
                            _buildRecentTransactionsSection(),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    quickActions,
                    AppSpacing.h24,
                    kpiStrip,
                    AppSpacing.h24,
                    urgentWork,
                    AppSpacing.h24,
                    apartmentStats,
                    AppSpacing.h24,
                    if (!isTechnician || canManageInvoices) ...[
                      Text(
                        'Tài chính & Thu phí',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.h12,
                      const ManagementFinancialProgressCard(),
                      AppSpacing.h16,
                      const RevenueTrendChart(),
                      AppSpacing.h16,
                      const MaintenanceFundCard(isManagement: true),
                      AppSpacing.h16,
                      _buildRecentTransactionsSection(),
                      AppSpacing.h24,
                    ],
                    opsStats,
                    AppSpacing.h40,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Thanh toán gần đây',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () {
                context.push(AppRoutes.managementPaymentTransactions);
              },
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        AppSpacing.h8,
        const ManagementRecentTransactionsCard(),
      ],
    );
  }
}
