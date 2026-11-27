import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(batchImportProvider);
    final notifier = ref.read(batchImportProvider.notifier);
    final activeBuilding = ref.watch(activeBuildingProvider).value;
    final buildingId =
        activeBuilding?.id ?? BuildingRepository.kDefaultCanonicalBuildingId;

    // Lắng nghe thông báo để hiển thị SnackBar
    ref.listen<BatchImportState>(batchImportProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppSnackBar.showError(context, next.errorMessage!);
      } else if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        AppSnackBar.showSuccess(context, next.successMessage!);
      }
    });

    return RoleGuard(
      permission: AppPermissions.batchImport,
      child: Scaffold(
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
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: AppSpacing.p16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner giới thiệu
                  _buildIntroductionBanner(context),
                  AppSpacing.h16,

                  // Tab chọn loại dữ liệu nhập
                  _buildTypeSelector(state, notifier),
                  AppSpacing.h20,

                  // Bước 1: Tải file mẫu
                  _buildStepCard(
                    context: context,
                    stepNumber: '1',
                    title: 'Tải File Mẫu Chuẩn Hóa (.xlsx / .csv)',
                    subtitle:
                        'Tải file mẫu Excel hoặc CSV chuẩn để điền dữ liệu theo đúng cấu trúc hệ thống',
                    action: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.table_view),
                          label: const Text('Tải mẫu Excel (.xlsx)'),
                          onPressed: state.isProcessing
                              ? null
                              : () async {
                                  final path = await notifier.downloadTemplate(
                                    state.selectedType,
                                  );
                                  if (path != null && context.mounted) {
                                    AppSnackBar.showSuccess(
                                      context,
                                      'Đã tạo file mẫu Excel thành công',
                                    );
                                  }
                                },
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.description),
                          label: const Text('Tải mẫu CSV (.csv)'),
                          onPressed: state.isProcessing
                              ? null
                              : () async {
                                  final path = await notifier
                                      .downloadCsvTemplate(state.selectedType);
                                  if (path != null && context.mounted) {
                                    AppSnackBar.showSuccess(
                                      context,
                                      'Đã tạo file mẫu CSV thành công',
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h16,

                  // Bước 2: Chọn file dữ liệu
                  _buildStepCard(
                    context: context,
                    stepNumber: '2',
                    title: 'Chọn File Dữ Liệu Excel hoặc CSV',
                    subtitle:
                        'Hệ thống tự động phân tích và thẩm định từng dòng ngay khi bạn chọn file',
                    action: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Chọn file (.xlsx, .xls, .csv)'),
                          onPressed: state.isProcessing
                              ? null
                              : () => notifier.pickAndParseFile(
                                  buildingId: buildingId,
                                ),
                        ),
                        if (state.selectedFileName != null) ...[
                          AppSpacing.h8,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: AppRadius.r8,
                              border: Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                                AppSpacing.w8,
                                Expanded(
                                  child: Text(
                                    state.selectedFileName!,
                                    style: context.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
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
                  AppSpacing.h16,

                  // Bước 3: Kết quả kiểm tra & Thẩm định dữ liệu
                  _buildStepCard(
                    context: context,
                    stepNumber: '3',
                    title: 'Kết Quả Thẩm Định & Kiểm Tra',
                    subtitle:
                        'Xem chi tiết số dòng hợp lệ và các lỗi cần điều chỉnh trước khi lưu',
                    action: _buildValidationSection(context, state, notifier),
                  ),
                  AppSpacing.h24,

                  // Nút bấm thực thi chính
                  _buildExecuteButton(context, state, notifier, buildingId),
                  AppSpacing.h32,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroductionBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary, size: 24),
          AppSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quy chuẩn dữ liệu nhập tự động',
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                AppSpacing.h4,
                Text(
                  '• Mã căn hộ: Cấu trúc <Block><Tầng 2 số><Phòng 2 số> (VD: A0110, B0205).\n'
                  '• Số điện thoại: 10 chữ số chuẩn mạng viễn thông Việt Nam.\n'
                  '• Chỉ số điện nước: Số thực không âm (≥ 0).\n'
                  '• An toàn dữ liệu: Cư dân chuyển đi chỉ đổi trạng thái kết thúc, bảo toàn 100% lịch sử giao dịch và công nợ.',
                  style: context.bodySmall?.copyWith(
                    height: 1.4,
                    color: colorScheme.onSurface,
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
    required BuildContext context,
    required String stepNumber,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: colorScheme.primary,
                child: Text(
                  stepNumber,
                  style: context.labelMedium?.tabularFigures().copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AppSpacing.w10,
              Expanded(
                child: Text(
                  title,
                  style: context.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          Text(
            subtitle,
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.h12,
          action,
        ],
      ),
    );
  }

  Widget _buildValidationSection(
    BuildContext context,
    BatchImportState state,
    BatchImportNotifier notifier,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final errorColor = AppTheme.getSemanticError(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    if (state.isProcessing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              AppSpacing.h12,
              Text(
                'Đang phân tích và thẩm định dữ liệu...',
                style: context.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final validation = state.validationResult;
    if (validation == null) {
      return Container(
        padding: AppSpacing.p16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: AppRadius.r8,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          'Chưa có dữ liệu nào được thẩm định. Vui lòng chọn file Excel ở bước 2.',
          style: context.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
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
              context: context,
              label: 'Tổng số dòng',
              count: validation.totalRows,
              color: secondaryColor,
              icon: Icons.format_list_numbered,
            ),
            AppSpacing.w8,
            _buildStatBadge(
              context: context,
              label: 'Hợp lệ',
              count: validation.validCount,
              color: successColor,
              icon: Icons.check_circle,
            ),
            AppSpacing.w8,
            _buildStatBadge(
              context: context,
              label: 'Bị lỗi',
              count: validation.errorCount,
              color: errorColor,
              icon: Icons.error,
            ),
          ],
        ),
        AppSpacing.h12,

        // Khi toàn bộ hợp lệ
        if (validation.isAllValid)
          Container(
            padding: AppSpacing.p12,
            decoration: BoxDecoration(
              color: successColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.r8,
              border: Border.all(
                color: successColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: successColor, size: 20),
                AppSpacing.w8,
                Expanded(
                  child: Text(
                    'Tuyệt vời! 100% dòng dữ liệu đều hợp lệ và sẵn sàng nạp.',
                    style: context.titleSmall?.copyWith(
                      color: successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Khi có lỗi
        if (validation.hasErrors) ...[
          Container(
            padding: AppSpacing.p12,
            decoration: BoxDecoration(
              color: errorColor.withValues(alpha: 0.08),
              borderRadius: AppRadius.r8,
              border: Border.all(color: errorColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: errorColor,
                      size: 20,
                    ),
                    AppSpacing.w8,
                    Expanded(
                      child: Text(
                        'Phát hiện ${validation.errorCount} dòng dữ liệu không hợp lệ',
                        style: context.titleSmall?.tabularFigures().copyWith(
                          color: errorColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.h12,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: errorColor,
                        side: BorderSide(color: errorColor),
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.table_view_outlined),
                      label: const Text('Xuất file Excel lỗi'),
                      onPressed: () async {
                        final path = await notifier.exportErrorRows();
                        if (path != null && context.mounted) {
                          AppSnackBar.showSuccess(
                            context,
                            'Đã xuất file Excel dòng lỗi thành công',
                          );
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: errorColor,
                        side: BorderSide(color: errorColor),
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Xuất file CSV lỗi'),
                      onPressed: () async {
                        final path = await notifier.exportErrorRowsCsv();
                        if (path != null && context.mounted) {
                          AppSnackBar.showSuccess(
                            context,
                            'Đã xuất file CSV dòng lỗi thành công',
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.h12,

          // Tùy chọn chỉ nạp dòng hợp lệ
          if (validation.hasValidItems)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Chỉ nạp ${validation.validCount} dòng hợp lệ (bỏ qua ${validation.errorCount} dòng lỗi)',
                style: context.bodyMedium?.tabularFigures().copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Cho phép nạp trước các dòng đạt chuẩn, các dòng lỗi có thể sửa và nạp lại sau',
                style: context.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: state.importOnlyValidRows,
              onChanged: (val) => notifier.toggleImportOnlyValidRows(val),
            ),

          // Danh sách lỗi chi tiết thu gọn
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              'Xem chi tiết ${validation.errorCount} lỗi',
              style: context.titleSmall?.tabularFigures().copyWith(
                fontWeight: FontWeight.bold,
                color: errorColor,
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
                    Icon(Icons.circle, size: 6, color: errorColor),
                    AppSpacing.w8,
                    Expanded(
                      child: Text(
                        err.displayText,
                        style: context.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        // Xem trước dữ liệu hợp lệ (Preview Data)
        if (validation.hasValidItems) ...[
          AppSpacing.h12,
          _buildPreviewSection(context, state, validation),
        ],
      ],
    );
  }

  Widget _buildPreviewSection(
    BuildContext context,
    BatchImportState state,
    BatchImportResultModel validation,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final validItems = validation.validItems;
    final displayItems = validItems.take(20).toList();

    return ExpansionTile(
      initiallyExpanded: true,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(
            Icons.preview_outlined,
            color: colorScheme.primary,
            size: 20,
          ),
          AppSpacing.w8,
          Expanded(
            child: Text(
              'Xem trước dữ liệu (${validation.validCount} dòng hợp lệ)',
              style: context.titleSmall?.tabularFigures().copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      subtitle: validItems.length > 20
          ? Text(
              'Hiển thị 20 / ${validItems.length} dòng đầu tiên',
              style: context.labelSmall?.tabularFigures().copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: AppRadius.r8,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.r8,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  colorScheme.primary.withValues(alpha: 0.05),
                ),
                columnSpacing: 20,
                horizontalMargin: 12,
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columns: _buildTableColumns(state.selectedType),
                rows: displayItems.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return _buildTableRow(context, idx, item, state.selectedType);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<DataColumn> _buildTableColumns(BatchImportType type) {
    switch (type) {
      case BatchImportType.apartments:
        return const [
          DataColumn(
            label: Text('STT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Mã Căn Hộ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Tòa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('Tầng', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Diện Tích (m²)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Trạng Thái',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ];
      case BatchImportType.residents:
        return const [
          DataColumn(
            label: Text('STT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Mã Căn Hộ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Họ Và Tên',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Số Điện Thoại',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Vai Trò',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ];
      case BatchImportType.meterReadings:
        return const [
          DataColumn(
            label: Text('STT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Mã Căn Hộ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Chỉ Số Điện',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Chỉ Số Nước',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Kỳ Thu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ];
    }
  }

  DataRow _buildTableRow(
    BuildContext context,
    int stt,
    dynamic item,
    BatchImportType type,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case BatchImportType.apartments:
        final apt = item as ApartmentImportItem;
        return DataRow(
          cells: [
            DataCell(Text('$stt', style: context.bodySmall?.tabularFigures())),
            DataCell(
              Text(
                apt.code,
                style: context.bodySmall?.tabularFigures().copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            DataCell(Text(apt.block)),
            DataCell(
              Text('${apt.floor}', style: context.bodySmall?.tabularFigures()),
            ),
            DataCell(
              Text(
                '${apt.area} m²',
                style: context.bodySmall?.tabularFigures(),
              ),
            ),
            DataCell(Text(apt.isEmpty ? 'Còn trống' : 'Đã có chủ')),
          ],
        );
      case BatchImportType.residents:
        final res = item as ResidentImportItem;
        return DataRow(
          cells: [
            DataCell(Text('$stt', style: context.bodySmall?.tabularFigures())),
            DataCell(
              Text(
                res.apartmentCode,
                style: context.bodySmall?.tabularFigures().copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            DataCell(
              Text(
                res.fullName,
                style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            DataCell(
              Text(res.phone, style: context.bodySmall?.tabularFigures()),
            ),
            DataCell(Text(res.relationRoleText)),
            DataCell(Text(res.email ?? '-')),
          ],
        );
      case BatchImportType.meterReadings:
        final meter = item as MeterReadingImportItem;
        return DataRow(
          cells: [
            DataCell(Text('$stt', style: context.bodySmall?.tabularFigures())),
            DataCell(
              Text(
                meter.apartmentCode,
                style: context.bodySmall?.tabularFigures().copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            DataCell(
              Text(
                '${meter.electricReading} kWh',
                style: context.bodySmall?.tabularFigures(),
              ),
            ),
            DataCell(
              Text(
                '${meter.waterReading} m³',
                style: context.bodySmall?.tabularFigures(),
              ),
            ),
            DataCell(
              Text(
                meter.period ?? '-',
                style: context.bodySmall?.tabularFigures(),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildStatBadge({
    required BuildContext context,
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
          borderRadius: AppRadius.r8,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            AppSpacing.h4,
            Text(
              '$count',
              style: context.titleLarge?.tabularFigures().copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: context.labelSmall?.copyWith(
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
    final colorScheme = Theme.of(context).colorScheme;
    final validation = state.validationResult;
    final canExecute =
        validation != null &&
        validation.hasValidItems &&
        (!validation.hasErrors || state.importOnlyValidRows) &&
        !state.isProcessing;

    final countToImport = validation?.validCount ?? 0;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
      ),
      icon: state.isProcessing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
          : const Icon(Icons.cloud_upload),
      label: Text(
        state.isProcessing
            ? 'Đang tiến hành nạp...'
            : 'Tiến Hành Nạp $countToImport Dòng Dữ Liệu',
        style: context.titleMedium?.tabularFigures().copyWith(
          fontWeight: FontWeight.bold,
          color: canExecute
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant,
        ),
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
          style: ctx.bodyMedium?.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
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
