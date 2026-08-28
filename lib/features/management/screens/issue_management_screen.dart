import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/issue_model.dart';

class IssueManagementScreen extends ConsumerStatefulWidget {
  const IssueManagementScreen({super.key});

  @override
  ConsumerState<IssueManagementScreen> createState() => _IssueManagementScreenState();
}

class _IssueManagementScreenState extends ConsumerState<IssueManagementScreen> {
  String _selectedStatus = 'pending'; // pending, in_progress, resolved

  void _updateStatus(IssueModel issue, String newStatus) async {
    try {
      await ref.read(managementRepositoryProvider).updateIssueStatus(issue.id, newStatus);
      // Dữ liệu sẽ tự động nhảy nhờ Stream Realtime Provider
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật trạng thái thành công'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(allIssuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xử lý Phản ánh'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('pending', 'Chờ xử lý', AppTheme.warning),
                const SizedBox(width: 8),
                _buildFilterChip('in_progress', 'Đang xử lý', AppTheme.primary),
                const SizedBox(width: 8),
                _buildFilterChip('resolved', 'Đã hoàn thành', AppTheme.success),
              ],
            ),
          ),
          
          Expanded(
            child: issuesAsync.when(
              data: (issues) {
                final filtered = issues.where((issue) => issue.status == _selectedStatus).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.chat_warning_24_regular, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Không có phản ánh nào.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allIssuesProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final issue = filtered[index];
                      final isHighPriority = issue.priority == 'high';
                      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                      
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isHighPriority ? AppTheme.error.withOpacity(0.5) : Colors.transparent,
                            width: isHighPriority ? 2 : 0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      if (isHighPriority)
                                        const Icon(FluentIcons.warning_24_filled, color: AppTheme.error, size: 20)
                                      else
                                        const Icon(FluentIcons.info_24_regular, color: AppTheme.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Căn hộ ${issue.apartment?.code ?? 'N/A'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 16,
                                          color: isHighPriority ? AppTheme.error : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    dateFormat.format(issue.createdAt),
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(issue.description, style: Theme.of(context).textTheme.bodyMedium),
                              
                              if (issue.reporter != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Người gửi: ${issue.reporter!.fullName}', 
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                              
                              const SizedBox(height: 16),
                              
                              if (issue.status == 'pending')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _updateStatus(issue, 'in_progress'),
                                    child: const Text('Tiếp nhận & Xử lý'),
                                  ),
                                )
                              else if (issue.status == 'in_progress')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _updateStatus(issue, 'resolved'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                                    child: const Text('Đánh dấu Hoàn thành'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label, Color color) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = status);
        }
      },
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppTheme.surface,
      side: BorderSide(
        color: isSelected ? color : const Color(0xFFE0E0E0),
      ),
    );
  }
}
