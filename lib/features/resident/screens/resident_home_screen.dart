import '../../../core/widgets/sync_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../widgets/sticky_emergency_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/app_avatar.dart';
import '../widgets/apartment_switcher_chip.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/announcement_provider.dart';
import '../../../data/providers/resident_invoice_provider.dart';
import '../../../data/providers/resident_issue_provider.dart';
import '../../../data/providers/meter_reading_provider.dart';
import 'resident_invoice_screen.dart';
import 'resident_issue_screen.dart';
import 'resident_profile_screen.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/announcement_model.dart';
import '../../../data/providers/link_request_provider.dart';
import '../../../data/providers/resident_apartment_provider.dart';
import '../../../core/widgets/maintenance_fund_card.dart';
import '../../../core/widgets/pdpl_consent_dialog.dart';
import '../../../data/providers/notification_provider.dart';
import '../widgets/equipment_interruption_banner.dart';
import '../widgets/home/resident_home_upcoming_invoice_card.dart';
import '../widgets/home/resident_home_quick_actions_row.dart';
import '../widgets/home/resident_home_services_section.dart';
import '../widgets/home/resident_home_latest_issue_card.dart';
import '../widgets/home/resident_home_announcements_card.dart';
import '../widgets/home/resident_utility_consumption_chart_card.dart';
import '../widgets/home/meter_reading_reminder_banner.dart';
import '../providers/home_personalization_provider.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/widgets/bounceable.dart';
import '../widgets/resident_onboarding_dialog.dart';

class ResidentHomeScreen extends ConsumerStatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  ConsumerState<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends ConsumerState<ResidentHomeScreen> {
  int _selectedIndex = 0;
  String? _lastNotifiedApartmentId;
  Set<String> _knownInvoiceIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await PdplConsentManager.showConsentDialogIfNeeded(context);
      if (!mounted) return;
      final user = ref.read(authProvider).value;
      if (user != null && user.isResident) {
        ResidentOnboardingDialog.checkAndShow(context, user);
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
            AppSpacing.w12,
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: AppRadius.shape12,
        margin: AppSpacing.p16,
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAptId = ref.watch(selectedApartmentIdProvider);
    _lastNotifiedApartmentId ??= currentAptId;

    final initialInvoices = ref.watch(residentInvoiceProvider).valueOrNull;
    if (_knownInvoiceIds.isEmpty && initialInvoices != null) {
      _knownInvoiceIds = initialInvoices.map((i) => i.id).toSet();
    }

    // 1. Lắng nghe cập nhật hóa đơn thời gian thực (Toast nội bộ, không spam khi đổi căn hộ)
    ref.listen<AsyncValue<List<InvoiceModel>>>(residentInvoiceProvider, (
      previous,
      next,
    ) {
      if (next.hasValue) {
        final liveAptId = ref.read(selectedApartmentIdProvider);
        final nextList = next.value!;
        final nextIds = nextList.map((i) => i.id).toSet();

        // Nếu vừa chuyển đổi căn hộ hoặc nạp dữ liệu lần đầu:
        if (liveAptId != _lastNotifiedApartmentId) {
          _lastNotifiedApartmentId = liveAptId;
          _knownInvoiceIds = nextIds;
          return; // Bỏ qua so sánh hóa đơn mới để không gây spam toast khi đổi căn hộ
        }

        if (previous?.hasValue == true) {
          final prevList = previous!.value!;
          final currencyFormat = NumberFormat.currency(
            locale: 'vi_VN',
            symbol: 'đ',
            decimalDigits: 0,
          );

          for (final nextInv in nextList) {
            final isBrandNew = !_knownInvoiceIds.contains(nextInv.id);

            // Trường hợp 1: Có hóa đơn mới vừa được tạo cho chính căn hộ này
            if (isBrandNew) {
              debugPrint(
                '🔔 [ResidentHome] Phát hiện hóa đơn mới kỳ: ${nextInv.period}',
              );
              _showNotificationToast(
                icon: Icons.receipt_long,
                message:
                    'Hóa đơn mới kỳ ${nextInv.period}: ${currencyFormat.format(nextInv.totalAmount)}',
                backgroundColor: AppTheme.primary,
              );
            } else {
              // Trường hợp 2: Hóa đơn được Ban Quản Lý xác nhận thanh toán thành công
              final prevInv = prevList.cast<InvoiceModel?>().firstWhere(
                (p) => p?.id == nextInv.id,
                orElse: () => null,
              );
              if (prevInv != null &&
                  prevInv.status != nextInv.status &&
                  nextInv.status == 'paid') {
                debugPrint(
                  '🔔 [ResidentHome] Hóa đơn kỳ ${nextInv.period} đã được thanh toán',
                );
                _showNotificationToast(
                  icon: Icons.check_circle,
                  message:
                      'Hóa đơn kỳ ${nextInv.period} đã được Ban Quản Lý xác nhận thanh toán thành công!',
                  backgroundColor: AppTheme.success,
                );
              }
            }
          }
        }
        _knownInvoiceIds = nextIds;
      }
    });

    // 2. Lắng nghe cập nhật phản ánh sự cố thời gian thực
    ref.listen<AsyncValue<List<IssueModel>>>(residentIssueProvider, (
      previous,
      next,
    ) {
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
              debugPrint(
                '🔔 [ResidentHome] Cập nhật sự cố đang xử lý: ${nextIssue.description}',
              );
              _showNotificationToast(
                icon: Icons.engineering,
                message:
                    'Phản ánh "${nextIssue.description}" đang được Ban Quản Lý xử lý.',
                backgroundColor: AppTheme.primary,
              );
            } else if (nextIssue.status == 'resolved') {
              debugPrint(
                '🔔 [ResidentHome] Cập nhật sự cố đã giải quyết: ${nextIssue.description}',
              );
              _showNotificationToast(
                icon: Icons.verified,
                message:
                    'Phản ánh "${nextIssue.description}" đã được giải quyết hoàn tất!',
                backgroundColor: AppTheme.success,
              );
            }
          }
        }
      }
    });

    // 3. Lắng nghe thông báo mới đăng thời gian thực (Bảng tin thông báo chung)
    ref.listen<
      AsyncValue<List<AnnouncementModel>>
    >(announcementsStreamProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevIds = previous!.value!.map((a) => a.id).toSet();
        final newlyAdded = next.value!
            .where((a) => !prevIds.contains(a.id))
            .toList();
        for (final newest in newlyAdded) {
          debugPrint(
            '📣 [ResidentHome] Phát hiện thông báo bảng tin mới: "${newest.title}"',
          );
          _showNotificationToast(
            icon: newest.isUrgent
                ? Icons.warning_amber_rounded
                : Icons.campaign,
            message: newest.isUrgent
                ? 'THÔNG BÁO KHẨN: ${newest.title}'
                : 'Thông báo mới: ${newest.title}',
            backgroundColor: newest.isUrgent
                ? AppTheme.error
                : AppTheme.primary,
            duration: const Duration(seconds: 5),
          );
        }
      }
    });

    // 4. Lắng nghe phê duyệt liên kết căn hộ thời gian thực
    ref.listen<ResidentLinkStatus>(residentLinkProvider, (previous, next) {
      if (previous?.status == LinkStatus.pending &&
          next.status == LinkStatus.linked) {
        _showNotificationToast(
          icon: Icons.apartment,
          message:
              'Yêu cầu liên kết căn hộ đã được Ban Quản Lý phê duyệt thành công!',
          backgroundColor: AppTheme.success,
        );
      }
    });

    return Scaffold(
      body: Column(
        children: [
          const SyncStatusBar(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboard(),
                const ResidentInvoiceScreen(),
                const ResidentIssueScreen(),
                const ResidentProfileScreen(),
              ],
            ),
          ),
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
    final announcementsAsync = ref.watch(residentAnnouncementsProvider);
    final invoiceAsync = ref.watch(residentInvoiceProvider);
    final issueAsync = ref.watch(residentIssueProvider);
    final personalization = ref.watch(homePersonalizationProvider);
    final fullName = user?.fullName ?? 'Cư dân';

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(residentInvoicePaginatedProvider);
        ref.invalidate(residentInvoiceProvider);
        ref.invalidate(residentUnpaidInvoicesProvider);
        ref.invalidate(residentIssuePaginatedProvider);
        ref.invalidate(residentIssueProvider);
        ref.invalidate(residentUtilityConsumptionHistoryProvider);
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Bounceable(
                                  onTap: () => _onItemTapped(3),
                                  child: AppAvatar(
                                    name: fullName,
                                    size: 40,
                                  ),
                                ),
                                AppSpacing.w8,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Xin chào,',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Consumer(
                                  builder: (context, ref, _) {
                                    final unreadCount = ref.watch(
                                      unreadNotificationsCountProvider,
                                    );
                                    return IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      icon: Badge(
                                        isLabelVisible: unreadCount > 0,
                                        label: Text('$unreadCount'),
                                        backgroundColor: AppStatusColors.unpaid,
                                        child: const Icon(
                                          Icons.notifications_outlined,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      tooltip: 'Thông báo',
                                      onPressed: () {
                                        context.push(
                                          AppRoutes.residentNotifications,
                                        );
                                      },
                                    );
                                  },
                                ),

                              ],
                            ),
                            const SizedBox(height: 8),
                            const ApartmentSwitcherChip(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 900;
                      final isIssuePriority =
                          personalization.priority == HomePriority.activeIssueTracking;

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cột trái (60%): Nhắc chỉ số + Hóa đơn + Thao tác nhanh + [Sự cố ưu tiên] + Dịch vụ tiện ích + Biểu đồ
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (personalization.showMeterReadingReminder) ...[
                                    const MeterReadingReminderBanner(),
                                    AppSpacing.h20,
                                  ],
                                  ResidentHomeUpcomingInvoiceCard(
                                    invoiceAsync: invoiceAsync,
                                    mostUrgentInvoice: personalization.mostUrgentInvoice,
                                    daysUntilDueDate: personalization.daysUntilDueDate,
                                    onNavigateToInvoices: () => _onItemTapped(1),
                                    onRetry: () => ref.invalidate(residentInvoiceProvider),
                                  ),
                                  AppSpacing.h24,
                                  ResidentHomeQuickActionsRow(
                                    onPaymentTap: () => _onItemTapped(1),
                                    onIssueTap: () => _onItemTapped(2),
                                    onHandbookHotlineTap: () => context.push(
                                      AppRoutes.residentHandbook,
                                      extra: 0,
                                    ),
                                    onHandbookGuideTap: () => context.push(
                                      AppRoutes.residentHandbook,
                                      extra: 1,
                                    ),
                                  ),
                                  AppSpacing.h24,
                                  if (isIssuePriority) ...[
                                    ResidentHomeLatestIssueCard(
                                      issueAsync: issueAsync,
                                      activeIssue: personalization.activeIssue,
                                      onNavigateToIssues: () => _onItemTapped(2),
                                      onRetry: () => ref.invalidate(residentIssueProvider),
                                    ),
                                    AppSpacing.h24,
                                  ],
                                  const ResidentHomeServicesSection(),
                                  AppSpacing.h24,
                                  const ResidentUtilityConsumptionChartCard(),
                                  AppSpacing.h24,
                                  const MaintenanceFundCard(),
                                ],
                              ),
                            ),
                            AppSpacing.w24,
                            // Cột phải (40%): Cảnh báo khẩn cấp + Gián đoạn thiết bị + [Phản ánh thường] + Bảng tin
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const StickyEmergencyBar(),
                                  const EquipmentInterruptionBanner(),
                                  if (!isIssuePriority) ...[
                                    AppSpacing.h16,
                                    ResidentHomeLatestIssueCard(
                                      issueAsync: issueAsync,
                                      activeIssue: personalization.activeIssue,
                                      onNavigateToIssues: () => _onItemTapped(2),
                                      onRetry: () => ref.invalidate(residentIssueProvider),
                                    ),
                                  ],
                                  AppSpacing.h24,
                                  ResidentHomeAnnouncementsCard(
                                    announcementsAsync: announcementsAsync,
                                    onRetry: () => ref.invalidate(announcementsStreamProvider),
                                  ),
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
                          const StickyEmergencyBar(),
                          const EquipmentInterruptionBanner(),
                          if (personalization.showMeterReadingReminder) ...[
                            const MeterReadingReminderBanner(),
                            AppSpacing.h16,
                          ],
                          ResidentHomeUpcomingInvoiceCard(
                            invoiceAsync: invoiceAsync,
                            mostUrgentInvoice: personalization.mostUrgentInvoice,
                            daysUntilDueDate: personalization.daysUntilDueDate,
                            onNavigateToInvoices: () => _onItemTapped(1),
                            onRetry: () => ref.invalidate(residentInvoiceProvider),
                          ),
                          AppSpacing.h20,
                          ResidentHomeQuickActionsRow(
                            onPaymentTap: () => _onItemTapped(1),
                            onIssueTap: () => _onItemTapped(2),
                            onHandbookHotlineTap: () => context.push(
                              AppRoutes.residentHandbook,
                              extra: 0,
                            ),
                            onHandbookGuideTap: () => context.push(
                              AppRoutes.residentHandbook,
                              extra: 1,
                            ),
                          ),
                          AppSpacing.h24,
                          if (isIssuePriority) ...[
                            ResidentHomeLatestIssueCard(
                              issueAsync: issueAsync,
                              activeIssue: personalization.activeIssue,
                              onNavigateToIssues: () => _onItemTapped(2),
                              onRetry: () => ref.invalidate(residentIssueProvider),
                            ),
                            AppSpacing.h24,
                          ],
                          const ResidentHomeServicesSection(),
                          AppSpacing.h24,
                          const ResidentUtilityConsumptionChartCard(),
                          AppSpacing.h20,
                          const MaintenanceFundCard(),
                          if (!isIssuePriority) ...[
                            AppSpacing.h24,
                            ResidentHomeLatestIssueCard(
                              issueAsync: issueAsync,
                              activeIssue: personalization.activeIssue,
                              onNavigateToIssues: () => _onItemTapped(2),
                              onRetry: () => ref.invalidate(residentIssueProvider),
                            ),
                          ],
                          AppSpacing.h24,
                          ResidentHomeAnnouncementsCard(
                            announcementsAsync: announcementsAsync,
                            onRetry: () => ref.invalidate(announcementsStreamProvider),
                          ),
                          AppSpacing.h40,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
