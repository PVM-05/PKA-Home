import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
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
        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
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
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.key_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mã Kích Hoạt & Thư Mời Cư Dân',
                            style: context.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Phát hành mã bàn giao căn hộ cho cư dân mới',
                            style: context.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.maybePop(context),
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
                        formatErrorMessage(e),
                        style: TextStyle(color: colorScheme.error),
                        textAlign: TextAlign.center,
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
                    final pendingCount = activations
                        .where((a) =>
                            !a.isActive &&
                            a.activationCode.isNotEmpty &&
                            !a.isLocked &&
                            !a.isRevoked)
                        .length;
                    final unassignedCount = activations
                        .where((a) => !a.isActive && a.activationCode.isEmpty)
                        .length;
                    final lockedOrRevokedCount = activations
                        .where((a) => a.isLocked || a.isRevoked)
                        .length;

                    return Column(
                      children: [
                        // Hộp công cụ & Thống kê
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            children: [
                              // Thống kê nhanh tự động xuống dòng trên màn hình hẹp
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatCard(
                                    'Đã kích hoạt',
                                    '$activatedCount',
                                    AppTheme.getSemanticSuccess(context),
                                    Icons.verified,
                                  ),
                                  _buildStatCard(
                                    'Chờ kích hoạt',
                                    '$pendingCount',
                                    AppTheme.getSemanticWarning(context),
                                    Icons.pending_actions,
                                  ),
                                  _buildStatCard(
                                    'Chưa cấp mã',
                                    '$unassignedCount',
                                    colorScheme.primary,
                                    Icons.person_add_outlined,
                                  ),
                                  if (lockedOrRevokedCount > 0)
                                    _buildStatCard(
                                      'Khóa/Thu hồi',
                                      '$lockedOrRevokedCount',
                                      colorScheme.error,
                                      Icons.lock_person_outlined,
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
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
                                    label: Text(
                                      'Tạo mã cho cư dân mới',
                                      style: context.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onPressed: _isGenerating
                                        ? null
                                        : () => _handleGenerateCodes(buildingId),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    icon: const Icon(Icons.file_download_outlined, size: 18),
                                    label: Text(
                                      'Xuất CSV',
                                      style: context.bodyMedium,
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
                              ? Center(
                                  child: Text(
                                    'Không có cư dân nào phù hợp tìm kiếm',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
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
                                    return _buildActivationTile(item, buildingId);
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
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: context.labelSmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivationTile(ResidentActivationModel item, String buildingId) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCode = item.activationCode.isNotEmpty;
    final isActivated = item.isActive;

    Color statusBgColor = colorScheme.primary.withValues(alpha: 0.12);
    Color statusTextColor = colorScheme.primary;

    if (item.isLocked) {
      statusBgColor = colorScheme.error.withValues(alpha: 0.12);
      statusTextColor = colorScheme.error;
    } else if (item.isRevoked) {
      statusBgColor = colorScheme.surfaceContainerHighest;
      statusTextColor = colorScheme.onSurfaceVariant;
    } else if (isActivated) {
      statusBgColor = AppTheme.getSemanticSuccess(context).withValues(alpha: 0.12);
      statusTextColor = AppTheme.getSemanticSuccess(context);
    } else if (item.status == 'otp_sent' || hasCode) {
      statusBgColor = AppTheme.getSemanticWarning(context).withValues(alpha: 0.14);
      statusTextColor = AppTheme.getSemanticWarning(context);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mã căn hộ badge
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            item.apartmentCode,
            style: context.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
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
                      style: context.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.statusText,
                      style: context.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'SĐT: ${item.phone} • ${item.relationRoleText}',
                style: context.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (hasCode && !isActivated && !item.isRevoked) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.isLocked
                        ? colorScheme.error.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.isLocked
                          ? colorScheme.error.withValues(alpha: 0.35)
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isLocked ? Icons.lock : Icons.key,
                        size: 14,
                        color: item.isLocked ? colorScheme.error : colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.activationCode,
                        style: context.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: item.isLocked ? colorScheme.error : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Action Buttons Menu
        if (!isActivated) ...[
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
            tooltip: 'Tùy chọn thao tác',
            onSelected: (val) {
              if (val == 'copy_message') {
                _copyInviteMessage(item);
              } else if (val == 'regenerate') {
                _confirmRegenerate(item, buildingId);
              } else if (val == 'revoke') {
                _confirmRevoke(item, buildingId);
              }
            },
            itemBuilder: (ctx) => [
              if (hasCode && !item.isRevoked)
                const PopupMenuItem(
                  value: 'copy_message',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 16, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Sao chép thư mời Zalo/SMS'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'regenerate',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Cấp lại mã mới'),
                  ],
                ),
              ),
              if (hasCode && !item.isRevoked)
                const PopupMenuItem(
                  value: 'revoke',
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 16, color: AppTheme.error),
                      SizedBox(width: 8),
                      Text('Thu hồi mã'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _copyInviteMessage(ResidentActivationModel item) {
    final inviteMsg =
        '[Vivona] Ban Quản Lý trân trọng gửi mã kích hoạt tài khoản căn hộ ${item.apartmentCode} cho cư dân ${item.fullName}:\n'
        '• Số điện thoại: ${item.phone}\n'
        '• Mã kích hoạt: ${item.activationCode}\n'
        'Vui lòng tải ứng dụng Vivona và chọn "Kích hoạt tài khoản lần đầu" để đăng nhập và nhận thông báo từ tòa nhà.';

    Clipboard.setData(ClipboardData(text: inviteMsg));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép thư mời kích hoạt cho cư dân ${item.fullName}'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmRegenerate(ResidentActivationModel item, String buildingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cấp lại mã kích hoạt'),
        content: Text(
          'Hệ thống sẽ hủy mã cũ và cấp mã mới cho cư dân "${item.fullName}" (Căn hộ ${item.apartmentCode}). Bạn có chắc chắn muốn thực hiện?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await ref
                    .read(residentActivationRepositoryProvider)
                    .regenerateActivationCode(userId: item.userId);
                ref.invalidate(buildingActivationListProvider(buildingId));

                if (mounted) {
                  final newCode = res['activation_code'] ?? '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã cấp lại mã thành công: $newCode'),
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
            child: const Text('Cấp mã mới'),
          ),
        ],
      ),
    );
  }

  void _confirmRevoke(ResidentActivationModel item, String buildingId) {
    final actId = item.activationId;
    if (actId == null || actId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy mã hợp lệ để thu hồi'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi mã kích hoạt'),
        content: Text(
          'Mã kích hoạt của cư dân "${item.fullName}" sẽ bị vô hiệu hóa ngay lập tức. Cư dân sẽ không thể dùng mã này để kích hoạt nữa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(residentActivationRepositoryProvider)
                    .revokeActivation(activationId: actId);
                ref.invalidate(buildingActivationListProvider(buildingId));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã thu hồi mã kích hoạt thành công'),
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
            child: const Text('Thu hồi'),
          ),
        ],
      ),
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
            content: Text(formatErrorMessage(e)),
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
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
