import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/supabase_config.dart';
import '../../../data/providers/auth_provider.dart';
import '../widgets/technician_performance_card.dart';

class AuditLogItem {
  final String title;
  final String subtitle;
  final DateTime updatedAt;
  final IconData icon;
  final Color color;
  final String category; // 'invoice', 'issue', 'link', 'rbac'
  final String? changedBy;
  final String? performerName;

  AuditLogItem({
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    required this.icon,
    required this.color,
    required this.category,
    this.changedBy,
    this.performerName,
  });
}

final auditTrailProvider = FutureProvider.autoDispose<List<AuditLogItem>>((ref) async {
  final client = SupabaseConfig.client;
  List<AuditLogItem> logs = [];

  // 1. Fetch Invoices
  try {
    final invoicesRes = await client
        .from('invoices')
        .select('id, period, status, updated_at, created_at, apartments(code)')
        .order('updated_at', ascending: false)
        .limit(10);

    for (var row in (invoicesRes as List)) {
      final apt = (row['apartments'] as Map?)?['code'] ?? 'N/A';
      final rawDate = row['updated_at'] ?? row['created_at'];
      if (rawDate == null) continue;

      String action = 'Cập nhật hóa đơn';
      Color c = AppTheme.primary;
      if (row['status'] == 'paid') {
        action = 'Đã thu tiền hóa đơn';
        c = AppStatusColors.paid;
      } else if (row['status'] == 'pending_confirmation') {
        action = 'Cư dân báo đã thanh toán';
        c = AppStatusColors.pendingConfirmation;
      } else if (row['status'] == 'unpaid') {
        action = 'Hóa đơn chưa thanh toán';
        c = AppStatusColors.unpaid;
      }

      logs.add(AuditLogItem(
        title: '$action (Kỳ ${row['period']})',
        subtitle: 'Căn hộ: $apt',
        updatedAt: DateTime.parse(rawDate).toLocal(),
        icon: Icons.receipt_long_outlined,
        color: c,
        category: 'invoice',
      ));
    }
  } catch (_) {}

  // 2. Fetch Issues
  try {
    final issuesRes = await client
        .from('issue_reports')
        .select('id, description, status, updated_at, created_at, assigned_staff_id, reporter_id, apartments(code)')
        .order('updated_at', ascending: false)
        .limit(10);

    for (var row in (issuesRes as List)) {
      final apt = (row['apartments'] as Map?)?['code'] ?? 'N/A';
      final rawDate = row['updated_at'] ?? row['created_at'];
      if (rawDate == null) continue;

      String action = 'Cập nhật phản ánh';
      Color c = AppTheme.primary;
      if (row['status'] == 'resolved') {
        action = 'Đã hoàn thành xử lý sự cố';
        c = AppStatusColors.paid;
      } else if (row['status'] == 'in_progress') {
        action = 'Bắt đầu xử lý sự cố';
        c = AppStatusColors.pendingConfirmation;
      } else if (row['status'] == 'pending') {
        action = 'Có phản ánh sự cố mới';
        c = AppStatusColors.priorityHigh;
      }

      logs.add(AuditLogItem(
        title: action,
        subtitle: 'Căn hộ: $apt - ${row['description']}',
        updatedAt: DateTime.parse(rawDate).toLocal(),
        icon: Icons.report_problem_outlined,
        color: c,
        category: 'issue',
        changedBy: row['assigned_staff_id'] as String?,
      ));
    }
  } catch (_) {}

  // 3. Fetch Link Requests
  try {
    final linksRes = await client
        .from('apartment_link_requests')
        .select('id, status, updated_at, created_at, user_id, apartments(code), users(full_name)')
        .order('updated_at', ascending: false)
        .limit(10);

    for (var row in (linksRes as List)) {
      final apt = (row['apartments'] as Map?)?['code'] ?? 'N/A';
      final name = (row['users'] as Map?)?['full_name'] ?? 'Cư dân';
      final rawDate = row['updated_at'] ?? row['created_at'];
      if (rawDate == null) continue;

      String action = 'Yêu cầu liên kết';
      Color c = AppStatusColors.pending;
      if (row['status'] == 'approved') {
        action = 'Đã duyệt liên kết căn hộ';
        c = AppStatusColors.paid;
      } else if (row['status'] == 'rejected') {
        action = 'Đã từ chối liên kết';
        c = AppStatusColors.rejected;
      } else if (row['status'] == 'pending') {
        action = 'Yêu cầu liên kết mới';
        c = AppStatusColors.pending;
      }

      logs.add(AuditLogItem(
        title: action,
        subtitle: 'Cư dân $name -> Căn hộ $apt',
        updatedAt: DateTime.parse(rawDate).toLocal(),
        icon: Icons.person_add_outlined,
        color: c,
        category: 'link',
        changedBy: row['user_id'] as String?,
      ));
    }
  } catch (_) {}

  // 4. Fetch Role Change Logs
  try {
    final roleLogsRes = await client
        .from('role_change_log')
        .select('id, old_role, new_role, changed_by, changed_at, target:target_user_id(full_name), changer:changed_by(full_name)')
        .order('changed_at', ascending: false)
        .limit(10);

    for (var row in (roleLogsRes as List)) {
      final targetName = (row['target'] as Map?)?['full_name'] ?? 'Người dùng';
      final changerName = (row['changer'] as Map?)?['full_name'] ?? 'Quản trị viên';
      final oldRole = row['old_role'];
      final newRole = row['new_role'];

      logs.add(AuditLogItem(
        title: 'Đổi vai trò: $targetName',
        subtitle: '$oldRole ➔ $newRole (Bởi $changerName)',
        updatedAt: DateTime.parse(row['changed_at']).toLocal(),
        icon: Icons.admin_panel_settings_outlined,
        color: AppTheme.primary,
        category: 'rbac',
        changedBy: row['changed_by'] as String?,
        performerName: changerName,
      ));
    }
  } catch (_) {}

  // 5. Fetch Role Delegations
  try {
    final delegationRes = await client
        .from('role_delegations')
        .select('id, delegated_role, starts_at, ends_at, delegator_id, delegate_id, created_at, delegator:delegator_id(full_name), delegate:delegate_id(full_name)')
        .order('created_at', ascending: false)
        .limit(10);

    for (var row in (delegationRes as List)) {
      final delegatorName = (row['delegator'] as Map?)?['full_name'] ?? 'Quản trị viên';
      final delegateName = (row['delegate'] as Map?)?['full_name'] ?? 'Nhân sự';
      final role = row['delegated_role'] == 'accountant' ? 'Kế toán' : 'Kỹ thuật viên';

      logs.add(AuditLogItem(
        title: 'Ủy quyền tạm thời: $role',
        subtitle: '$delegatorName ➔ $delegateName',
        updatedAt: DateTime.parse(row['created_at']).toLocal(),
        icon: Icons.vpn_key_outlined,
        color: Colors.purple,
        category: 'rbac',
        changedBy: row['delegator_id'] as String?,
        performerName: delegatorName,
      ));
    }
  } catch (_) {}

  // Sắp xếp theo thời gian mới nhất
  logs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return logs.take(30).toList();
});

class AuditTrailScreen extends ConsumerStatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  ConsumerState<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends ConsumerState<AuditTrailScreen> {
  String _selectedCategory = 'all'; // all, invoice, issue, link, rbac
  bool _onlyMyActions = false;

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(auditTrailProvider);
    final currentUser = ref.watch(authProvider).valueOrNull;
    final isAdmin = currentUser?.isAdmin ?? false;
    timeago.setLocaleMessages('vi', timeago.ViMessages());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Hoạt động'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả'),
                const SizedBox(width: 8),
                _buildFilterChip('invoice', 'Hóa đơn'),
                const SizedBox(width: 8),
                _buildFilterChip('issue', 'Sự cố'),
                const SizedBox(width: 8),
                _buildFilterChip('link', 'Liên kết'),
                const SizedBox(width: 8),
                _buildFilterChip('rbac', 'Phân quyền'),
                const SizedBox(width: 12),
                FilterChip(
                  selected: _onlyMyActions,
                  avatar: Icon(
                    Icons.person,
                    size: 16,
                    color: _onlyMyActions ? Colors.white : AppTheme.primary,
                  ),
                  label: const Text('Của tôi'),
                  labelStyle: TextStyle(
                    color: _onlyMyActions ? Colors.white : AppTheme.textPrimary,
                    fontWeight: _onlyMyActions ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: AppTheme.primary,
                  onSelected: (selected) {
                    setState(() => _onlyMyActions = selected);
                  },
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: AppStateView<List<AuditLogItem>>(
              asyncValue: auditAsync,
              emptyMessage: 'Chưa có hoạt động nào phù hợp.',
              emptyIcon: Icons.history,
              onRetry: () => ref.invalidate(auditTrailProvider),
              dataBuilder: (rawLogs) {
                // Áp dụng bộ lọc
                var filtered = rawLogs;
                if (_selectedCategory != 'all') {
                  filtered = filtered.where((l) => l.category == _selectedCategory).toList();
                }
                if (_onlyMyActions && currentUser != null) {
                  filtered = filtered.where((l) => l.changedBy == currentUser.id).toList();
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Không tìm thấy hoạt động nào phù hợp bộ lọc.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: (isAdmin ? 1 : 0) + filtered.length,
                  itemBuilder: (context, index) {
                    // Thẻ hiệu suất KTV hiển thị ở vị trí đầu tiên cho Admin
                    if (isAdmin && index == 0) {
                      return const TechnicianPerformanceCard();
                    }

                    final logIndex = isAdmin ? index - 1 : index;
                    final log = filtered[logIndex];
                    final relativeTime = timeago.format(log.updatedAt, locale: 'vi');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline indicator
                          Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: log.color.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(log.icon, color: log.color, size: 20),
                              ),
                              if (logIndex < filtered.length - 1)
                                Container(
                                  width: 2,
                                  height: 40,
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  log.subtitle,
                                  style: const TextStyle(color: AppTheme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  relativeTime,
                                  style: TextStyle(fontSize: 12, color: log.color),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primary,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedCategory = category);
        }
      },
    );
  }
}
