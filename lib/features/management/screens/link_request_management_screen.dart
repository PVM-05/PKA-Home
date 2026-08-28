import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../core/theme/app_theme.dart';
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
          icon: const Icon(FluentIcons.chevron_left_24_regular),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: requestsState.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.checkmark_circle_48_regular, size: 64, color: AppTheme.success),
                  SizedBox(height: 16),
                  Text('Không có yêu cầu nào đang chờ duyệt', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

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
                              borderRadius: BorderRadius.circular(4),
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
                          const Icon(FluentIcons.building_home_16_regular, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text('Căn hộ: ${apartment['code']}', style: const TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(FluentIcons.dismiss_24_regular, color: AppTheme.error),
                            label: const Text('Từ chối', style: TextStyle(color: AppTheme.error)),
                            onPressed: () => _handleReject(context, ref, req['id']),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(FluentIcons.checkmark_24_regular),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: AppTheme.error))),
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
