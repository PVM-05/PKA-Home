import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../data/models/resident_activation_model.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/resident_activation_provider.dart';
import '../../../data/repositories/building_repository.dart';

class ResidentActivationManagementSheet extends ConsumerStatefulWidget {
  const ResidentActivationManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ResidentActivationManagementSheet(),
    );
  }

  @override
  ConsumerState<ResidentActivationManagementSheet> createState() =>
      _ResidentActivationManagementSheetState();
}

class _ResidentActivationManagementSheetState
    extends ConsumerState<ResidentActivationManagementSheet> {
  String _searchQuery = '';
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final activeBuilding = ref.watch(activeBuildingProvider).value;
    final buildingId =
        activeBuilding?.id ?? BuildingRepository.kDefaultCanonicalBuildingId;
    final activationsAsync =
        ref.watch(buildingActivationListProvider(buildingId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mã Kích Hoạt & Thư Mời Cư Dân',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Phát hành mã bàn giao căn hộ cho cư dân mới',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Nội dung danh sách
              Expanded(
                child: activationsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Lỗi khi tải danh sách: $e',
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ),
                  data: (activations) {
                    final filtered = activations.where((a) {
                      if (_searchQuery.isEmpty) return true;
                      final query = _searchQuery.toLowerCase();
                      return a.apartmentCode.toLowerCase().contains(query) ||
                          a.fullName.toLowerCase().contains(query) ||
                          a.phone.contains(query) ||
                          a.activationCode.toLowerCase().contains(query);
                    }).toList();

                    final activatedCount =
                        activations.where((a) => a.isActive).length;
                    final pendingCount =
                        activations.where((a) => !a.isActive).length;

                    return Column(
                      children: [
                        // Hộp công cụ & Thống kê
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            children: [
                              // Thống kê nhanh 2 cột
                              Row(
                                children: [
                                  _buildStatCard(
                                    'Đã kích hoạt',
                                    '$activatedCount',
                                    AppTheme.success,
                                    Icons.verified,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatCard(
                                    'Chưa kích hoạt',
                                    '$pendingCount',
                                    Colors.orange,
                                    Icons.pending_actions,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Thanh tìm kiếm
                              TextField(
                                decoration: InputDecoration(
                                  hintText:
                                      'Tìm theo căn hộ, họ tên, SĐT, mã...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() => _searchQuery = val.trim());
                                },
                              ),
                              const SizedBox(height: 12),

                              // Nút hành động BQL
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      icon: _isGenerating
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.auto_fix_high, size: 18),
                                      label: const Text(
                                        'Tạo mã cho cư dân mới',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: _isGenerating
                                          ? null
                                          : () => _handleGenerateCodes(buildingId),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    icon: const Icon(Icons.file_download_outlined, size: 18),
                                    label: const Text(
                                      'Xuất CSV',
                                      style: TextStyle(fontSize: 12.5),
                                    ),
                                    onPressed: () =>
                                        _exportActivationListCsv(activations),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Danh sách hiển thị
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Không có cư dân nào phù hợp tìm kiếm',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 16),
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    return _buildActivationTile(item);
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String count,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivationTile(ResidentActivationModel item) {
    final hasCode = item.activationCode.isNotEmpty;
    final isActivated = item.isActive;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mã căn hộ badge
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            item.apartmentCode,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Thông tin cư dân
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActivated
                          ? AppTheme.success.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.statusText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isActivated ? AppTheme.success : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'SĐT: ${item.phone} • ${item.relationRoleText}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (hasCode && !isActivated) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.key, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        item.activationCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Action Buttons
        if (hasCode && !isActivated)
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: AppTheme.primary),
            tooltip: 'Sao chép mã',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: item.activationCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã sao chép mã ${item.activationCode}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _handleGenerateCodes(String buildingId) async {
    setState(() => _isGenerating = true);
    final repo = ref.read(residentActivationRepositoryProvider);

    try {
      final res = await repo.generateActivationCodes(buildingId: buildingId);
      ref.invalidate(buildingActivationListProvider(buildingId));

      if (mounted) {
        setState(() => _isGenerating = false);
        final msg = res['message']?.toString() ?? 'Đã hoàn tất sinh mã';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi sinh mã kích hoạt: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _exportActivationListCsv(
    List<ResidentActivationModel> list,
  ) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(
        '\uFEFFCăn Hộ,Họ Và Tên,Số Điện Thoại,Vai Trò,Mã Kích Hoạt,Trạng Thái',
      );

      for (final a in list) {
        buffer.writeln(
          '${a.apartmentCode},"${a.fullName}",${a.phone},${a.relationRoleText},${a.activationCode},${a.statusText}',
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final date = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/Danh_Sach_Ma_Kich_Hoat_$date.csv';

      final file = File(filePath);
      await file.writeAsBytes(utf8.encode(buffer.toString()));

      await ExcelExportHelper.shareFile(
        filePath,
        subject: 'Danh sách mã kích hoạt cư dân',
        text: 'File CSV danh sách mã kích hoạt căn hộ phục vụ bàn giao',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất file CSV: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
