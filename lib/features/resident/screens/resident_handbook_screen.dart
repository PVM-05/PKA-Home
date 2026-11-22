import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/emergency_contact_model.dart';
import '../../../data/providers/handbook_provider.dart';

class ResidentHandbookScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const ResidentHandbookScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<ResidentHandbookScreen> createState() =>
      _ResidentHandbookScreenState();
}

class _ResidentHandbookScreenState extends ConsumerState<ResidentHandbookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final launchUri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else if (mounted) {
        AppSnackBar.showError(
          context,
          'Không thể thực hiện cuộc gọi đến $phoneNumber',
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Không thể mở ứng dụng điện thoại cho số: $phoneNumber',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: context.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm hotline, nội quy...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              )
            : const Text('Cẩm Nang Cư Dân'),
        actions: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Đóng tìm kiếm' : 'Tìm kiếm',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.emergency_outlined), text: 'Đường dây nóng'),
            Tab(icon: Icon(Icons.gavel_outlined), text: 'Nội quy tòa nhà'),
            Tab(icon: Icon(Icons.help_outline), text: 'Biểu phí & FAQ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmergencyContactsTab(),
          _buildBuildingRulesTab(),
          _buildFeeScheduleAndFaqTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Đường Dây Nóng
  // ===========================================================================
  Widget _buildEmergencyContactsTab() {
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(emergencyContactsProvider),
      child: contactsAsync.when(
        data: (contacts) {
          final filteredContacts = _searchQuery.isEmpty
              ? contacts
              : contacts
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(_searchQuery) ||
                          c.phone.contains(_searchQuery) ||
                          c.contactType.toLowerCase().contains(_searchQuery),
                    )
                    .toList();

          if (filteredContacts.isEmpty) {
            return AppEmptyState(
              icon: Icons.phone_in_talk_outlined,
              title: _searchQuery.isEmpty
                  ? 'Chưa có thông tin đường dây nóng'
                  : 'Không tìm thấy liên hệ phù hợp',
              description: _searchQuery.isEmpty
                  ? 'Ban Quản Lý sẽ sớm cập nhật các số điện thoại khẩn cấp của tòa nhà.'
                  : 'Không tìm thấy liên hệ phù hợp với "$_searchQuery".',
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: AppSpacing.p16,
                itemCount: filteredContacts.length,
                itemBuilder: (context, index) =>
                    _buildContactCard(context, filteredContacts[index]),
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 3, itemHeight: 100)],
        ),
        error: (e, _) => Center(
          child: AppErrorCard(
            error: e,
            onRetry: () => ref.invalidate(emergencyContactsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    EmergencyContactModel contact,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color typeColor;
    final IconData typeIcon;
    final String typeLabel;

    switch (contact.contactType) {
      case 'fire':
        typeColor = AppTheme.getSemanticError(context);
        typeIcon = Icons.local_fire_department_outlined;
        typeLabel = 'Cứu hỏa / PCCC';
      case 'management':
        typeColor = colorScheme.primary;
        typeIcon = Icons.business_outlined;
        typeLabel = 'Văn phòng BQL';
      case 'technical':
        typeColor = AppStatusColors.getPending(context);
        typeIcon = Icons.build_outlined;
        typeLabel = 'Đội kỹ thuật';
      case 'security':
      default:
        typeColor = AppStatusColors.getPaid(context);
        typeIcon = Icons.security_outlined;
        typeLabel = 'An ninh / Bảo vệ';
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.p16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;

          final headerContent = Row(
            children: [
              Container(
                padding: AppSpacing.p12,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(typeIcon, color: typeColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        borderRadius: AppRadius.r8,
                      ),
                      child: Text(
                        typeLabel,
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ),
                    AppSpacing.h4,
                    Text(
                      contact.name,
                      style: context.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.h4,
                    Text(
                      contact.phone,
                      style: context.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final callButton = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textSuccess,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
            ),
            onPressed: () => _makePhoneCall(contact.phone),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text(
              'Gọi ngay',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerContent,
                AppSpacing.h12,
                callButton,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: headerContent),
              AppSpacing.w8,
              callButton,
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tab 2: Nội Quy Tòa Nhà
  // ===========================================================================
  Widget _buildBuildingRulesTab() {
    final rulesAsync = ref.watch(buildingRulesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildingRulesProvider),
      child: rulesAsync.when(
        data: (rules) {
          final filteredRules = _searchQuery.isEmpty
              ? rules
              : rules
                    .where(
                      (r) =>
                          r.title.toLowerCase().contains(_searchQuery) ||
                          r.content.toLowerCase().contains(_searchQuery),
                    )
                    .toList();

          if (filteredRules.isEmpty) {
            return AppEmptyState(
              icon: Icons.gavel_outlined,
              title: _searchQuery.isEmpty
                  ? 'Chưa có nội quy được đăng tải'
                  : 'Không tìm thấy nội quy phù hợp',
              description: _searchQuery.isEmpty
                  ? 'Ban Quản Lý sẽ sớm cập nhật bộ nội quy tòa nhà tại đây.'
                  : 'Không tìm thấy nội quy phù hợp với "$_searchQuery".',
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: AppSpacing.p16,
                itemCount: filteredRules.length,
                itemBuilder: (context, index) {
                  final rule = filteredRules[index];
                  return AppCard(
                    padding: EdgeInsets.zero,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(
                              alpha: isDark ? 0.18 : 0.10,
                            ),
                            borderRadius: AppRadius.r8,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        title: Text(
                          rule.title,
                          style: context.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              rule.content,
                              style: context.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 3, itemHeight: 80)],
        ),
        error: (e, _) => Center(
          child: AppErrorCard(
            error: e,
            onRetry: () => ref.invalidate(buildingRulesProvider),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Tab 3: Biểu Phí & FAQ
  // ===========================================================================
  Widget _buildFeeScheduleAndFaqTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: AppSpacing.p16,
          children: [
            AppCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              onTap: () => context.push(AppRoutes.residentAmenities),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      ),
                      borderRadius: AppRadius.r12,
                    ),
                    child: Icon(
                      Icons.pool_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  AppSpacing.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xem danh mục Tiện ích tòa nhà',
                          style: context.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSpacing.h4,
                        Text(
                          'Đặt lịch Hồ bơi, BBQ, Gym và theo dõi ca sử dụng',
                          style: context.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            Text(
              'Biểu Phí Quản Lý & Vận Hành',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            AppSpacing.h8,
            AppCard(
              padding: AppSpacing.p16,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildFeeRow(
                    context: context,
                    title: 'Phí dịch vụ quản lý',
                    rate: AppConstants.kDefaultManagementFeeFormatted,
                    formula: 'Đơn giá × Diện tích thông thủy căn hộ',
                  ),
                  const Divider(height: 20),
                  _buildFeeRow(
                    context: context,
                    title: 'Phí gửi xe máy',
                    rate: AppConstants.kMotorbikeFeeFormatted,
                    formula: 'Đăng ký tối đa 2 xe máy/căn hộ',
                  ),
                  const Divider(height: 20),
                  _buildFeeRow(
                    context: context,
                    title: 'Phí gửi ô tô',
                    rate: AppConstants.kCarFeeFormatted,
                    formula: 'Theo vị trí đỗ xe tại tầng hầm',
                  ),
                  const Divider(height: 20),
                  _buildFeeRow(
                    context: context,
                    title: 'Tiền điện sinh hoạt',
                    rate: 'Biểu giá EVN',
                    formula: 'Bậc thang theo công tơ riêng của từng căn',
                  ),
                  const Divider(height: 20),
                  _buildFeeRow(
                    context: context,
                    title: 'Tiền nước sạch',
                    rate: 'Theo định mức nước',
                    formula: 'Chỉ số đồng hồ đo thực tế × Đơn giá',
                  ),
                ],
              ),
            ),
            AppSpacing.h24,
            Text(
              'Câu Hỏi Thường Gặp',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            AppSpacing.h8,
            _buildFaqItem(
              context: context,
              question: 'Tôi thanh toán hóa đơn bằng cách nào?',
              answer:
                  'Tại màn hình Hóa đơn, nhấn "Xem chi tiết" -> "Thanh toán". Ứng dụng cung cấp Cổng thanh toán trực tuyến tiện lợi hỗ trợ thanh toán tức thì hoặc Cư dân có thể thanh toán trực tiếp tại văn phòng Ban Quản Lý.',
            ),
            _buildFaqItem(
              context: context,
              question: 'Khi gặp sự cố trong căn hộ thì xử lý thế nào?',
              answer:
                  'Bạn có thể vào mục "Phản ánh" để gửi hình ảnh và mô tả sự cố cho BQL tiếp nhận. Nếu là sự cố khẩn cấp (chập điện, rò nước), vui lòng gọi ngay hotline kỹ thuật tại tab "Đường dây nóng".',
            ),
            _buildFaqItem(
              context: context,
              question: 'Làm thế nào để thêm thành viên cùng ở vào căn hộ?',
              answer:
                  'Thành viên mới cần cài đặt app, đăng ký tài khoản với vai trò Cư dân, sau đó tại màn hình "Tài khoản của tôi" bấm "Xin liên kết căn hộ". Ban Quản Lý sẽ xác minh và phê duyệt trong vòng 24 giờ.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow({
    required BuildContext context,
    required String title,
    required String rate,
    required String formula,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.h4,
              Text(
                formula,
                style: context.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.w8,
        Text(
          rate,
          style: context.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildFaqItem({
    required BuildContext context,
    required String question,
    required String answer,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.help_outline, color: colorScheme.primary),
          title: Text(
            question,
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: context.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
