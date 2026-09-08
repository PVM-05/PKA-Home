import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/issue_model.dart';

class IssueManagementScreen extends ConsumerStatefulWidget {
  const IssueManagementScreen({super.key});

  @override
  ConsumerState<IssueManagementScreen> createState() => _IssueManagementScreenState();
}

class _IssueManagementScreenState extends ConsumerState<IssueManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all'; // all, pending, in_progress, resolved

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo căn hộ hoặc mô tả sự cố...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),

          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả', AppTheme.primary),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Chờ xử lý', AppStatusColors.pending),
                const SizedBox(width: 8),
                _buildFilterChip('in_progress', 'Đang xử lý', AppTheme.primary),
                const SizedBox(width: 8),
                _buildFilterChip('resolved', 'Đã hoàn thành', AppStatusColors.paid),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: AppStateView<List<IssueModel>>(
              asyncValue: issuesAsync,
              emptyMessage: 'Không có phản ánh nào.',
              emptyIcon: Icons.report_problem_outlined,
              onRetry: () => ref.invalidate(allIssuesProvider),
              dataBuilder: (issues) {
                final filtered = issues.where((issue) {
                  if (_selectedStatus != 'all' && issue.status != _selectedStatus) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final code = (issue.apartment?.code ?? '').toLowerCase();
                    final desc = issue.description.toLowerCase();
                    final q = _searchQuery.toLowerCase();
                    if (!code.contains(q) && !desc.contains(q)) return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report_problem_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Không có phản ánh nào ở trạng thái này.',
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
                      final isMediumPriority = issue.priority == 'medium';
                      final priorityColor = isHighPriority 
                          ? AppStatusColors.priorityHigh 
                          : (isMediumPriority ? AppStatusColors.priorityMedium : AppStatusColors.priorityLow);
                          
                      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                      final isNew = DateTime.now().difference(issue.createdAt).inMinutes < 15;
                      
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isHighPriority ? AppStatusColors.priorityHigh.withValues(alpha: 0.5) : Colors.transparent,
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
                                      Icon(
                                        isHighPriority ? Icons.warning : Icons.info_outline, 
                                        color: priorityColor, 
                                        size: 20
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Căn hộ ${issue.apartment?.code ?? 'N/A'}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 16,
                                          color: isHighPriority ? AppStatusColors.priorityHigh : AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (isNew) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppStatusColors.paid,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('MỚI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                      ]
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
                              
                              if (issue.imageUrls.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    issue.imageUrls.first,
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                              
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
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppTheme.surface,
      side: BorderSide(
        color: isSelected ? color : AppTheme.border,
      ),
    );
  }
}
