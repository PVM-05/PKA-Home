import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/providers/link_request_management_provider.dart';

class LinkRequestManagementScreen extends ConsumerWidget {
  const LinkRequestManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsState = ref.watch(linkRequestManagementProvider);

    return RoleGuard(
      permission: AppPermissions.linkRequestManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Duyệt yêu cầu liên kết'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
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
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final user = req['users'] as Map<String, dynamic>?;
                    final apartment = req['apartments'] as Map<String, dynamic>?;
                    final residentName = user?['full_name'] as String? ?? 'Cư dân (Không rõ)';
                    final residentPhone = user?['phone'] as String?;
                    final apartmentCode = apartment?['code'] as String? ?? 'Chưa xác định';
                    final requestedRole = req['requested_relation_role']?.toString() ?? 'member';

                    final isOwner = requestedRole == 'owner';
                    final roleLabel = isOwner
                        ? 'Chủ hộ'
                        : (requestedRole == 'tenant' ? 'Khách thuê' : 'Thành viên');

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      residentName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (residentPhone != null && residentPhone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'SĐT: $residentPhone',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOwner
                                      ? AppTheme.primary.withValues(alpha: 0.12)
                                      : Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isOwner
                                        ? AppTheme.primary.withValues(alpha: 0.3)
                                        : Colors.teal.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  roleLabel,
                                  style: TextStyle(
                                    color: isOwner ? AppTheme.primary : Colors.teal.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.apartment_outlined,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Căn hộ: $apartmentCode',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (isOwner) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warning),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Yêu cầu vai trò Chủ hộ: Cần kiểm tra kỹ hồ sơ hợp đồng sở hữu trước khi duyệt.',
                                      style: TextStyle(fontSize: 11.5, color: Colors.brown),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.close,
                                  color: AppTheme.error,
                                ),
                                label: const Text(
                                  'Từ chối',
                                  style: TextStyle(color: AppTheme.error),
                                ),
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
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
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
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleApprove(
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Xác nhận phê duyệt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phê duyệt liên kết căn hộ cho cư dân:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cư dân: $residentName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Căn hộ: $apartmentCode'),
                  const SizedBox(height: 4),
                  Text('Vai trò được cấp: $roleLabel', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (isOwner) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: AppTheme.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cảnh báo: Cư dân sẽ có toàn quyền đại diện căn hộ, nhận thông báo công nợ và thêm các thành viên khác.',
                        style: TextStyle(fontSize: 11.5, color: Colors.brown),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Xác nhận duyệt'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await runAction(
      context,
      () async {
        await ref.read(linkRequestManagementProvider.notifier).approveRequest(id);
        return 'Đã phê duyệt liên kết căn hộ $apartmentCode cho $residentName!';
      },
      actionName: 'Phê duyệt liên kết căn hộ',
    );
  }

  void _handleReject(
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Từ chối yêu cầu liên kết', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lý do từ chối * (Cư dân sẽ nhận được thông báo này)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'VD: Số điện thoại không khớp hợp đồng mua bán, căn hộ đã có chủ hộ...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập lý do từ chối' : null,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildReasonChip('SĐT không khớp hợp đồng', reasonCtrl),
                    _buildReasonChip('Căn hộ đã có chủ hộ', reasonCtrl),
                    _buildReasonChip('Thiếu giấy tờ chứng minh', reasonCtrl),
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
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true || !context.mounted) return;

    await runAction(
      context,
      () async {
        await ref.read(linkRequestManagementProvider.notifier).rejectRequest(id, reason: reason);
        return 'Đã từ chối yêu cầu liên kết của $residentName.';
      },
      actionName: 'Từ chối yêu cầu liên kết',
    );
  }

  Widget _buildReasonChip(String text, TextEditingController controller) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 11)),
      onPressed: () => controller.text = text,
    );
  }
}
