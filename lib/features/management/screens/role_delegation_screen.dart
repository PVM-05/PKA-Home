import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/role_delegation_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/role_delegation_provider.dart';

class RoleDelegationScreen extends ConsumerStatefulWidget {
  const RoleDelegationScreen({super.key});

  @override
  ConsumerState<RoleDelegationScreen> createState() =>
      _RoleDelegationScreenState();
}

class _RoleDelegationScreenState extends ConsumerState<RoleDelegationScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  void _showCreateDelegationDialog(BuildContext context) async {
    final residents = await ref.read(residentsProvider.future);
    // P0-#14: Chỉ cho phép ủy quyền cho nhân sự nội bộ thuộc BQL (kế toán, kỹ thuật viên, lễ tân, an ninh...)
    // Tuyệt đối không cho phép ủy quyền chức năng BQL cho cư dân (resident, tenant...)
    const allowedStaffRoles = {'accountant', 'technician', 'receptionist', 'security', 'staff'};
    final eligibleUsers = residents
        .where((r) => allowedStaffRoles.contains(r.role))
        .toList();

    if (!context.mounted) return;

    if (eligibleUsers.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Không có nhân sự BQL phù hợp để ủy quyền. Vui lòng tạo tài khoản nhân viên (Kế toán, Kỹ thuật viên...) trước.',
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => _CreateDelegationSheet(eligibleUsers: eligibleUsers),
    );
  }

  void _confirmRevoke(RoleDelegationModel delegation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi ủy quyền?'),
        content: Text(
          'Bạn có chắc chắn muốn kết thúc sớm quyền "${delegation.roleDisplayName}" của ${delegation.delegateName ?? "nhân viên này"} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await runAction(
                context,
                () async {
                  await ref
                      .read(managementRepositoryProvider)
                      .revokeDelegation(delegation.id);
                  ref.invalidate(delegationsListProvider);
                  return 'Đã thu hồi ủy quyền thành công!';
                },
                actionName: 'Thu hồi ủy quyền',
              );
            },
            child: const Text('Thu hồi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final delegationsAsync = ref.watch(delegationsListProvider);

    return RoleGuard(
      permission: AppPermissions.roleDelegation,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản Lý Ủy Quyền'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: AppStateView<List<RoleDelegationModel>>(
          asyncValue: delegationsAsync,
          emptyMessage: 'Chưa có lịch sử ủy quyền vai trò nào.',
          emptyIcon: Icons.admin_panel_settings_outlined,
          onRetry: () => ref.invalidate(delegationsListProvider),
          dataBuilder: (delegations) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(delegationsListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: delegations.length,
                    itemBuilder: (context, index) {
                      final item = delegations[index];
                      final isActive = item.isActive;

                      Color statusColor = Colors.grey;
                      String statusText = 'Đã kết thúc';
                      if (isActive) {
                        statusColor = AppTheme.success;
                        statusText = 'Đang hiệu lực';
                      } else if (item.isUpcoming) {
                        statusColor = Colors.orange;
                        statusText = 'Sắp diễn ra';
                      }

                      final roleColor = item.delegatedRole == 'accountant'
                          ? Colors.purple
                          : Colors.orange;

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          item.roleDisplayName,
                                          style: context.labelSmall?.copyWith(
                                            color: roleColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          statusText,
                                          style: context.labelSmall?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isActive)
                                  TextButton(
                                    onPressed: () => _confirmRevoke(item),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.error,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                    ),
                                    child: const Text('Thu hồi'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Người nhận: ${item.delegateName ?? "N/A"}',
                              style: context.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Người ủy quyền: ${item.delegatorName ?? "Quản trị viên"}',
                              style: context.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${_dateFormat.format(item.startsAt)} -> ${_dateFormat.format(item.endsAt)}',
                                    style: context.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                            if (item.note != null && item.note!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Lý do: ${item.note}',
                                  style: context.labelSmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
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
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'create_delegation_fab',
          onPressed: () => _showCreateDelegationDialog(context),
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Thêm ủy quyền',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _CreateDelegationSheet extends ConsumerStatefulWidget {
  final List<ResidentModel> eligibleUsers;

  const _CreateDelegationSheet({required this.eligibleUsers});

  @override
  ConsumerState<_CreateDelegationSheet> createState() => _CreateDelegationSheetState();
}

class _CreateDelegationSheetState extends ConsumerState<_CreateDelegationSheet> {
  late String _selectedUserId;
  String _selectedRole = 'accountant';
  DateTime _startsAt = DateTime.now();
  DateTime _endsAt = DateTime.now().add(const Duration(days: 3));
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.eligibleUsers.first.id;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tạo Ủy Quyền Vai Trò BQL',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Chọn nhân sự
            const Text(
              'Nhân sự nhận ủy quyền *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedUserId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: widget.eligibleUsers.map((u) {
                return DropdownMenuItem(
                  value: u.id,
                  child: Text('${u.fullName} (${u.roleDisplayName})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedUserId = val);
              },
            ),
            const SizedBox(height: 16),

            // Chọn vai trò tạm thời
            const Text(
              'Vai trò ủy quyền tạm thời *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'accountant',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.purple, size: 18),
                      SizedBox(width: 8),
                      Text('Kế toán (Quản lý hóa đơn & Sổ cái)'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'technician',
                  child: Row(
                    children: [
                      Icon(Icons.build_circle, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text('Kỹ thuật viên (Sự cố & Bàn giao)'),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 16),

            // Thời hạn ủy quyền
            const Text(
              'Thời hạn ủy quyền *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
              title: Text(
                '${DateFormat('dd/MM/yyyy').format(_startsAt)} - ${DateFormat('dd/MM/yyyy').format(_endsAt)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Bấm để chọn khoảng ngày'),
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: DateTimeRange(start: _startsAt, end: _endsAt),
                );
                if (picked != null) {
                  setState(() {
                    _startsAt = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0);
                    _endsAt = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Ghi chú
            const Text(
              'Lý do / Căn cứ ủy quyền',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'VD: Thay thế nhân sự nghỉ phép, hỗ trợ đột xuất...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Nút xác nhận
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await runAction(
                    context,
                    () async {
                      await ref.read(managementRepositoryProvider).createDelegation(
                            delegateId: _selectedUserId,
                            delegatedRole: _selectedRole,
                            startsAt: _startsAt,
                            endsAt: _endsAt,
                            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                          );
                      ref.invalidate(delegationsListProvider);
                      return 'Tạo ủy quyền vai trò thành công!';
                    },
                    actionName: 'Tạo ủy quyền vai trò',
                  );
                },
                child: const Text(
                  'XÁC NHẬN ỦY QUYỀN',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
