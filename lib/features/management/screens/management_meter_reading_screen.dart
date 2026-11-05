import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../data/models/meter_reading_submission_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/meter_reading_provider.dart';
import '../../../core/utils/network_error_handler.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/constants/permissions.dart';

class ManagementMeterReadingScreen extends ConsumerStatefulWidget {
  const ManagementMeterReadingScreen({super.key});

  @override
  ConsumerState<ManagementMeterReadingScreen> createState() =>
      _ManagementMeterReadingScreenState();
}

class _ManagementMeterReadingScreenState
    extends ConsumerState<ManagementMeterReadingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(allMeterReadingsProvider);
    ref.invalidate(anomalyMeterReadingsProvider);
    ref.invalidate(pendingMeterReadingsCountProvider);
    ref.invalidate(pendingAnomalyCountProvider);
  }

  Future<void> _showApproveDialog(MeterReadingSubmissionModel item) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    bool generateInvoice = true;
    final defaultDueDate = DateTime.now().add(const Duration(days: 10));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppStatusColors.paid,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phê Duyệt Chỉ Số - Căn ${item.apartmentCode ?? ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kỳ: ${item.period} • Người gửi: ${item.submitterName ?? 'Cư dân'}',
                    ),
                    const SizedBox(height: 12),

                    // Cảnh báo nếu chỉ số có cờ bất thường
                    if (item.hasAnomaly) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.isDangerAnomaly
                              ? AppTheme.error.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          border: Border.all(
                            color: item.isDangerAnomaly
                                ? AppTheme.error
                                : Colors.orange,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              item.isDangerAnomaly
                                  ? Icons.error_outline
                                  : Icons.warning_amber_rounded,
                              color: item.isDangerAnomaly
                                  ? AppTheme.error
                                  : Colors.orange.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cảnh báo ${item.anomalySeverityDisplayName}: ${item.anomalyReason ?? ''}. Đề nghị kỹ thuật kiểm tra thực tế trước khi phát hành hóa đơn!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: item.isDangerAnomaly
                                      ? AppTheme.error
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• Điện mới: ${item.electricReading} kWh',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Nước mới: ${item.waterReading} m³',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Tự động tạo hóa đơn tháng cho căn hộ này',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Tính phí điện, nước theo chỉ số mới và phí quản lý',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      value: generateInvoice,
                      activeColor: AppTheme.primary,
                      onChanged: (val) {
                        setDialogState(() {
                          generateInvoice = val ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Xác nhận duyệt'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await ref
          .read(meterReadingRepositoryProvider)
          .approveReading(
            submissionId: item.id,
            generateInvoice: generateInvoice,
            dueDate: defaultDueDate,
          );

      _refreshAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Đã phê duyệt chỉ số thành công!'),
            backgroundColor: AppStatusColors.paid,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(NetworkErrorHandler.getMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(MeterReadingSubmissionModel item) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.cancel_outlined,
                color: AppTheme.error,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Từ Chối Chỉ Số - Căn ${item.apartmentCode ?? ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vui lòng nhập lý do từ chối để cư dân nắm được và thực hiện khai báo lại:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'VD: Ảnh chụp đồng hồ nước bị mờ, không rõ 2 số cuối...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập lý do từ chối';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Xác nhận từ chối'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await ref
          .read(meterReadingRepositoryProvider)
          .rejectReading(
            submissionId: item.id,
            reason: reasonController.text.trim(),
          );

      _refreshAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Đã từ chối chỉ số.'),
            backgroundColor: AppTheme.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(NetworkErrorHandler.getMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showImageDialog(String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: AppTheme.textSecondary,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Không thể tải ảnh minh chứng',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    final pendingCountAsync = ref.watch(pendingMeterReadingsCountProvider);
    final pendingAnomalyAsync = ref.watch(pendingAnomalyCountProvider);

    return RoleGuard(
      permission: AppPermissions.meterReadingManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Duyệt Chỉ Số Điện Nước'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: _refreshAll,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chờ duyệt'),
                    const SizedBox(width: 6),
                    pendingCountAsync.when(
                      data: (count) => count > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bất thường'),
                    const SizedBox(width: 6),
                    pendingAnomalyAsync.when(
                      data: (count) => count > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade800,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const Tab(text: 'Đã duyệt'),
              const Tab(text: 'Đã từ chối'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSubmissionList('pending'),
            _buildAnomalyList(),
            _buildSubmissionList('approved'),
            _buildSubmissionList('rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomalyList() {
    final anomaliesAsync = ref.watch(anomalyMeterReadingsProvider);

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: anomaliesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 64,
                    color: AppStatusColors.paid,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Không có chỉ số nào bị gắn cờ bất thường.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildSubmissionCard(item, item.status);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: AppErrorCard(error: e, onRetry: _refreshAll),
        ),
      ),
    );
  }

  Widget _buildSubmissionList(String status) {
    final submissionsAsync = ref.watch(allMeterReadingsProvider(status));

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: submissionsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            String emptyMessage = 'Không có chỉ số nào đang chờ duyệt.';
            if (status == 'approved')
              emptyMessage = 'Chưa có chỉ số nào được duyệt.';
            if (status == 'rejected')
              emptyMessage = 'Không có chỉ số nào bị từ chối.';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildSubmissionCard(item, status);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: AppErrorCard(error: e, onRetry: _refreshAll),
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(
    MeterReadingSubmissionModel item,
    String currentTabStatus,
  ) {
    Color statusColor = AppTheme.warning;
    if (item.isApproved) statusColor = AppStatusColors.paid;
    if (item.isRejected) statusColor = AppTheme.error;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.apartment,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Căn hộ ${item.apartmentCode ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Kỳ: ${item.period} • Gửi lúc ${_dateFormat.format(item.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.statusDisplayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          // Banner cảnh báo bất thường AI/OCR nếu có
          if (item.hasAnomaly) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.isDangerAnomaly
                    ? AppTheme.error.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.08),
                border: Border.all(
                  color: item.isDangerAnomaly ? AppTheme.error : Colors.orange,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.isDangerAnomaly
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: item.isDangerAnomaly
                            ? AppTheme.error
                            : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Phát hiện bất thường: ${item.anomalySeverityDisplayName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: item.isDangerAnomaly
                              ? AppTheme.error
                              : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  if (item.anomalyReason != null &&
                      item.anomalyReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.anomalyReason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: item.isDangerAnomaly
                            ? AppTheme.error
                            : Colors.orange.shade900,
                      ),
                    ),
                  ],
                  if (item.previousElectricReading != null ||
                      item.previousWaterReading != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '• Đối chiếu cũ: Điện ${item.previousElectricReading ?? '—'} kWh (TB: ${item.avgElectricUsage ?? '—'}) | Nước ${item.previousWaterReading ?? '—'} m³ (TB: ${item.avgWaterUsage ?? '—'})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Chỉ số điện và nước
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: Colors.amber.shade800,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Điện (kWh)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.electricReading} kWh',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.electricImageUrl != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showImageDialog(
                            'Ảnh công tơ điện - Căn ${item.apartmentCode}',
                            item.electricImageUrl!,
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.image,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Xem ảnh',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop,
                            color: Colors.blue.shade800,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Nước (m³)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.waterReading} m³',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.waterImageUrl != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showImageDialog(
                            'Ảnh công tơ nước - Căn ${item.apartmentCode}',
                            item.waterImageUrl!,
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.image,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Xem ảnh',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (item.submitterName != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Người gửi: ${item.submitterName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Độ tin cậy OCR: ${(item.ocrConfidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          if (item.isRejected && item.rejectReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${item.rejectReason}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Hành động nếu là Tab Chờ duyệt hoặc Bất thường có status pending
          if (currentTabStatus == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Từ chối'),
                    onPressed: () => _showRejectDialog(item),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Phê duyệt'),
                    onPressed: () => _showApproveDialog(item),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
