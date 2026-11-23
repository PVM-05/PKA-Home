import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bounceable.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/providers/dashboard_providers.dart';
import '../../../../data/providers/management_provider.dart';
import '../../../../data/providers/meter_reading_provider.dart';
import '../all_quick_actions_sheet.dart';

class ManagementQuickActionsSection extends ConsumerWidget {
  final UserModel? currentUser;
  final bool isAdmin;
  final bool canManageInvoices;
  final bool canManageIssues;
  final bool canManageMeterReadings;
  final bool canManageHandbook;
  final bool canManageAmenities;
  final bool canManageEquipment;
  final bool canApproveVehicles;
  final bool canViewPaymentTransactions;
  final bool canViewAuditTrail;
  final AsyncValue<int> pendingLinkReqAsync;
  final AsyncValue<int> pendingIssuesAsync;
  final AsyncValue<int> pendingMeterReadingsAsync;

  const ManagementQuickActionsSection({
    super.key,
    required this.currentUser,
    required this.isAdmin,
    required this.canManageInvoices,
    required this.canManageIssues,
    required this.canManageMeterReadings,
    required this.canManageHandbook,
    required this.canManageAmenities,
    required this.canManageEquipment,
    required this.canApproveVehicles,
    required this.canViewPaymentTransactions,
    required this.canViewAuditTrail,
    required this.pendingLinkReqAsync,
    required this.pendingIssuesAsync,
    required this.pendingMeterReadingsAsync,
  });

  void _openAllActions(BuildContext context, WidgetRef ref) {
    showAllQuickActionsSheet(
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final successColor = AppTheme.getSemanticSuccess(context);
    final pendingConfirmColor = AppStatusColors.getPendingConfirmation(context);
    final tertiaryColor = colorScheme.tertiary;

    final isTechnician = currentUser?.isTechnician ?? false;
    final isAccountant = currentUser?.isAccountant ?? false;

    final quickActionItems = <Widget>[];

    if (isTechnician) {
      if (canManageIssues) {
        quickActionItems.add(
          _QuickActionTile(
            icon: Icons.report_problem_outlined,
            label: 'Xử lý sự cố',
            color: warningColor,
            onTap: () => context.push(AppRoutes.managementIssues),
            badgeCount: pendingIssuesAsync.valueOrNull ?? 0,
          ),
        );
      }
      if (canManageMeterReadings) {
        quickActionItems.add(
          _QuickActionTile(
            icon: Icons.speed_outlined,
            label: 'Duyệt điện nước',
            color: pendingConfirmColor,
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
          _QuickActionTile(
            icon: Icons.precision_manufacturing_outlined,
            label: 'Bảo trì TB',
            color: warningColor,
            onTap: () => context.push(AppRoutes.managementEquipment),
          ),
        );
      }
      quickActionItems.add(
        _QuickActionTile(
          icon: Icons.inventory_2_outlined,
          label: 'Kho vật tư',
          color: successColor,
          onTap: () => context.push(AppRoutes.managementMaterials),
        ),
      );
      quickActionItems.add(
        _QuickActionTile(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Bàn giao',
          color: tertiaryColor,
          onTap: () => context.push(AppRoutes.managementHandovers),
        ),
      );
    } else if (isAccountant) {
      if (canManageInvoices) {
        quickActionItems.add(
          _QuickActionTile(
            icon: Icons.receipt_long,
            label: 'Lập hóa đơn',
            color: secondaryColor,
            onTap: () => context.push(AppRoutes.managementCreateInvoice),
          ),
        );
        quickActionItems.add(
          _QuickActionTile(
            icon: Icons.table_chart_rounded,
            label: 'Bàn kế toán',
            color: colorScheme.onSurfaceVariant,
            onTap: () =>
                context.push(AppRoutes.managementAccountingWorkstation),
          ),
        );
        quickActionItems.add(
          _QuickActionTile(
            icon: Icons.analytics_outlined,
            label: 'Báo cáo TC',
            color: primaryColor,
            onTap: () => context.push(AppRoutes.managementFinancialReport),
          ),
        );
      }
      if (canManageMeterReadings) {
        quickActionItems.add(
          _QuickActionTile(
            icon: Icons.speed_outlined,
            label: 'Duyệt điện nước',
            color: pendingConfirmColor,
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
          _QuickActionTile(
            icon: Icons.receipt_long_outlined,
            label: 'Giao dịch',
            color: tertiaryColor,
            onTap: () =>
                context.push(AppRoutes.managementPaymentTransactions),
          ),
        );
      }
    } else {
      if (isAdmin) {
        quickActionItems.add(
          _QuickActionTile(
            icon: Icons.person_add,
            label: 'Duyệt liên kết',
            color: primaryColor,
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
          _QuickActionTile(
            icon: Icons.receipt_long,
            label: 'Lập hóa đơn',
            color: secondaryColor,
            onTap: () => context.push(AppRoutes.managementCreateInvoice),
          ),
        );
      }
      if (canManageMeterReadings) {
        quickActionItems.add(
          _QuickActionTile(
            icon: Icons.speed_outlined,
            label: 'Duyệt điện nước',
            color: pendingConfirmColor,
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
          _QuickActionTile(
            icon: Icons.report_problem_outlined,
            label: 'Xử lý sự cố',
            color: warningColor,
            onTap: () => context.push(AppRoutes.managementIssues),
            badgeCount: pendingIssuesAsync.valueOrNull ?? 0,
          ),
        );
      }
      quickActionItems.add(
        _QuickActionTile(
          icon: Icons.desk_outlined,
          label: 'Lễ tân',
          color: tertiaryColor,
          onTap: () => context.push(AppRoutes.managementFrontDesk),
        ),
      );
    }

    quickActionItems.add(
      _QuickActionTile(
        icon: Icons.apps_rounded,
        label: 'Xem tất cả',
        color: primaryColor,
        onTap: () => _openAllActions(context, ref),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _openAllActions(context, ref),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        AppSpacing.h8,
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cols = width < 420
                ? 3
                : (width < 1100 ? 4 : 6);
            final ratio = width < 360 ? 0.95 : (width < 600 ? 1.05 : 1.15);
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
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Bounceable(
      onTap: onTap,
      scaleFactor: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.16 : 0.08),
          borderRadius: AppRadius.r12,
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.22),
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
                        color: AppTheme.textError,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onError,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.h6,
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
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
