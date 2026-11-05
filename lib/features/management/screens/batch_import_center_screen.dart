import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/batch_import_model.dart';
import '../../../data/providers/batch_import_provider.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/repositories/building_repository.dart';

class BatchImportCenterScreen extends ConsumerStatefulWidget {
  const BatchImportCenterScreen({super.key});

  @override
  ConsumerState<BatchImportCenterScreen> createState() =>
      _BatchImportCenterScreenState();
}

class _BatchImportCenterScreenState
    extends ConsumerState<BatchImportCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchImportProvider);
    final notifier = ref.read(batchImportProvider.notifier);
    final activeBuilding = ref.watch(activeBuildingProvider).value;
    final buildingId =
        activeBuilding?.id ?? BuildingRepository.kDefaultCanonicalBuildingId;

    // Lắng nghe thông báo để hiển thị SnackBar
    ref.listen<BatchImportState>(batchImportProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập Liệu Hàng Loạt'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.reset(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner giới thiệu
            _buildIntroductionBanner(),
            const SizedBox(height: 16),

            // Tab chọn loại dữ liệu nhập
            _buildTypeSelector(state, notifier),
            const SizedBox(height: 20),

            // Bước 1: Tải file mẫu
            _buildStepCard(
              stepNumber: '1',
              title: 'Tải File Mẫu Chuẩn Hóa (.xlsx)',
              subtitle:
                  'Tải file mẫu Excel chuẩn để điền dữ liệu theo đúng cấu trúc hệ thống',
              action: OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: Text('Tải mẫu ${state.selectedType.label}'),
                onPressed: state.isProcessing
                    ? null
                    : () async {
                        final path = await notifier.downloadTemplate(
                          state.selectedType,
                        );
                        if (path != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã tạo file mẫu Excel thành công'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      },
              ),
            ),
            const SizedBox(height: 16),

            // Bước 2: Chọn file dữ liệu
            _buildStepCard(
              stepNumber: '2',
              title: 'Chọn File Dữ Liệu Excel',
              subtitle:
                  'Hệ thống tự động phân tích và thẩm định từng dòng ngay khi bạn chọn file',
              action: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Chọn file Excel (.xlsx, .xls)'),
                    onPressed: state.isProcessing
                        ? null
                        : () =>
                              notifier.pickAndParseFile(buildingId: buildingId),
                  ),
                  if (state.selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.selectedFileName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bước 3: Kết quả kiểm tra & Thẩm định dữ liệu
            _buildStepCard(
              stepNumber: '3',
              title: 'Kết Quả Thẩm Định & Kiểm Tra',
              subtitle:
                  'Xem chi tiết số dòng hợp lệ và các lỗi cần điều chỉnh trước khi lưu',
              action: _buildValidationSection(context, state, notifier),
            ),
            const SizedBox(height: 24),

            // Nút bấm thực thi chính
            _buildExecuteButton(context, state, notifier, buildingId),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroductionBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.primary, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quy chuẩn dữ liệu nhập tự động',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Mã căn hộ: Cấu trúc <Block><Tầng 2 số><Phòng 2 số> (VD: A0110, B0205).\n'
                  '• Số điện thoại: 10 chữ số chuẩn mạng viễn thông Việt Nam.\n'
                  '• Chỉ số điện nước: Số thực không âm (≥ 0).\n'
                  '• An toàn dữ liệu: Cư dân chuyển đi chỉ đổi trạng thái kết thúc, bảo toàn 100% lịch sử giao dịch và công nợ.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(
    BatchImportState state,
    BatchImportNotifier notifier,
  ) {
    return SegmentedButton<BatchImportType>(
      segments: const [
        ButtonSegment(
          value: BatchImportType.apartments,
          label: Text('Căn hộ'),
          icon: Icon(Icons.apartment),
        ),
        ButtonSegment(
          value: BatchImportType.residents,
          label: Text('Cư dân'),
          icon: Icon(Icons.people),
        ),
        ButtonSegment(
          value: BatchImportType.meterReadings,
          label: Text('Điện nước'),
          icon: Icon(Icons.speed),
        ),
      ],
      selected: {state.selectedType},
      onSelectionChanged: (newSelection) {
        if (newSelection.isNotEmpty) {
          notifier.selectType(newSelection.first);
        }
      },
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            action,
          ],
        ),
      ),
    );
  }

  Widget _buildValidationSection(
    BuildContext context,
    BatchImportState state,
    BatchImportNotifier notifier,
  ) {
    if (state.isProcessing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Đang phân tích và thẩm định dữ liệu...',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final validation = state.validationResult;
    if (validation == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Chưa có dữ liệu nào được thẩm định. Vui lòng chọn file Excel ở bước 2.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thống kê nhanh 3 cột
        Row(
          children: [
            _buildStatBadge(
              label: 'Tổng số dòng',
              count: validation.totalRows,
              color: Colors.blueGrey,
              icon: Icons.format_list_numbered,
            ),
            const SizedBox(width: 8),
            _buildStatBadge(
              label: 'Hợp lệ',
              count: validation.validCount,
              color: AppTheme.success,
              icon: Icons.check_circle,
            ),
            const SizedBox(width: 8),
            _buildStatBadge(
              label: 'Bị lỗi',
              count: validation.errorCount,
              color: AppTheme.error,
              icon: Icons.error,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Khi toàn bộ hợp lệ
        if (validation.isAllValid)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.success.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: AppTheme.success, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tuyệt vời! 100% dòng dữ liệu đều hợp lệ và sẵn sàng nạp.',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Khi có lỗi
        if (validation.hasErrors) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phát hiện ${validation.errorCount} dòng dữ liệu không hợp lệ',
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Xuất file Excel danh sách dòng lỗi'),
                  onPressed: () async {
                    final path = await notifier.exportErrorRows();
                    if (path != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã xuất file Excel dòng lỗi thành công',
                          ),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tùy chọn chỉ nạp dòng hợp lệ
          if (validation.hasValidItems)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Chỉ nạp ${validation.validCount} dòng hợp lệ (bỏ qua ${validation.errorCount} dòng lỗi)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Cho phép nạp trước các dòng đạt chuẩn, các dòng lỗi có thể sửa và nạp lại sau',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              value: state.importOnlyValidRows,
              onChanged: (val) => notifier.toggleImportOnlyValidRows(val),
            ),

          // Danh sách lỗi chi tiết thu gọn
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                'Xem chi tiết ${validation.errorCount} lỗi',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.error,
                ),
              ),
              children: validation.rowErrors.map((err) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          err.displayText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatBadge({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.85),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecuteButton(
    BuildContext context,
    BatchImportState state,
    BatchImportNotifier notifier,
    String buildingId,
  ) {
    final validation = state.validationResult;
    final canExecute =
        validation != null &&
        validation.hasValidItems &&
        (!validation.hasErrors || state.importOnlyValidRows) &&
        !state.isProcessing;

    final countToImport = validation?.validCount ?? 0;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: state.isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.cloud_upload),
      label: Text(
        state.isProcessing
            ? 'Đang tiến hành nạp...'
            : 'Tiến Hành Nạp $countToImport Dòng Dữ Liệu',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      onPressed: canExecute
          ? () => _confirmAndExecute(
              context,
              notifier,
              buildingId,
              countToImport,
              state.selectedType.label,
            )
          : null,
    );
  }

  void _confirmAndExecute(
    BuildContext context,
    BatchImportNotifier notifier,
    String buildingId,
    int count,
    String typeLabel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận nạp dữ liệu'),
        content: Text(
          'Bạn có chắc chắn muốn nạp $count dòng dữ liệu $typeLabel vào tòa nhà này?\n\n'
          'Hệ thống sẽ cập nhật tự động và ghi nhận toàn bộ lịch sử quản lý.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.executeImport(buildingId: buildingId);
            },
            child: const Text('Đồng ý nạp'),
          ),
        ],
      ),
    );
  }
}
