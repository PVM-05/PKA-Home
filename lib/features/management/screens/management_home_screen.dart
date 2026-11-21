import '../../../core/widgets/sync_status_bar.dart';
import '../../../core/widgets/adaptive_management_scaffold.dart';
import 'accounting_web_workstation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_card.dart';
import '../widgets/stat_card.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/dashboard_providers.dart';
import '../../../data/providers/management_provider.dart';
import 'resident_management_screen.dart';
import 'invoice_management_screen.dart';
import 'issue_management_screen.dart';
import '../widgets/role_onboarding_dialog.dart';
import '../widgets/revenue_trend_chart.dart';
import '../widgets/all_quick_actions_sheet.dart';
import '../widgets/management_theme_mode_sheet.dart';
import '../widgets/home/management_financial_progress_card.dart';
import '../widgets/home/management_recent_transactions_card.dart';
import '../../../core/widgets/maintenance_fund_card.dart';
import '../../../core/widgets/building_switcher_dropdown.dart';
import '../../../core/widgets/font_size_sheet.dart';
import '../../../core/constants/permissions.dart';
import '../../../data/providers/role_delegation_provider.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/widgets/pdpl_consent_dialog.dart';
import '../../../data/providers/notification_provider.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/providers/meter_reading_provider.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/widgets/bounceable.dart';

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
      setState(() {
        _selectedIndex = index;
      });
    }
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
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
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
    // 1. Lắng nghe phản ánh sự cố mới thời gian thực từ Cư dân
    ref.listen<
      AsyncValue<List<Map<String, dynamic>>>
    >(rawIssuesStreamProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevIds = previous!.value!.map((i) => i['id'] as String).toSet();
        final newlyAdded = next.value!
            .where((i) => !prevIds.contains(i['id']))
            .toList();
        for (final issue in newlyAdded) {
          final desc =
              (issue['description'] as String?) ??
              'Phản ánh sự cố mới từ cư dân';
          final isUrgent =
              issue['priority'] == 'high' || issue['priority'] == 'urgent';

          debugPrint(
            '🔔 [ManagementHome] Phát hiện phản ánh mới từ Cư dân: "$desc" (priority: ${issue['priority']})',
          );
          _showNotificationToast(
            icon: isUrgent ? Icons.warning_amber_rounded : Icons.report_problem,
            message: isUrgent ? 'SỰ CỐ KHẨN: $desc' : 'Sự cố mới: $desc',
            backgroundColor: isUrgent ? AppTheme.error : AppTheme.warning,
            duration: const Duration(seconds: 5),
          );
        }
      }
    });

    // 2. Lắng nghe xác nhận chuyển khoản thanh toán hóa đơn mới từ Cư dân
    ref.listen<AsyncValue<int>>(pendingConfirmationInvoicesProvider, (
      previous,
      next,
    ) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevCount = previous!.value!;
        final nextCount = next.value!;
        if (nextCount > prevCount) {
          debugPrint(
            '🔔 [ManagementHome] Cư dân vừa gửi xác nhận thanh toán (Tổng chờ đối soát: $nextCount)',
          );
          _showNotificationToast(
            icon: Icons.payments,
            message:
                'Cư dân vừa gửi xác nhận chuyển khoản! Đang chờ BQL đối soát.',
            backgroundColor: AppTheme.success,
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

    // 3. Lắng nghe yêu cầu liên kết căn hộ mới từ Cư dân
    ref.listen<AsyncValue<int>>(pendingLinkRequestsCountProvider, (
      previous,
      next,
    ) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevCount = previous!.value!;
        final nextCount = next.value!;
        if (nextCount > prevCount) {
          debugPrint(
            '🔔 [ManagementHome] Có yêu cầu liên kết căn hộ mới (Tổng chờ duyệt: $nextCount)',
          );
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

    // 4. Lắng nghe thông báo hệ thống định danh cho tài khoản quản trị
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
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleBadgeColor(
                            currentUser.role,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getRoleBadgeColor(
                              currentUser.role,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          currentUser.roleDisplayName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _getRoleBadgeColor(currentUser.role),
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
                    maxWidth:
                        MediaQuery.sizeOf(context).width < 360 ? 100 : 135,
                  ),
                  child: const BuildingSwitcherDropdown(),
                ),
                if (MediaQuery.sizeOf(context).width >= 360)
                  Builder(
                    builder: (context) {
                      final unreadNotifs =
                          ref.watch(unreadNotificationsCountProvider);
                      return IconButton(
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
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'fontSize',
                      child: Row(
                        children: [
                          Icon(
                            Icons.format_size_outlined,
                            size: 20,
                            color: AppTheme.primary,
                          ),
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
                          Icon(
                            Icons.brightness_6_outlined,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                          SizedBox(width: 8),
                          Text('Giao diện'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout_outlined,
                            size: 20,
                            color: AppTheme.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Đăng xuất',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = MediaQuery.sizeOf(context).width < 600;
                    if (isSmall) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(
                        Icons.logout_outlined,
                        color: AppTheme.error,
                      ),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VIVONA',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currentUser?.roleDisplayName ?? 'Ban Quản Lý',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _getRoleBadgeColor(currentUser?.role ?? ''),
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
        padding: const EdgeInsets.all(16.0),
        child: OutlinedButton.icon(
          onPressed: () => _showLogoutDialog(context),
          icon: const Icon(Icons.logout, size: 18, color: AppTheme.error),
          label: const Text(
            'Đăng xuất',
            style: TextStyle(color: AppTheme.error),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.error),
            minimumSize: const Size.fromHeight(40),
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

    final List<Widget> quickActionItems = [];
    final isAccountant = currentUser?.isAccountant ?? false;

    if (isTechnician) {
      if (canManageIssues) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.report_problem_outlined,
            label: 'Xử lý sự cố',
            color: Colors.orange,
            onTap: () => context.push(AppRoutes.managementIssues),
            badgeCount: pendingIssuesAsync.valueOrNull ?? 0,
          ),
        );
      }
      if (canManageMeterReadings) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.speed_outlined,
            label: 'Duyệt điện nước',
            color: AppStatusColors.pendingConfirmation,
            onTap: () async {
              await context.push(AppRoutes.managementMeterReading);
              ref.invalidate(pendingMeterReadingsCountProvider);
            },
            badgeCount: pendingMeterReadingsAsync.valueOrNull ?? 0,
          ),
        );
      }
      if (canManageEquipment) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.precision_manufacturing_outlined,
            label: 'Bảo trì TB',
            color: Colors.deepOrange,
            onTap: () => context.push(AppRoutes.managementEquipment),
          ),
        );
      }
      quickActionItems.add(
        _buildQuickAction(
          context,
          icon: Icons.inventory_2_outlined,
          label: 'Kho vật tư',
          color: Colors.teal,
          onTap: () => context.push(AppRoutes.managementMaterials),
        ),
      );
      quickActionItems.add(
        _buildQuickAction(
          context,
          icon: Icons.assignment_turned_in_outlined,
          label: 'Bàn giao',
          color: Colors.teal,
          onTap: () => context.push(AppRoutes.managementHandovers),
        ),
      );
    } else if (isAccountant) {
      if (canManageInvoices) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.receipt_long,
            label: 'Lập hóa đơn',
            color: AppTheme.secondary,
            onTap: () => context.push(AppRoutes.managementCreateInvoice),
          ),
        );
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.table_chart_rounded,
            label: 'Bàn kế toán',
            color: Colors.blueGrey,
            onTap: () => context.push(AppRoutes.managementAccountingWorkstation),
          ),
        );
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.analytics_outlined,
            label: 'Báo cáo TC',
            color: Colors.indigo,
            onTap: () => context.push(AppRoutes.managementFinancialReport),
          ),
        );
      }
      if (canManageMeterReadings) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.speed_outlined,
            label: 'Duyệt điện nước',
            color: AppStatusColors.pendingConfirmation,
            onTap: () async {
              await context.push(AppRoutes.managementMeterReading);
              ref.invalidate(pendingMeterReadingsCountProvider);
            },
            badgeCount: pendingMeterReadingsAsync.valueOrNull ?? 0,
          ),
        );
      }
      if (canViewPaymentTransactions) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.receipt_long_outlined,
            label: 'Giao dịch',
            color: Colors.deepPurple,
            onTap: () => context.push(AppRoutes.managementPaymentTransactions),
          ),
        );
      }
    } else {
      // Admin / Ban Quản Lý
      if (isAdmin) {
        quickActionItems.add(
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
            badgeCount: pendingLinkReqAsync.valueOrNull ?? 0,
          ),
        );
      }
      if (canManageInvoices) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.receipt_long,
            label: 'Lập hóa đơn',
            color: AppTheme.secondary,
            onTap: () => context.push(AppRoutes.managementCreateInvoice),
          ),
        );
      }
      if (canManageMeterReadings) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.speed_outlined,
            label: 'Duyệt điện nước',
            color: AppStatusColors.pendingConfirmation,
            onTap: () async {
              await context.push(AppRoutes.managementMeterReading);
              ref.invalidate(pendingMeterReadingsCountProvider);
            },
            badgeCount: pendingMeterReadingsAsync.valueOrNull ?? 0,
          ),
        );
      }
      if (canManageIssues) {
        quickActionItems.add(
          _buildQuickAction(
            context,
            icon: Icons.report_problem_outlined,
            label: 'Xử lý sự cố',
            color: Colors.orange,
            onTap: () => context.push(AppRoutes.managementIssues),
            badgeCount: pendingIssuesAsync.valueOrNull ?? 0,
          ),
        );
      }
      quickActionItems.add(
        _buildQuickAction(
          context,
          icon: Icons.desk_outlined,
          label: 'Lễ tân',
          color: Colors.deepOrange,
          onTap: () => context.push(AppRoutes.managementFrontDesk),
        ),
      );
    }

    // Nút mở Tất cả thao tác (luôn là slot thứ 6)
    quickActionItems.add(
      _buildQuickAction(
        context,
        icon: Icons.apps_rounded,
        label: 'Xem tất cả',
        color: AppTheme.primary,
        onTap: () => showAllQuickActionsSheet(
          context,
          ref: ref,
          isAdmin: isAdmin,
          canManageInvoices: canManageInvoices,
          canManageIssues: canManageIssues,
          canManageMeterReadings: canManageMeterReadings,
          canManageHandbook: canManageHandbook,
          canManageAmenities: canManageAmenities,
          canManageEquipment: canManageEquipment,
          canApproveVehicles: canApproveVehicles,
          canViewPaymentTransactions: canViewPaymentTransactions,
          canManageRoleDelegations: isAdmin,
          canManagePermissions: isAdmin,
          canViewAuditLogs: canViewAuditTrail,
          pendingLinkCount: pendingLinkReqAsync.valueOrNull ?? 0,
          pendingIssuesCount: pendingIssuesAsync.valueOrNull ?? 0,
          pendingMeterCount: pendingMeterReadingsAsync.valueOrNull ?? 0,
        ),
      ),
    );

    return RefreshIndicator(
      color: AppTheme.primary,
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
        padding: const EdgeInsets.all(16),
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
                      // Cột trái (65%): Dải KPI tương tác hành động + Việc cần xử lý ngay + Thống kê căn hộ + Doanh thu
                      Expanded(
                        flex: 65,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInteractiveKpiStrip(
                              pendingInvoicesAsync: pendingConfirmationAsync,
                              pendingIssuesAsync: pendingIssuesAsync,
                              pendingMeterReadingsAsync:
                                  pendingMeterReadingsAsync,
                              pendingLinkReqAsync: pendingLinkReqAsync,
                              canManageInvoices: canManageInvoices,
                              canManageIssues: canManageIssues,
                              canManageMeterReadings:
                                  canManageMeterReadings,
                              isAdmin: isAdmin,
                            ),
                            const SizedBox(height: 24),
                            _buildUrgentWorkSection(
                              allIssuesAsync: allIssuesAsync,
                              pendingConfirmationAsync:
                                  pendingConfirmationAsync,
                              pendingLinkReqAsync: pendingLinkReqAsync,
                              pendingMeterReadingsAsync:
                                  pendingMeterReadingsAsync,
                              isAdmin: isAdmin,
                              canManageInvoices: canManageInvoices,
                              canManageMeterReadings:
                                  canManageMeterReadings,
                            ),
                            const SizedBox(height: 24),
                            _buildApartmentResidentStats(
                              isTechnician,
                              pendingLinkReqAsync,
                            ),
                            const SizedBox(height: 24),
                            if (!isTechnician || canManageInvoices) ...[
                              Text(
                                'Tài chính & Thu phí',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const ManagementFinancialProgressCard(),
                              const SizedBox(height: 16),
                              const RevenueTrendChart(),
                              const SizedBox(height: 24),
                            ],
                            _buildOpsStats(
                              pendingIssuesAsync,
                              allIssuesAsync,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Cột phải (35%): Lối tắt nghiệp vụ + Quỹ bảo trì + Giao dịch thanh toán gần nhất
                      Expanded(
                        flex: 35,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuickActionsHeader(
                              context,
                              isAdmin: isAdmin,
                              canManageInvoices: canManageInvoices,
                              canManageIssues: canManageIssues,
                              canManageMeterReadings:
                                  canManageMeterReadings,
                              canManageHandbook: canManageHandbook,
                              canManageAmenities: canManageAmenities,
                              canManageEquipment: canManageEquipment,
                              canApproveVehicles: canApproveVehicles,
                              canViewPaymentTransactions:
                                  canViewPaymentTransactions,
                              canViewAuditTrail: canViewAuditTrail,
                              pendingLinkReqAsync: pendingLinkReqAsync,
                              pendingIssuesAsync: pendingIssuesAsync,
                              pendingMeterReadingsAsync:
                                  pendingMeterReadingsAsync,
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionsGrid(quickActionItems),
                            const SizedBox(height: 24),
                            const MaintenanceFundCard(isManagement: true),
                            const SizedBox(height: 24),
                            _buildRecentTransactionsSection(),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Mobile & Tablet (< 900dp): 1 Column
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickActionsHeader(
                      context,
                      isAdmin: isAdmin,
                      canManageInvoices: canManageInvoices,
                      canManageIssues: canManageIssues,
                      canManageMeterReadings: canManageMeterReadings,
                      canManageHandbook: canManageHandbook,
                      canManageAmenities: canManageAmenities,
                      canManageEquipment: canManageEquipment,
                      canApproveVehicles: canApproveVehicles,
                      canViewPaymentTransactions:
                          canViewPaymentTransactions,
                      canViewAuditTrail: canViewAuditTrail,
                      pendingLinkReqAsync: pendingLinkReqAsync,
                      pendingIssuesAsync: pendingIssuesAsync,
                      pendingMeterReadingsAsync: pendingMeterReadingsAsync,
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionsGrid(quickActionItems),
                    const SizedBox(height: 24),
                    _buildInteractiveKpiStrip(
                      pendingInvoicesAsync: pendingConfirmationAsync,
                      pendingIssuesAsync: pendingIssuesAsync,
                      pendingMeterReadingsAsync: pendingMeterReadingsAsync,
                      pendingLinkReqAsync: pendingLinkReqAsync,
                      canManageInvoices: canManageInvoices,
                      canManageIssues: canManageIssues,
                      canManageMeterReadings: canManageMeterReadings,
                      isAdmin: isAdmin,
                    ),
                    const SizedBox(height: 24),
                    _buildUrgentWorkSection(
                      allIssuesAsync: allIssuesAsync,
                      pendingConfirmationAsync: pendingConfirmationAsync,
                      pendingLinkReqAsync: pendingLinkReqAsync,
                      pendingMeterReadingsAsync: pendingMeterReadingsAsync,
                      isAdmin: isAdmin,
                      canManageInvoices: canManageInvoices,
                      canManageMeterReadings: canManageMeterReadings,
                    ),
                    const SizedBox(height: 24),
                    _buildApartmentResidentStats(
                      isTechnician,
                      pendingLinkReqAsync,
                    ),
                    const SizedBox(height: 24),
                    if (!isTechnician || canManageInvoices) ...[
                      Text(
                        'Tài chính & Thu phí',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const ManagementFinancialProgressCard(),
                      const SizedBox(height: 16),
                      const RevenueTrendChart(),
                      const SizedBox(height: 16),
                      const MaintenanceFundCard(isManagement: true),
                      const SizedBox(height: 16),
                      _buildRecentTransactionsSection(),
                      const SizedBox(height: 24),
                    ],
                    _buildOpsStats(pendingIssuesAsync, allIssuesAsync),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsHeader(
    BuildContext context, {
    required bool isAdmin,
    required bool canManageInvoices,
    required bool canManageIssues,
    required bool canManageMeterReadings,
    required bool canManageHandbook,
    required bool canManageAmenities,
    required bool canManageEquipment,
    required bool canApproveVehicles,
    required bool canViewPaymentTransactions,
    required bool canViewAuditTrail,
    required AsyncValue<int> pendingLinkReqAsync,
    required AsyncValue<int> pendingIssuesAsync,
    required AsyncValue<int> pendingMeterReadingsAsync,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Thao tác nhanh',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () => showAllQuickActionsSheet(
            context,
            ref: ref,
            isAdmin: isAdmin,
            canManageInvoices: canManageInvoices,
            canManageIssues: canManageIssues,
            canManageMeterReadings: canManageMeterReadings,
            canManageHandbook: canManageHandbook,
            canManageAmenities: canManageAmenities,
            canManageEquipment: canManageEquipment,
            canApproveVehicles: canApproveVehicles,
            canViewPaymentTransactions: canViewPaymentTransactions,
            canManageRoleDelegations: isAdmin,
            canManagePermissions: isAdmin,
            canViewAuditLogs: canViewAuditTrail,
            pendingLinkCount: pendingLinkReqAsync.valueOrNull ?? 0,
            pendingIssuesCount: pendingIssuesAsync.valueOrNull ?? 0,
            pendingMeterCount: pendingMeterReadingsAsync.valueOrNull ?? 0,
          ),
          child: const Text('Xem tất cả'),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(List<Widget> quickActionItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int cols = width < 420
            ? 3
            : (width < 768
                ? 4
                : (width < 1100
                    ? 4
                    : 6));
        final double ratio = width < 360 ? 0.95 : (width < 600 ? 1.05 : 1.15);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: ratio,
          children: quickActionItems,
        );
      },
    );
  }

  Widget _buildUrgentWorkSection({
    required AsyncValue<List<IssueModel>> allIssuesAsync,
    required AsyncValue<int> pendingConfirmationAsync,
    required AsyncValue<int> pendingLinkReqAsync,
    required AsyncValue<int> pendingMeterReadingsAsync,
    required bool isAdmin,
    required bool canManageInvoices,
    required bool canManageMeterReadings,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Công việc cần xử lý ngay • Phản ánh cần xử lý gấp',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppStatusColors.priorityHigh,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        allIssuesAsync.when(
          data: (issues) {
            final urgentIssues = issues
                .where(
                  (issue) =>
                      issue.priority == 'high' && issue.status == 'pending',
                )
                .toList();
            final pendingConfirmationCount =
                pendingConfirmationAsync.valueOrNull ?? 0;
            final pendingLinkCount =
                (isAdmin ? pendingLinkReqAsync.valueOrNull : 0) ?? 0;
            final pendingMeterCount =
                (canManageMeterReadings
                    ? pendingMeterReadingsAsync.valueOrNull
                    : 0) ??
                0;

            final allUrgentCards = <Widget>[];

            for (final issue in urgentIssues) {
              allUrgentCards.add(
                _buildUrgentCard(
                  icon: Icons.warning,
                  color: AppStatusColors.priorityHigh,
                  title:
                      'Phản ánh sự cố — Căn ${issue.apartment?.code ?? 'N/A'}',
                  subtitle: issue.description,
                  actionLabel: 'Xem ngay',
                  onAction: () => context.push(AppRoutes.managementIssues),
                ),
              );
            }
            if (pendingConfirmationCount > 0 && canManageInvoices) {
              allUrgentCards.add(
                _buildUrgentCard(
                  icon: Icons.receipt_long,
                  color: Colors.purple,
                  title: 'Hóa đơn chờ đối soát ($pendingConfirmationCount)',
                  subtitle: 'Cư dân đã gửi minh chứng thanh toán',
                  actionLabel: 'Đối soát',
                  onAction: () => context.push(AppRoutes.managementInvoices),
                ),
              );
            }
            if (pendingLinkCount > 0 && isAdmin) {
              allUrgentCards.add(
                _buildUrgentCard(
                  icon: Icons.person_add,
                  color: AppTheme.primary,
                  title: 'Yêu cầu liên kết căn hộ ($pendingLinkCount)',
                  subtitle: 'Cư dân đăng ký thông tin căn hộ chờ duyệt',
                  actionLabel: 'Duyệt ngay',
                  onAction: () async {
                    await context.push(AppRoutes.managementLinkRequests);
                    ref.invalidate(pendingLinkRequestsCountProvider);
                    ref.invalidate(residentsProvider);
                  },
                ),
              );
            }
            if (pendingMeterCount > 0 && canManageMeterReadings) {
              allUrgentCards.add(
                _buildUrgentCard(
                  icon: Icons.speed_outlined,
                  color: AppStatusColors.pendingConfirmation,
                  title: 'Chỉ số điện nước chờ duyệt ($pendingMeterCount)',
                  subtitle: 'Cần xác nhận chỉ số để chốt kỳ thanh toán',
                  actionLabel: 'Duyệt ngay',
                  onAction: () async {
                    await context.push(AppRoutes.managementMeterReading);
                    ref.invalidate(pendingMeterReadingsCountProvider);
                  },
                ),
              );
            }

            if (allUrgentCards.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppStatusColors.paid,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Không có sự cố khẩn cấp nào cần xử lý.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final visibleCards = allUrgentCards.take(3).toList();
            final remainingCount = allUrgentCards.length - visibleCards.length;

            return Column(
              children: [
                ...visibleCards,
                if (remainingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size.fromHeight(40),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      onPressed: () => context.push(AppRoutes.managementIssues),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Xem thêm $remainingCount việc cần xử lý khác',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => AppSkeletonShimmer.cardList(
            count: 2,
            itemHeight: 56,
            borderRadius: BorderRadius.circular(12),
          ),
          error: (e, _) => const Text(
            'Lỗi tải dữ liệu',
            style: TextStyle(color: AppTheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          final actionButton = ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(88, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actionButton),
              ],
            );
          }

          return Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              actionButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildInteractiveKpiStrip({
    required AsyncValue<int> pendingInvoicesAsync,
    required AsyncValue<int> pendingIssuesAsync,
    required AsyncValue<int> pendingMeterReadingsAsync,
    required AsyncValue<int> pendingLinkReqAsync,
    required bool canManageInvoices,
    required bool canManageIssues,
    required bool canManageMeterReadings,
    required bool isAdmin,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chỉ số hành động trọng tâm',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final int cols = width < 600 ? 2 : (width < 1100 ? 4 : 4);
            final double ratio =
                width < 360 ? 1.05 : (width < 600 ? 1.25 : 1.45);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
              children: [
                StatCard(
                  title: 'Hóa đơn chờ thu',
                  value: pendingInvoicesAsync.when(
                    data: (count) => '$count',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  subtitle: 'Bấm đối soát',
                  icon: Icons.receipt_long,
                  color: AppTheme.secondary,
                  onTap: () => context.push(AppRoutes.managementInvoices),
                ),
                StatCard(
                  title: 'Sự cố đang mở',
                  value: pendingIssuesAsync.when(
                    data: (count) => '$count',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  subtitle: 'Bấm xử lý',
                  icon: Icons.report_problem_outlined,
                  color: Colors.orange,
                  onTap: () => context.push(AppRoutes.managementIssues),
                ),
                StatCard(
                  title: 'Chỉ số chờ duyệt',
                  value: pendingMeterReadingsAsync.when(
                    data: (count) => '$count',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  subtitle: 'Bấm duyệt số',
                  icon: Icons.speed_outlined,
                  color: AppStatusColors.pendingConfirmation,
                  onTap: () async {
                    await context.push(AppRoutes.managementMeterReading);
                    ref.invalidate(pendingMeterReadingsCountProvider);
                  },
                ),
                StatCard(
                  title: 'Yêu cầu chờ duyệt',
                  value: pendingLinkReqAsync.when(
                    data: (count) => '$count',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  subtitle: 'Bấm phê duyệt',
                  icon: Icons.person_add_alt_1,
                  color: AppTheme.primary,
                  onTap: () async {
                    await context.push(AppRoutes.managementLinkRequests);
                    ref.invalidate(pendingLinkRequestsCountProvider);
                    ref.invalidate(residentsProvider);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildApartmentResidentStats(
    bool isTechnician,
    AsyncValue<int> pendingLinkReqAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cư dân & Căn hộ — Tổng quan trạng thái',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final int cols = width < 600 ? 2 : (width < 1100 ? 3 : 4);
            final double ratio =
                width < 360 ? 0.98 : (width < 600 ? 1.18 : 1.45);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
              children: [
                ref.watch(totalApartmentsProvider).isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Tổng số Căn hộ',
                        value: ref
                            .watch(totalApartmentsProvider)
                            .when(
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
                        value: ref
                            .watch(totalResidentsProvider)
                            .when(
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
                        value: ref
                            .watch(occupancyRateProvider)
                            .when(
                              data: (rate) =>
                                  '${(rate * 100).toStringAsFixed(1)}%',
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
                  ref.watch(emptyApartmentsProvider).isLoading
                      ? const StatCardSkeleton()
                      : StatCard(
                          title: 'Căn hộ trống',
                          value: ref
                              .watch(emptyApartmentsProvider)
                              .when(
                                data: (count) => '$count',
                                loading: () => '...',
                                error: (_, _) => 'Lỗi',
                              ),
                          icon: Icons.meeting_room_outlined,
                          color: Colors.amber.shade700,
                        ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOpsStats(
    AsyncValue<int> pendingIssuesAsync,
    AsyncValue<List<IssueModel>> allIssuesAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vận hành & Kỹ thuật',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final int cols = width < 600 ? 2 : (width < 1100 ? 2 : 2);
            final double ratio =
                width < 360 ? 0.98 : (width < 600 ? 1.18 : 1.45);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
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
                allIssuesAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Sự cố đang xử lý',
                        value: allIssuesAsync.when(
                          data: (issues) =>
                              '${issues.where((i) => i.status == 'in_progress').length}',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.build_circle_outlined,
                        color: Colors.orange,
                      ),
              ],
            );
          },
        ),
      ],
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
              onPressed: () {
                context.push(AppRoutes.managementPaymentTransactions);
              },
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const ManagementRecentTransactionsCard(),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
    double? width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Bounceable(
      onTap: onTap,
      scaleFactor: 0.94,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 28),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppStatusColors.priorityHigh,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

