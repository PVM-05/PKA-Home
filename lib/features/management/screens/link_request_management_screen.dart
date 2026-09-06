import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../data/providers/link_request_management_provider.dart';

class LinkRequestManagementScreen extends ConsumerWidget {
  const LinkRequestManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsState = ref.watch(linkRequestManagementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt yêu cầu liên kết'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AppStateView<List<Map<String, dynamic>>>(
        asyncValue: requestsState,
        emptyMessage: 'Không có yêu cầu nào đang chờ duyệt',
        emptyIcon: Icons.check_circle_outline,
        onRetry: () => ref.invalidate(linkRequestManagementProvider),
        dataBuilder: (requests) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final user = req['users'];
              final apartment = req['apartments'];
              final roleLabel = req['requested_relation_role'] == 'owner' ? 'Chủ hộ' : 'Khách thuê';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            user['full_name'] ?? 'Cư dân',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              roleLabel,
                              style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.apartment_outlined, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Căn hộ: ${apartment['code']}', style: const TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.close, color: AppTheme.error),
                            label: const Text('Từ chối', style: TextStyle(color: AppTheme.error)),
                            onPressed: () => _handleReject(context, ref, req['id']),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Phê duyệt'),
                            onPressed: () => _handleApprove(context, ref, req['id']),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleApprove(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(linkRequestManagementProvider.notifier).approveRequest(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã duyệt yêu cầu'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _handleReject(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(linkRequestManagementProvider.notifier).rejectRequest(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã từ chối yêu cầu')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
}
