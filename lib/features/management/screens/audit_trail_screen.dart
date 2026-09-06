import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/supabase_config.dart';

class AuditLogItem {
  final String title;
  final String subtitle;
  final DateTime updatedAt;
  final IconData icon;
  final Color color;

  AuditLogItem({
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    required this.icon,
    required this.color,
  });
}

final auditTrailProvider = FutureProvider.autoDispose<List<AuditLogItem>>((ref) async {
  final client = SupabaseConfig.client;
  
  // 1. Fetch Invoices
  final invoicesRes = await client
      .from('invoices')
      .select('id, period, status, updated_at, created_at, apartments(code)')
      .order('updated_at', ascending: false)
      .limit(10);
      
  // 2. Fetch Issues
  final issuesRes = await client
      .from('issue_reports')
      .select('id, description, status, updated_at, created_at, apartments(code)')
      .order('updated_at', ascending: false)
      .limit(10);
      
  // 3. Fetch Link Requests
  final linksRes = await client
      .from('apartment_link_requests')
      .select('id, status, updated_at, created_at, apartments(code), users(full_name)')
      .order('updated_at', ascending: false)
      .limit(10);

  List<AuditLogItem> logs = [];

  // Parse Invoices
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
    ));
  }

  // Parse Issues
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
    ));
  }

  // Parse Link Requests
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
    ));
  }

  // Sort by updatedAt descending
  logs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  
  // Return top 20
  return logs.take(20).toList();
});


class AuditTrailScreen extends ConsumerWidget {
  const AuditTrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditTrailProvider);
    timeago.setLocaleMessages('vi', timeago.ViMessages());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Hoạt động'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AppStateView<List<AuditLogItem>>(
        asyncValue: auditAsync,
        emptyMessage: 'Chưa có hoạt động nào.',
        emptyIcon: Icons.history,
        onRetry: () => ref.invalidate(auditTrailProvider),
        dataBuilder: (logs) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
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
                        if (index < logs.length - 1)
                          Container(
                            width: 2,
                            height: 40,
                            color: Colors.grey.withValues(alpha: 0.2),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          )
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
    );
  }
}
