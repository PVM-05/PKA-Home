import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
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
  final TextEditingController _electricRateController = TextEditingController(text: '3000');
  final TextEditingController _waterRateController = TextEditingController(text: '15000');

  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 15));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodController = TextEditingController(text: 'Tháng ${now.month}/${now.year}');
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

  Future<void> _generateInvoices() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final period = _periodController.text.trim();
      final mgmtRate = double.tryParse(_mgmtRateController.text.trim()) ?? 10000;
      final electricRate = double.tryParse(_electricRateController.text.trim()) ?? 3000;
      final waterRate = double.tryParse(_waterRateController.text.trim()) ?? 15000;

      final result = await ref.read(managementRepositoryProvider).generateMonthlyBulkInvoices(
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
        final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã tạo thành công $created hóa đơn cho kỳ $period với tổng dự thu ${currencyFormat.format(totalAmount)}!',
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
    return AlertDialog(
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
                'Hệ thống sẽ tự động quét tất cả căn hộ đang có người ở, tính phí quản lý theo diện tích, phí gửi xe theo xe đã duyệt và định mức điện nước.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _periodController,
                decoration: const InputDecoration(
                  labelText: 'Kỳ hóa đơn *',
                  hintText: 'VD: Tháng 10/2026',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
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
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mgmtRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Phí quản lý (đ/m²)',
                  prefixIcon: Icon(Icons.domain),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _electricRateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Điện (đ/kWh)',
                        prefixIcon: Icon(Icons.bolt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _waterRateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nước (đ/m³)',
                        prefixIcon: Icon(Icons.water_drop_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _generateInvoices,
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow),
          label: const Text('Tạo hóa đơn'),
        ),
      ],
    );
  }
}
