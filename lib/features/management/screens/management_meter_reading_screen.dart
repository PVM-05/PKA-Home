import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../data/models/meter_reading_submission_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/meter_reading_provider.dart';
import '../../../core/utils/error_formatter.dart';

class ManagementMeterReadingScreen extends ConsumerStatefulWidget {
  const ManagementMeterReadingScreen({super.key});

  @override
  ConsumerState<ManagementMeterReadingScreen> createState() => _ManagementMeterReadingScreenState();
}

class _ManagementMeterReadingScreenState extends ConsumerState<ManagementMeterReadingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(allMeterReadingsProvider);
    ref.invalidate(pendingMeterReadingsCountProvider);
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppStatusColors.paid, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phê Duyệt Chỉ Số - Căn ${item.apartmentCode ?? ''}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kỳ: ${item.period} • Người gửi: ${item.submitterName ?? 'Cư dân'}'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Điện mới: ${item.electricReading} kWh', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('• Nước mới: ${item.waterReading} m³', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Tự động tạo hóa đơn tháng cho căn hộ này',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Tính phí điện, nước theo chỉ số mới và phí quản lý',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
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

    if (confirmed == true && mounted) {
      try {
        await ref.read(meterReadingRepositoryProvider).approveReading(
              submissionId: item.id,
              generateInvoice: generateInvoice,
              dueDate: generateInvoice ? defaultDueDate : null,
            );

        _refreshAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                generateInvoice
                    ? 'Đã duyệt chỉ số và tự động tạo hóa đơn tháng thành công!'
                    : 'Đã duyệt chỉ số thành công!',
              ),
              backgroundColor: AppStatusColors.paid,
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
    }
  }

  Future<void> _showRejectDialog(MeterReadingSubmissionModel item) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: AppTheme.error, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Từ Chối Chỉ Số - Căn ${item.apartmentCode ?? ''}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  'Vui lòng nhập lý do từ chối để cư dân nắm được thông tin và khai báo lại:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Lý do từ chối *',
                    hintText: 'VD: Ảnh mờ không rõ số, số điện thấp hơn thực tế...',
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

    if (confirmed == true && mounted) {
      try {
        await ref.read(meterReadingRepositoryProvider).rejectReading(
              submissionId: item.id,
              reason: reasonController.text.trim(),
            );

        _refreshAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã từ chối chỉ số thành công.'),
              backgroundColor: AppTheme.warning,
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
    }
  }

  void _showImageDialog(String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(title, style: const TextStyle(fontSize: 16)),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Không thể tải hình ảnh công tơ'),
                  ),
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

    return Scaffold(
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
          _buildSubmissionList('approved'),
          _buildSubmissionList('rejected'),
        ],
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
            if (status == 'approved') emptyMessage = 'Chưa có chỉ số nào được duyệt.';
            if (status == 'rejected') emptyMessage = 'Không có chỉ số nào bị từ chối.';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  Text(emptyMessage, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
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
        error: (e, _) => Center(child: AppErrorCard(error: e, onRetry: _refreshAll)),
      ),
    );
  }

  Widget _buildSubmissionCard(MeterReadingSubmissionModel item, String currentTabStatus) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.apartment, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Căn hộ ${item.apartmentCode ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Kỳ: ${item.period} • Gửi lúc ${_dateFormat.format(item.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.statusDisplayName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
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
                          Icon(Icons.bolt, color: Colors.amber.shade800, size: 18),
                          const SizedBox(width: 4),
                          const Text('Điện (kWh)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.electricReading} kWh',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                      if (item.electricImageUrl != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showImageDialog('Ảnh công tơ điện - Căn ${item.apartmentCode}', item.electricImageUrl!),
                          child: const Row(
                            children: [
                              Icon(Icons.image, size: 14, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text('Xem ảnh', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
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
                          Icon(Icons.water_drop, color: Colors.blue.shade800, size: 18),
                          const SizedBox(width: 4),
                          const Text('Nước (m³)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.waterReading} m³',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                      if (item.waterImageUrl != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showImageDialog('Ảnh công tơ nước - Căn ${item.apartmentCode}', item.waterImageUrl!),
                          child: const Row(
                            children: [
                              Icon(Icons.image, size: 14, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text('Xem ảnh', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
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
            Text(
              'Người gửi: ${item.submitterName}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${item.rejectReason}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Hành động nếu là Tab Chờ duyệt
          if (currentTabStatus == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
