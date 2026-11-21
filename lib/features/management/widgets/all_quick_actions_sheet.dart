import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/core/router/route_names.dart';
import 'package:vivona/data/providers/dashboard_providers.dart';
import 'package:vivona/data/providers/management_provider.dart';
import 'package:vivona/data/providers/meter_reading_provider.dart';

/// Bảng điều khiển tác vụ quản trị toàn diện ("Xem tất cả"):
/// Phân nhóm theo 4 trụ cột nghiệp vụ chuẩn B2B PropTech SaaS:
/// 1. Vận hành tòa nhà
/// 2. Tài chính & Kế toán
/// 3. Truyền thông & Cư dân (bao gồm Bảng tin thông báo chuyển từ tab bottom bar)
/// 4. Hệ thống & Thiết lập
void showAllQuickActionsSheet(
  BuildContext context, {
  required WidgetRef ref,
  required bool isAdmin,
  required bool canManageInvoices,
  required bool canManageIssues,
  required bool canManageMeterReadings,
  required bool canManageHandbook,
  required bool canManageAmenities,
  required bool canManageEquipment,
  required bool canApproveVehicles,
  required bool canViewPaymentTransactions,
  required bool canManageRoleDelegations,
  required bool canManagePermissions,
  required bool canViewAuditLogs,
  required int pendingLinkCount,
  required int pendingIssuesCount,
  required int pendingMeterCount,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetContext, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.apps_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tất cả thao tác quản trị',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    // Nhóm 1: Vận hành tòa nhà
                    _buildSheetSectionHeader(
                      context,
                      'Vận hành tòa nhà',
                      Icons.domain_outlined,
                    ),
                    if (canManageIssues)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.report_problem_outlined,
                        title: 'Xử lý sự cố',
                        subtitle:
                            'Tiếp nhận, phân công và khắc phục phản ánh cư dân',
                        color: Colors.orange,
                        badgeCount: pendingIssuesCount,
                        onTap: () => context.push(AppRoutes.managementIssues),
                      ),
                    if (canManageEquipment)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.precision_manufacturing_outlined,
                        title: 'Bảo trì thiết bị',
                        subtitle:
                            'Lập lịch và theo dõi bảo dưỡng thang máy, máy phát',
                        color: Colors.deepOrange,
                        onTap: () =>
                            context.push(AppRoutes.managementEquipment),
                      ),
                    if (canManageAmenities)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.pool_outlined,
                        title: 'Tiện ích chung',
                        subtitle:
                            'Hồ bơi, sân thể thao, BBQ và kiểm soát lượt đặt chỗ',
                        color: Colors.teal.shade700,
                        onTap: () =>
                            context.push(AppRoutes.managementAmenities),
                      ),
                    _buildSheetActionItem(
                      context: context,
                      icon: Icons.local_parking_rounded,
                      title: 'Bãi xe & Ô đỗ',
                      subtitle:
                          'Sơ đồ ô đỗ hầm, kiểm soát sức chứa và trạm soát vé',
                      color: Colors.blue.shade700,
                      onTap: () => context.push(AppRoutes.managementParking),
                    ),
                    if (canApproveVehicles)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.two_wheeler_outlined,
                        title: 'Duyệt phương tiện',
                        subtitle:
                            'Xét duyệt hồ sơ gửi xe máy, ô tô của cư dân',
                        color: Colors.blueGrey,
                        onTap: () =>
                            context.push(AppRoutes.managementVehicleApproval),
                      ),
                    _buildSheetActionItem(
                      context: context,
                      icon: Icons.desk_outlined,
                      title: 'Lễ tân & An ninh sảnh',
                      subtitle:
                          'Đón khách, tiếp nhận bưu kiện shipper và mã PIN',
                      color: Colors.deepOrange,
                      onTap: () =>
                          context.push(AppRoutes.managementFrontDesk),
                    ),
                    if (canManageIssues)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.inventory_2_outlined,
                        title: 'Kho vật tư kỹ thuật',
                        subtitle:
                            'Định mức tồn kho, xuất kho bảo trì & trừ vật tư sự cố',
                        color: Colors.teal,
                        onTap: () =>
                            context.push(AppRoutes.managementMaterials),
                      ),

                    const SizedBox(height: 14),
                    // Nhóm 2: Tài chính & Kế toán
                    _buildSheetSectionHeader(
                      context,
                      'Tài chính & Kế toán',
                      Icons.account_balance_wallet_outlined,
                    ),
                    if (canManageInvoices)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.receipt_long,
                        title: 'Lập hóa đơn',
                        subtitle:
                            'Tạo phiếu thu phí quản lý, điện, nước hàng tháng',
                        color: AppTheme.secondary,
                        onTap: () =>
                            context.push(AppRoutes.managementCreateInvoice),
                      ),
                    if (canManageInvoices)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.table_chart_rounded,
                        title: 'Bàn làm việc kế toán',
                        subtitle:
                            'Đối soát sao kê VietQR, thu tiền tại quầy và phiếu thu',
                        color: Colors.blueGrey,
                        onTap: () => context.push(
                          AppRoutes.managementAccountingWorkstation,
                        ),
                      ),
                    if (canManageMeterReadings)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.speed_outlined,
                        title: 'Duyệt chỉ số điện nước',
                        subtitle:
                            'Kiểm tra và phê duyệt số điện nước công tơ',
                        color: Colors.orange.shade900,
                        badgeCount: pendingMeterCount,
                        onTap: () async {
                          await context.push(
                            AppRoutes.managementMeterReading,
                          );
                          ref.invalidate(pendingMeterReadingsCountProvider);
                        },
                      ),
                    if (canViewPaymentTransactions)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.receipt_long_outlined,
                        title: 'Lịch sử giao dịch',
                        subtitle:
                            'Theo dõi dòng tiền và đối soát chuyển khoản VietQR',
                        color: Colors.deepPurple,
                        onTap: () => context.push(
                          AppRoutes.managementPaymentTransactions,
                        ),
                      ),
                    if (canManageInvoices)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.analytics_outlined,
                        title: 'Báo cáo tài chính & Sổ quỹ',
                        subtitle:
                            'Báo cáo doanh thu, công nợ lũy kế và quỹ bảo trì 2%',
                        color: Colors.indigo,
                        onTap: () => context.push(
                          AppRoutes.managementFinancialReport,
                        ),
                      ),

                    const SizedBox(height: 14),
                    // Nhóm 3: Truyền thông & Cư dân
                    _buildSheetSectionHeader(
                      context,
                      'Truyền thông & Cư dân',
                      Icons.campaign_outlined,
                    ),
                    if (isAdmin)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.person_add_outlined,
                        title: 'Duyệt liên kết căn hộ',
                        subtitle:
                            'Phê duyệt tài khoản cư dân liên kết căn hộ',
                        color: AppTheme.primary,
                        badgeCount: pendingLinkCount,
                        onTap: () async {
                          await context.push(
                            AppRoutes.managementLinkRequests,
                          );
                          ref.invalidate(pendingLinkRequestsCountProvider);
                          ref.invalidate(residentsProvider);
                        },
                      ),
                    if (isAdmin)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.domain_outlined,
                        title: 'Quản lý căn hộ',
                        subtitle: 'Danh sách và thông tin sơ đồ căn hộ',
                        color: Colors.teal,
                        onTap: () =>
                            context.push(AppRoutes.managementApartments),
                      ),
                    _buildSheetActionItem(
                      context: context,
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Bàn giao & Kiểm kê',
                      subtitle: 'Biên bản nhận/trả nhà & Ký số kiểm kê tài sản',
                      color: Colors.teal,
                      onTap: () =>
                          context.push(AppRoutes.managementHandovers),
                    ),
                    _buildSheetActionItem(
                      context: context,
                      icon: Icons.campaign_rounded,
                      title: 'Bảng tin thông báo',
                      subtitle:
                          'Soạn và phát thông báo tin tức, lịch cắt điện nước',
                      color: AppTheme.primary,
                      onTap: () =>
                          context.push(AppRoutes.managementAnnouncements),
                    ),
                    _buildSheetActionItem(
                      context: context,
                      icon: Icons.how_to_vote_outlined,
                      title: 'Cộng đồng & Biểu quyết',
                      subtitle:
                          'Biểu quyết điện tử Luật Nhà ở & Xử lý kiến nghị',
                      color: Colors.blueGrey,
                      onTap: () =>
                          context.push(AppRoutes.managementCommunity),
                    ),
                    if (canManageHandbook)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.menu_book_outlined,
                        title: 'Cẩm nang cư dân',
                        subtitle: 'Quy định, hướng dẫn và nội quy tòa nhà',
                        color: Colors.indigo,
                        onTap: () =>
                            context.push(AppRoutes.managementHandbook),
                      ),
                    if (canManageIssues)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.star_rate_rounded,
                        title: 'Đánh giá dịch vụ',
                        subtitle:
                            'Khảo sát độ hài lòng của cư dân về dịch vụ tòa nhà',
                        color: Colors.amber.shade700,
                        onTap: () =>
                            context.push(AppRoutes.managementServiceRatings),
                      ),

                    const SizedBox(height: 14),
                    // Nhóm 4: Hệ thống & Thiết lập
                    _buildSheetSectionHeader(
                      context,
                      'Hệ thống & Thiết lập',
                      Icons.tune_outlined,
                    ),
                    if (isAdmin) ...[
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.upload_file_outlined,
                        title: 'Nhập Excel cư dân & căn hộ',
                        subtitle:
                            'Nhập dữ liệu hàng loạt từ file bảng tính Excel',
                        color: Colors.teal,
                        onTap: () =>
                            context.push(AppRoutes.managementBatchImport),
                      ),
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.badge_outlined,
                        title: 'Danh sách kích hoạt',
                        subtitle:
                            'Theo dõi mã kích hoạt định danh tài khoản cư dân',
                        color: Colors.indigo,
                        onTap: () =>
                            context.push(AppRoutes.managementActivationList),
                      ),
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.card_membership_outlined,
                        title: 'Gói cước SaaS tòa nhà',
                        subtitle:
                            'Quản lý gói dịch vụ và thời hạn bản quyền phần mềm',
                        color: Colors.purple,
                        onTap: () =>
                            context.push(AppRoutes.managementSubscription),
                      ),
                    ],
                    if (canManageRoleDelegations)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.vpn_key_outlined,
                        title: 'Ủy quyền công việc',
                        subtitle: 'Phân quyền tạm thời cho nhân sự cấp phó',
                        color: Colors.purple,
                        onTap: () =>
                            context.push(AppRoutes.managementRoleDelegation),
                      ),
                    if (canManagePermissions)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.security_outlined,
                        title: 'Ma trận phân quyền',
                        subtitle: 'Cấu hình chi tiết quyền hạn từng vai trò',
                        color: Colors.indigoAccent,
                        onTap: () => context.push(
                          AppRoutes.managementPermissionMatrix,
                        ),
                      ),
                    if (canViewAuditLogs)
                      _buildSheetActionItem(
                        context: context,
                        icon: Icons.history_edu_outlined,
                        title: 'Nhật ký kiểm toán',
                        subtitle:
                            'Ghi vết bảo mật và hoạt động thay đổi hệ thống',
                        color: Colors.blueGrey,
                        onTap: () =>
                            context.push(AppRoutes.managementAuditTrail),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildSheetSectionHeader(
  BuildContext context,
  String title,
  IconData icon,
) {
  return Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSheetActionItem({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
  int badgeCount = 0,
}) {
  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 6),
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: ListTile(
      dense: true,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: const BoxDecoration(
                  color: AppStatusColors.priorityHigh,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(
                  '$badgeCount',
                  style: context.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.labelSmall?.copyWith(color: AppTheme.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: AppTheme.textSecondary,
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    ),
  );
}
