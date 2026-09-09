import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/resident_invoice_provider.dart' show invoiceDetailProvider;

class EditInvoiceScreen extends ConsumerStatefulWidget {
  final InvoiceModel invoice;

  const EditInvoiceScreen({super.key, required this.invoice});

  @override
  ConsumerState<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditableFeeItem {
  final TextEditingController feeTypeController;
  final TextEditingController unitPriceController;
  final TextEditingController quantityController;

  _EditableFeeItem({
    required String feeType,
    required double unitPrice,
    required double quantity,
    required VoidCallback onChanged,
  })  : feeTypeController = TextEditingController(text: feeType),
        unitPriceController = TextEditingController(
          text: unitPrice % 1 == 0 ? unitPrice.toInt().toString() : unitPrice.toString(),
        ),
        quantityController = TextEditingController(
          text: quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString(),
        ) {
    feeTypeController.addListener(onChanged);
    unitPriceController.addListener(onChanged);
    quantityController.addListener(onChanged);
  }

  double get unitPrice => double.tryParse(unitPriceController.text) ?? 0.0;
  double get quantity => double.tryParse(quantityController.text) ?? 0.0;
  double get subtotal => unitPrice * quantity;

  void dispose() {
    feeTypeController.dispose();
    unitPriceController.dispose();
    quantityController.dispose();
  }
}

class _EditInvoiceScreenState extends ConsumerState<EditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  late TextEditingController _periodController;
  late DateTime _dueDate;
  late String _status;

  final List<_EditableFeeItem> _items = [];
  bool _isItemsInitialized = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _periodController = TextEditingController(text: widget.invoice.period);
    _dueDate = widget.invoice.dueDate;
    _status = widget.invoice.status;
  }

  @override
  void dispose() {
    _periodController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _onItemChanged() {
    if (mounted) setState(() {});
  }

  void _initializeItems(List<Map<String, dynamic>> rawItems) {
    if (_isItemsInitialized) return;
    for (final raw in rawItems) {
      final feeType = raw['fee_type'] as String? ?? 'Phí dịch vụ';
      final unitPrice = (raw['unit_price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (raw['quantity'] as num?)?.toDouble() ?? 1.0;
      _items.add(_EditableFeeItem(
        feeType: feeType,
        unitPrice: unitPrice,
        quantity: quantity,
        onChanged: _onItemChanged,
      ));
    }
    _isItemsInitialized = true;
  }

  void _addNewItem() {
    setState(() {
      _items.add(_EditableFeeItem(
        feeType: 'Phí khác',
        unitPrice: 0.0,
        quantity: 1.0,
        onChanged: _onItemChanged,
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hóa đơn phải có ít nhất một khoản phí.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  double get _totalAmount {
    double sum = 0.0;
    for (final item in _items) {
      sum += item.subtotal;
    }
    return sum;
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất một khoản phí.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final formattedItems = <Map<String, dynamic>>[];
    for (final item in _items) {
      final type = item.feeTypeController.text.trim();
      final price = item.unitPrice;
      final qty = item.quantity;
      if (type.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tên loại phí không được để trống.'),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }
      formattedItems.add({
        'fee_type': type,
        'unit_price': price,
        'quantity': qty,
      });
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(managementRepositoryProvider).updateInvoice(
            invoiceId: widget.invoice.id,
            period: _periodController.text.trim(),
            dueDate: _dueDate,
            status: _status,
            items: formattedItems,
          );

      ref.invalidate(invoicesProvider);
      ref.invalidate(invoiceDetailProvider(widget.invoice.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật hóa đơn thành công!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop(true);
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(invoiceDetailProvider(widget.invoice.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Sửa Hóa đơn ${widget.invoice.period}'),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text(
              'Lỗi tải chi tiết: ${formatErrorMessage(err)}',
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
          data: (rawItems) {
            _initializeItems(rawItems);

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGeneralInfoCard(),
                    const SizedBox(height: 16),
                    _buildFeeItemsCard(),
                    const SizedBox(height: 16),
                    _buildTotalCard(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'LƯU THAY ĐỔI',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGeneralInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin chung',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: AppTheme.radiusSm,
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Căn hộ: ${widget.invoice.apartment?.code ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (widget.invoice.apartment?.area != null) ...[
                    const Spacer(),
                    Text(
                      '${widget.invoice.apartment!.area} m²',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _periodController,
                    decoration: const InputDecoration(
                      labelText: 'Kỳ hóa đơn',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Vui lòng nhập kỳ' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectDueDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hạn thanh toán',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(_dateFormat.format(_dueDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Trạng thái hóa đơn',
                prefixIcon: Icon(Icons.info_outline),
              ),
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: 'unpaid', child: Text('Chưa thanh toán')),
                DropdownMenuItem(value: 'pending_confirmation', child: Text('Chờ xác nhận')),
                DropdownMenuItem(value: 'paid', child: Text('Đã thanh toán')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chi tiết các khoản phí',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                TextButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Thêm phí'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: AppTheme.radiusSm,
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: item.feeTypeController,
                            decoration: const InputDecoration(
                              labelText: 'Tên loại phí',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Nhập tên loại phí' : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                          tooltip: 'Xóa khoản phí',
                          onPressed: () => _removeItem(idx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: item.unitPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Đơn giá (đ)',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Nhập đơn giá';
                              if (double.tryParse(val) == null) return 'Sai định dạng';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: item.quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Số lượng',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Nhập SL';
                              if (double.tryParse(val) == null) return 'Sai';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Thành tiền', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              Text(
                                _currencyFormat.format(item.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TỔNG CỘNG MỚI:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
          ),
          Text(
            _currencyFormat.format(_totalAmount),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}
