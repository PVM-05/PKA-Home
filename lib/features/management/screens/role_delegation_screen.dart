import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/role_delegation_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/role_delegation_provider.dart';

class RoleDelegationScreen extends ConsumerStatefulWidget {
  const RoleDelegationScreen({super.key});

  @override
  ConsumerState<RoleDelegationScreen> createState() => _RoleDelegationScreenState();
}

class _RoleDelegationScreenState extends ConsumerState<RoleDelegationScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  void _showCreateDelegationDialog(BuildContext context) async {
    final residents = await ref.read(residentsProvider.future);
    // Chỉ cho phép ủy quyền cho các nhân viên hoặc cư dân (trừ các tài khoản đã là admin)
    final eligibleUsers = residents.where((r) => r.role != 'admin' && r.role != 'management').toList();

    if (!context.mounted) return;

    if (eligibleUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có nhân sự phù hợp để ủy quyền.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    String selectedUserId = eligibleUsers.first.id;
    String selectedRole = 'accountant';
    DateTime startsAt = DateTime.now();
    DateTime endsAt = DateTime.now().add(const Duration(days: 3));
    final noteController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                          'Tạo Ủy Quyền Vai Trò',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Chọn nhân sự
                    const Text('Nhân sự nhận ủy quyền *', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUserId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: eligibleUsers.map((u) {
                        return DropdownMenuItem(
                          value: u.id,
                          child: Text('${u.fullName} (${u.roleDisplayName})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedUserId = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Chọn vai trò tạm thời
                    const Text('Vai trò ủy quyền tạm thời *', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
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
                              Text('Kế toán (Quản lý hóa đơn)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'technician',
                          child: Row(
                            children: [
                              Icon(Icons.build_circle, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text('Kỹ thuật viên (Xử lý sự cố)'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Thời hạn ủy quyền
                    const Text('Thời hạn ủy quyền *', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
                      title: Text(
                        '${DateFormat('dd/MM/yyyy').format(startsAt)} - ${DateFormat('dd/MM/yyyy').format(endsAt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Bấm để chọn khoảng ngày'),
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: DateTimeRange(start: startsAt, end: endsAt),
                        );
                        if (picked != null) {
                          setModalState(() {
                            startsAt = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0);
                            endsAt = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ghi chú
                    const Text('Lý do / Ghi chú ủy quyền', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        hintText: 'VD: Kế toán nghỉ phép 3 ngày...',
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
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  await ref.read(managementRepositoryProvider).createDelegation(
                                        delegateId: selectedUserId,
                                        delegatedRole: selectedRole,
                                        startsAt: startsAt,
                                        endsAt: endsAt,
                                        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                      );
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  ref.invalidate(delegationsListProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Tạo ủy quyền vai trò thành công!'),
                                        backgroundColor: AppTheme.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(formatErrorMessage(e)),
                                        backgroundColor: AppTheme.error,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'XÁC NHẬN ỦY QUYỀN',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
              try {
                await ref.read(managementRepositoryProvider).revokeDelegation(delegation.id);
                ref.invalidate(delegationsListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã thu hồi ủy quyền thành công!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(formatErrorMessage(e)),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
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
            return RefreshIndicator(
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

                  final roleColor = item.delegatedRole == 'accountant' ? Colors.purple : Colors.orange;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isActive ? statusColor.withValues(alpha: 0.5) : Colors.grey.shade300,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.roleDisplayName,
                                      style: TextStyle(
                                        color: roleColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Người ủy quyền: ${item.delegatorName ?? "Quản trị viên"}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_dateFormat.format(item.startsAt)} -> ${_dateFormat.format(item.endsAt)}',
                                  style: const TextStyle(fontSize: 13),
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
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
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
