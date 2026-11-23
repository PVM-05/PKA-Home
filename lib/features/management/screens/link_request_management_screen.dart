import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/providers/link_request_management_provider.dart';

class LinkRequestManagementScreen extends ConsumerWidget {
  const LinkRequestManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsState = ref.watch(linkRequestManagementProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    return RoleGuard(
      permission: AppPermissions.linkRequestManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Duyệt yêu cầu liên kết'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: () => ref.invalidate(linkRequestManagementProvider),
            ),
          ],
        ),
        body: AppStateView<List<Map<String, dynamic>>>(
          asyncValue: requestsState,
          emptyMessage: 'Không có yêu cầu nào đang chờ duyệt',
          emptyIcon: Icons.check_circle_outline,
          onRetry: () => ref.invalidate(linkRequestManagementProvider),
          dataBuilder: (requests) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(linkRequestManagementProvider),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.p16,
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final user = req['users'] as Map<String, dynamic>?;
                      final apartment =
                          req['apartments'] as Map<String, dynamic>?;
                      final residentName =
                          user?['full_name'] as String? ?? 'Cư dân (Không rõ)';
                      final residentPhone = user?['phone'] as String?;
                      final apartmentCode =
                          apartment?['code'] as String? ?? 'Chưa xác định';
                      final requestedRole =
                          req['requested_relation_role']?.toString() ??
                              'member';

                      final isOwner = requestedRole == 'owner';
                      final roleLabel = isOwner
                          ? 'Chủ hộ'
                          : (requestedRole == 'tenant'
                              ? 'Khách thuê'
                              : 'Thành viên');
                      final badgeColor =
                          isOwner ? colorScheme.primary : secondaryColor;

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: AppSpacing.p16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        residentName,
                                        style: context.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (residentPhone != null &&
                                          residentPhone.isNotEmpty) ...[
                                        AppSpacing.h4,
                                        Text(
                                          'SĐT: $residentPhone',
                                          style: context.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              )
                                              .tabularFigures(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                AppSpacing.w8,
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: AppRadius.r12,
                                    border: Border.all(
                                      color: badgeColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    roleLabel,
                                    style: context.labelSmall?.copyWith(
                                      color: badgeColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.h12,
                            Row(
                              children: [
                                Icon(
                                  Icons.apartment_outlined,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                AppSpacing.w8,
                                Expanded(
                                  child: Text(
                                    'Căn hộ: $apartmentCode',
                                    style: context.bodyMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        )
                                        .tabularFigures(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (isOwner) ...[
                              AppSpacing.h12,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: warningColor.withValues(alpha: 0.1),
                                  borderRadius: AppRadius.r8,
                                  border: Border.all(
                                    color: warningColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: warningColor,
                                    ),
                                    AppSpacing.w6,
                                    Expanded(
                                      child: Text(
                                        'Yêu cầu vai trò Chủ hộ: Cần kiểm tra kỹ hồ sơ hợp đồng sở hữu trước khi duyệt.',
                                        style: context.labelSmall?.copyWith(
                                          color: warningColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            AppSpacing.h16,
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: errorColor,
                                      side: BorderSide(color: errorColor),
                                      minimumSize: const Size(0, 48),
                                    ),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Từ chối'),
                                    onPressed: () => _handleReject(
                                      context,
                                      ref,
                                      req['id'].toString(),
                                      residentName,
                                      apartmentCode,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      minimumSize: const Size(0, 48),
                                    ),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Phê duyệt'),
                                    onPressed: () => _handleApprove(
                                      context,
                                      ref,
                                      req['id'].toString(),
                                      residentName,
                                      apartmentCode,
                                      roleLabel,
                                      isOwner,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    WidgetRef ref,
    String id,
    String residentName,
    String apartmentCode,
    String roleLabel,
    bool isOwner,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final warningColor = AppTheme.getSemanticWarning(ctx);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colorScheme.primary),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Xác nhận phê duyệt',
                  style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phê duyệt liên kết căn hộ cho cư dân:'),
                AppSpacing.h8,
                Container(
                  width: double.infinity,
                  padding: AppSpacing.p12,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: AppRadius.r8,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cư dân: $residentName',
                        style: ctx.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.h4,
                      Text(
                        'Căn hộ: $apartmentCode',
                        style: ctx.bodyMedium?.tabularFigures(),
                      ),
                      AppSpacing.h4,
                      Text(
                        'Vai trò được cấp: $roleLabel',
                        style: ctx.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwner) ...[
                  AppSpacing.h12,
                  Container(
                    padding: AppSpacing.p12,
                    decoration: BoxDecoration(
                      color: warningColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r8,
                      border: Border.all(
                        color: warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security, color: warningColor, size: 18),
                        AppSpacing.w8,
                        Expanded(
                          child: Text(
                            'Cảnh báo: Cư dân sẽ có toàn quyền đại diện căn hộ, nhận thông báo công nợ và thêm các thành viên khác.',
                            style: ctx.labelSmall?.copyWith(
                              color: warningColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Xác nhận duyệt'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await runAction(
      context,
      () async {
        await ref
            .read(linkRequestManagementProvider.notifier)
            .approveRequest(id);
        return 'Đã phê duyệt liên kết căn hộ $apartmentCode cho $residentName!';
      },
      actionName: 'Phê duyệt liên kết căn hộ',
    );
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    String id,
    String residentName,
    String apartmentCode,
  ) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final errorColor = AppTheme.getSemanticError(ctx);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.cancel_outlined, color: errorColor),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Từ chối yêu cầu liên kết',
                  style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Từ chối liên kết của cư dân $residentName với căn hộ $apartmentCode.',
                    style: ctx.bodyMedium,
                  ),
                  AppSpacing.h12,
                  Text(
                    'Lý do từ chối * (Cư dân sẽ nhận được thông báo này)',
                    style: ctx.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.h6,
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'VD: Số điện thoại không khớp hợp đồng mua bán, căn hộ đã có chủ hộ...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập lý do từ chối'
                        : null,
                  ),
                  AppSpacing.h12,
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildReasonChip(
                        ctx,
                        'SĐT không khớp hợp đồng',
                        reasonCtrl,
                      ),
                      _buildReasonChip(ctx, 'Căn hộ đã có chủ hộ', reasonCtrl),
                      _buildReasonChip(
                        ctx,
                        'Thiếu giấy tờ chứng minh',
                        reasonCtrl,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Xác nhận từ chối'),
            ),
          ],
        );
      },
    );

    final reason = reasonCtrl.text.trim();

    if (confirmed != true || !context.mounted) return;

    await runAction(
      context,
      () async {
        await ref
            .read(linkRequestManagementProvider.notifier)
            .rejectRequest(id, reason: reason);
        return 'Đã từ chối yêu cầu liên kết của $residentName.';
      },
      actionName: 'Từ chối yêu cầu liên kết',
    );
  }

  Widget _buildReasonChip(
    BuildContext context,
    String text,
    TextEditingController controller,
  ) {
    return ActionChip(
      label: Text(text, style: context.labelSmall),
      onPressed: () => controller.text = text,
    );
  }
}
