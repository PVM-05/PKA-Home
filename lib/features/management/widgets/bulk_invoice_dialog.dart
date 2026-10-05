import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/bulk_invoice_validation_model.dart';
import '../../../data/providers/management_provider.dart';

class BulkInvoiceDialog extends ConsumerStatefulWidget {
  const BulkInvoiceDialog({super.key});

  @override
  ConsumerState<BulkInvoiceDialog> createState() => _BulkInvoiceDialogState();
}

class _BulkInvoiceDialogState extends ConsumerState<BulkInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _periodController;
  late final TextEditingController _dueDateController;
  final TextEditingController _mgmtRateController = TextEditingController(text: '10000');
  final TextEditingController _electricRateController = TextEditingController(text: '3500');
  final TextEditingController _waterRateController = TextEditingController(text: '18000');

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 15));
  int _currentStep = 1; // 1: Cấu hình, 2: Kết quả tiền kiểm tra (Pre-flight)
  bool _isLoading = false;
  BulkInvoiceValidationModel? _validationResult;
  int _selectedListTab = 0; // 0: Căn hợp lệ, 1: Căn cần xử lý

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodController = TextEditingController(text: '${now.month.toString().padLeft(2, '0')}/${now.year}');
    _dueDateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_selectedDueDate),
    );
  }

  @override
  void dispose() {
    _periodController.dispose();
    _dueDateController.dispose();
    _mgmtRateController.dispose();
    _electricRateController.dispose();
    _waterRateController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
        _dueDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _runDryRunValidation() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final period = _periodController.text.trim();
      final mgmtRate = double.tryParse(_mgmtRateController.text.trim()) ?? 10000;
      final electricRate = double.tryParse(_electricRateController.text.trim()) ?? 3500;
      final waterRate = double.tryParse(_waterRateController.text.trim()) ?? 18000;

      final result = await ref.read(managementRepositoryProvider).validateMonthlyBulkInvoices(
            period: period,
            mgmtRate: mgmtRate,
            electricRate: electricRate,
            waterRate: waterRate,
          );

      if (mounted) {
        setState(() {
          _validationResult = result;
          _currentStep = 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi kiểm tra dữ liệu: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _generateInvoices() async {
    if (_validationResult == null || !_validationResult!.canGenerateAny) return;

    setState(() => _isLoading = true);

    try {
      final period = _periodController.text.trim();
      final mgmtRate = double.tryParse(_mgmtRateController.text.trim()) ?? 10000;
      final electricRate = double.tryParse(_electricRateController.text.trim()) ?? 3500;
      final waterRate = double.tryParse(_waterRateController.text.trim()) ?? 18000;

      final result = await ref.read(managementRepositoryProvider).generateValidBulkInvoices(
            period: period,
            dueDate: _selectedDueDate,
            mgmtRate: mgmtRate,
            electricRate: electricRate,
            waterRate: waterRate,
          );

      if (mounted) {
        ref.invalidate(invoicesProvider);
        Navigator.of(context).pop(true);

        final created = result['invoices_created'] ?? 0;
        final totalAmount = (result['total_amount'] as num?)?.toDouble() ?? 0.0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã tạo thành công $created hóa đơn cho kỳ $period với tổng dự thu ${_currencyFormat.format(totalAmount)}!',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo hóa đơn hàng loạt: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 1) {
      return _buildStep1Configuration(context);
    } else {
      return _buildStep2PreflightResult(context);
    }
  }

  Widget _buildStep1Configuration(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('Tạo hóa đơn hàng loạt'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bước 1: Thiết lập kỳ và biểu phí để hệ thống chạy tiền kiểm tra (Dry-Run) trước khi phát hành hóa đơn.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _periodController,
                decoration: const InputDecoration(
                  labelText: 'Kỳ hóa đơn *',
                  hintText: 'VD: 10/2026',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập kỳ hóa đơn' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dueDateController,
                readOnly: true,
                onTap: _selectDueDate,
                decoration: const InputDecoration(
                  labelText: 'Hạn thanh toán *',
                  prefixIcon: Icon(Icons.event_available_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _electricRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Đơn giá điện (đ/kWh) *',
                  prefixIcon: Icon(Icons.bolt_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập giá điện' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _waterRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Đơn giá nước (đ/m³) *',
                  prefixIcon: Icon(Icons.water_drop_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập giá nước' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mgmtRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Phí quản lý (đ/m²) *',
                  prefixIcon: Icon(Icons.apartment_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập phí quản lý' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.fact_check_outlined, size: 18),
          label: Text(_isLoading ? 'Đang kiểm tra...' : 'Kiểm tra dữ liệu'),
          onPressed: _isLoading ? null : _runDryRunValidation,
        ),
      ],
    );
  }

  Widget _buildStep2PreflightResult(BuildContext context) {
    final result = _validationResult;
    if (result == null) return const SizedBox.shrink();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.fact_check_outlined, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kết Quả Tiền Kiểm Tra',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kỳ: ${result.period} • Quét ${result.totalScanned} căn hộ (Dry-Run: Chưa ghi vào cơ sở dữ liệu)',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              // 4 Thẻ KPI
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      label: '${result.validCount} Hợp lệ',
                      sub: 'Có thể tạo',
                      color: AppStatusColors.paid,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      label: '${result.missingCount} Thiếu số',
                      sub: 'Cần bổ sung',
                      color: AppTheme.warning,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      label: '${result.invalidCount} Bất thường',
                      sub: 'Cần kiểm tra',
                      color: AppTheme.error,
                      icon: Icons.error_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      label: '${result.alreadyInvoicedCount} Đã có HĐ',
                      sub: 'Không tạo trùng',
                      color: Colors.blueGrey,
                      icon: Icons.done_all,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Thẻ tóm tắt dự thu
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng tiền dự thu (${'các căn hợp lệ'}):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(result.totalEstimatedAmount),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    Text(
                      '${result.validCount}/${result.totalScanned} căn',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Chuyển đổi danh sách chi tiết
              Row(
                children: [
                  ChoiceChip(
                    label: Text('Căn hợp lệ (${result.validCount})'),
                    selected: _selectedListTab == 0,
                    onSelected: (_) => setState(() => _selectedListTab = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Cần xử lý (${result.issues.length})'),
                    selected: _selectedListTab == 1,
                    onSelected: (_) => setState(() => _selectedListTab = 1),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Danh sách chi tiết cuộn
              Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedListTab == 0
                    ? _buildValidItemsList(result.validItems)
                    : _buildIssuesList(result.issues),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isLoading ? null : () => setState(() => _currentStep = 1),
          child: const Text('Quay lại chỉnh sửa'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: (_isLoading || !result.canGenerateAny) ? null : _generateInvoices,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Tạo ${result.validCount} hóa đơn hợp lệ'),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                Text(sub, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidItemsList(List<ValidApartmentBillingItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('Không có căn hộ nào đủ điều kiện tạo hóa đơn.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.apartment, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text('Căn ${item.apartmentCode}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text('(${item.area} m²)', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
              Text(_currencyFormat.format(item.estimatedTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIssuesList(List<BulkInvoiceIssueItem> issues) {
    if (issues.isEmpty) {
      return const Center(child: Text('Tất cả các căn hộ đều hợp lệ!', style: TextStyle(fontSize: 12, color: AppStatusColors.paid)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: issues.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final issue = issues[index];
        Color color = AppTheme.warning;
        if (issue.isInvalidReading) color = AppTheme.error;
        if (issue.isAlreadyInvoiced) color = Colors.blueGrey;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  issue.apartmentCode,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issue.typeDisplayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                    Text(issue.message, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
