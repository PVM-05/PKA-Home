import '../../../core/widgets/sync_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_card.dart';
import '../widgets/sticky_emergency_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
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
import '../../../data/providers/resident_apartment_provider.dart';
import '../../../core/widgets/maintenance_fund_card.dart';
import '../../../core/widgets/pdpl_consent_dialog.dart';
import '../../../data/providers/notification_provider.dart';
import '../widgets/equipment_interruption_banner.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PdplConsentManager.showConsentDialogIfNeeded(context);
      }
    });
  }

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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
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
                                AppAvatar(
                                  name: fullName,
                                  size: 40,
                                  fontSize: 15,
                                  onTap: () => _onItemTapped(3),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Xin chào,',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
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
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
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
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  icon: const Icon(
                                    Icons.logout_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  tooltip: 'Đăng xuất',
                                  onPressed: () => _showLogoutDialog(context),
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
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cột trái (60%): Hóa đơn + Thao tác nhanh + Dịch vụ tiện ích
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInvoiceOverviewSection(invoiceAsync),
                                  const SizedBox(height: 24),
                                  _buildQuickActionsRow(),
                                  const SizedBox(height: 24),
                                  _buildResidentServicesSection(context),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Cột phải (40%): Cảnh báo gián đoạn + Quỹ bảo trì + Phản ánh + Thông báo
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const StickyEmergencyBar(),
                                  const EquipmentInterruptionBanner(),
                                  const SizedBox(height: 16),
                                  const MaintenanceFundCard(),
                                  const SizedBox(height: 24),
                                  _buildLatestIssueSection(issueAsync),
                                  const SizedBox(height: 24),
                                  _buildAnnouncementsSection(
                                    announcementsAsync,
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
                          _buildInvoiceOverviewSection(invoiceAsync),
                          const SizedBox(height: 12),
                          const MaintenanceFundCard(),
                          const SizedBox(height: 20),
                          const EquipmentInterruptionBanner(),
                          const SizedBox(height: 20),
                          _buildQuickActionsRow(),
                          const SizedBox(height: 24),
                          _buildResidentServicesSection(context),
                          const SizedBox(height: 24),
                          _buildLatestIssueSection(issueAsync),
                          const SizedBox(height: 24),
                          _buildAnnouncementsSection(announcementsAsync),
                          const SizedBox(height: 40),
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

  Widget _buildInvoiceOverviewSection(
    AsyncValue<List<InvoiceModel>> invoiceAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tổng quan hóa đơn',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        invoiceAsync.when(
          data: (invoices) {
            final unpaidInvoices = invoices
                .where(
                  (i) =>
                      i.status == 'unpaid' ||
                      i.status == 'pending_confirmation',
                )
                .toList();
            final totalUnpaid = unpaidInvoices.fold<double>(
              0,
              (sum, item) => sum + item.totalAmount,
            );
            final unpaidCount = unpaidInvoices.length;

            if (totalUnpaid > 0) {
              return Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.brandPrimary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.softMd,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Đến hạn thanh toán',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '( $unpaidCount hóa đơn chưa thanh toán )',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tổng tiền cần đóng',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        NumberFormat.currency(
                          locale: 'vi_VN',
                          symbol: 'VNĐ',
                        ).format(totalUnpaid),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _onItemTapped(1),
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        size: 18,
                      ),
                      label: const Text(
                        'THANH TOÁN NGAY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.sapphire,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fade(duration: 400.ms, delay: 100.ms)
              .slideX(begin: 0.1, curve: Curves.easeOut);
            }

            return AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.success,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Đã hoàn tất',
                              style: TextStyle(
                                color: AppTheme.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Flexible(
                        child: Text(
                          '( Đã thanh toán đầy đủ các kỳ phí )',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Đã thanh toán đầy đủ các kỳ phí',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Căn hộ của bạn không có hóa đơn quá hạn hoặc đang chờ đối soát.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _onItemTapped(1),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text(
                      'XEM HÓA ĐƠN',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fade(duration: 400.ms, delay: 100.ms)
            .slideX(begin: 0.1, curve: Curves.easeOut);
          },
          loading: () => AppSkeletonShimmer.rectangular(
            width: double.infinity,
            height: 160,
            borderRadius: BorderRadius.circular(20),
          ),
          error: (err, st) => AppErrorCard(
            error: err,
            onRetry: () => ref.invalidate(residentInvoiceProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildQuickAction(
            Icons.qr_code_scanner,
            'Thanh toán',
            () => _onItemTapped(1),
            accentColor: AppTheme.sapphire,
          ).animate().fade(duration: 300.ms).slideY(
            begin: 0.2,
            curve: Curves.easeOutQuad,
          ),
        ),
        Expanded(
          child: _buildQuickAction(
            Icons.build_circle_outlined,
            'Báo sự cố',
            () => _onItemTapped(2),
            accentColor: Colors.orange,
          ).animate().fade(duration: 300.ms, delay: 100.ms).slideY(
            begin: 0.2,
            curve: Curves.easeOutQuad,
          ),
        ),
        Expanded(
          child: _buildQuickAction(
            Icons.emergency_outlined,
            'Hotline',
            () => context.push(
              AppRoutes.residentHandbook,
              extra: 0,
            ),
            accentColor: AppTheme.error,
          ).animate().fade(duration: 300.ms, delay: 200.ms).slideY(
            begin: 0.2,
            curve: Curves.easeOutQuad,
          ),
        ),
        Expanded(
          child: _buildQuickAction(
            Icons.menu_book_outlined,
            'Cẩm nang',
            () => context.push(
              AppRoutes.residentHandbook,
              extra: 1,
            ),
            accentColor: Colors.teal,
          ).animate().fade(duration: 300.ms, delay: 300.ms).slideY(
            begin: 0.2,
            curve: Curves.easeOutQuad,
          ),
        ),
      ],
    );
  }

  Widget _buildResidentServicesSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildServiceCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
    }) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white60
                              : AppTheme.textSecondary,
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
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        Widget meterAndVehicleRow;
        if (isNarrow) {
          meterAndVehicleRow = Column(
            children: [
              buildServiceCard(
                title: 'Số điện nước',
                subtitle: 'Quét OCR & Gửi chỉ số',
                icon: Icons.speed_outlined,
                color: const Color(0xFFE65100),
                onTap: () => context.push(AppRoutes.residentMeterReading),
              ),
              const SizedBox(height: 10),
              buildServiceCard(
                title: 'Đăng ký gửi xe',
                subtitle: 'Quản lý phương tiện',
                icon: Icons.directions_car_filled_outlined,
                color: const Color(0xFF1E88E5),
                onTap: () => context.push(AppRoutes.residentVehicles),
              ),
            ],
          );
        } else {
          meterAndVehicleRow = Row(
            children: [
              Expanded(
                child: buildServiceCard(
                  title: 'Số điện nước',
                  subtitle: 'Quét OCR & Gửi chỉ số',
                  icon: Icons.speed_outlined,
                  color: const Color(0xFFE65100),
                  onTap: () => context.push(AppRoutes.residentMeterReading),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildServiceCard(
                  title: 'Đăng ký gửi xe',
                  subtitle: 'Quản lý phương tiện',
                  icon: Icons.directions_car_filled_outlined,
                  color: const Color(0xFF1E88E5),
                  onTap: () => context.push(AppRoutes.residentVehicles),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dịch vụ & Tiện ích',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            meterAndVehicleRow,
            const SizedBox(height: 10),
            buildServiceCard(
              title: 'Đón khách & Bưu kiện',
              subtitle: 'Tạo mã QR đón khách & Mã PIN nhận hàng',
              icon: Icons.mark_as_unread_outlined,
              color: const Color(0xFF673AB7),
              onTap: () => context.push(AppRoutes.residentVisitorParcel),
            ),
            const SizedBox(height: 10),
            buildServiceCard(
              title: 'Biểu quyết & Ý kiến',
              subtitle: 'Tham gia biểu quyết điện tử & Đóng góp kiến nghị',
              icon: Icons.how_to_vote_outlined,
              color: const Color(0xFF00897B),
              onTap: () => context.push(AppRoutes.residentCommunity),
            ),
            const SizedBox(height: 10),
            buildServiceCard(
              title: 'Bàn giao & Kiểm kê',
              subtitle: 'Biên bản nhận/trả căn hộ & Ký số kiểm kê tài sản',
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFF00796B),
              onTap: () => context.push(AppRoutes.residentHandovers),
            ),
            const SizedBox(height: 10),
            buildServiceCard(
              title: 'Tiện ích chung',
              subtitle: 'BBQ, Hồ bơi, Phòng gym & Quy định sinh hoạt',
              icon: Icons.pool_outlined,
              color: const Color(0xFF26A69A),
              onTap: () => context.push(AppRoutes.residentHandbook, extra: 2),
            ),
          ],
        )
        .animate()
        .fade(duration: 350.ms, delay: 150.ms)
        .slideY(begin: 0.1, curve: Curves.easeOutQuad);
      },
    );
  }

  Widget _buildLatestIssueSection(AsyncValue<List<IssueModel>> issueAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tiến độ phản ánh',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        issueAsync.when(
          data: (issues) {
            if (issues.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Căn hộ hoạt động ổn định',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Không có phản ánh nào gần đây.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _onItemTapped(2),
                      child: const Text('Báo mới'),
                    ),
                  ],
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
            return AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withValues(
                    alpha: 0.1,
                  ),
                  child: Icon(statusIcon, color: statusColor),
                ),
                title: Text(
                  latestIssue.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                ),
                onTap: () => _onItemTapped(2),
              ),
            )
            .animate()
            .fade(duration: 400.ms, delay: 200.ms)
            .slideX(begin: 0.1, curve: Curves.easeOut);
          },
          loading: () => AppSkeletonShimmer.cardList(
            count: 1,
            itemHeight: 68,
            borderRadius: BorderRadius.circular(16),
          ),
          error: (err, st) => AppErrorCard(
            error: err,
            onRetry: () => ref.invalidate(residentIssueProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementsSection(
    AsyncValue<List<AnnouncementModel>> announcementsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Thông báo mới nhất',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            announcementsAsync.maybeWhen(
              data: (announcements) => announcements.length > 3
                  ? TextButton(
                      onPressed: () => context.push(
                        AppRoutes.residentNotifications,
                      ),
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
              return const AppCard(
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
                  date:
                      '${announcement.createdAt.day.toString().padLeft(2, '0')}/${announcement.createdAt.month.toString().padLeft(2, '0')}/${announcement.createdAt.year}',
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
          loading: () => AppSkeletonShimmer.cardList(
            count: 2,
            itemHeight: 74,
            borderRadius: BorderRadius.circular(16),
          ),
          error: (error, stack) => AppErrorCard(
            error: error,
            onRetry: () =>
                ref.invalidate(announcementsStreamProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? AppTheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
