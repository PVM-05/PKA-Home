import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/invoice_items_provider.dart';
import '../../../core/utils/invoice_fee_helper.dart';

class EditInvoiceScreen extends ConsumerStatefulWidget {
  final InvoiceModel invoice;

  const EditInvoiceScreen({super.key, required this.invoice});

  @override
  ConsumerState<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditableFeeItem {
  String feeKey;
  final TextEditingController feeTypeController;
  final TextEditingController unitPriceController;
  final TextEditingController quantityController;

  _EditableFeeItem({
    required this.feeKey,
    required String feeName,
    required double unitPrice,
    required double quantity,
    required VoidCallback onChanged,
  })  : feeTypeController = TextEditingController(text: feeName),
        unitPriceController = TextEditingController(
          text: formatMoney(unitPrice.toInt(), includeSymbol: false),
        ),
        quantityController = TextEditingController(
          text: quantity % 1 == 0
              ? quantity.toInt().toString()
              : quantity.toString(),
        ) {
    feeTypeController.addListener(onChanged);
    unitPriceController.addListener(onChanged);
    quantityController.addListener(onChanged);
  }

  double get unitPrice => parseMoney(unitPriceController.text).toDouble();
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
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );
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
      final rawKey = raw['fee_type'] as String? ?? 'other';
      final feeName = InvoiceFeeHelper.getFeeName(rawKey);
      final unitPrice = (raw['unit_price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (raw['quantity'] as num?)?.toDouble() ?? 1.0;
      _items.add(
        _EditableFeeItem(
          feeKey: InvoiceFeeHelper.getFeeKey(rawKey),
          feeName: feeName,
          unitPrice: unitPrice,
          quantity: quantity,
          onChanged: _onItemChanged,
        ),
      );
    }
    _isItemsInitialized = true;
  }

  void _addNewItem() {
    setState(() {
      _items.add(
        _EditableFeeItem(
          feeKey: 'other',
          feeName: 'Phí khác',
          unitPrice: 0.0,
          quantity: 1.0,
          onChanged: _onItemChanged,
        ),
      );
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
      final displayName = item.feeTypeController.text.trim();
      final key = InvoiceFeeHelper.getFeeKey(displayName);
      final price = item.unitPrice;
      final qty = item.quantity;
      if (displayName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tên loại phí không được để trống.'),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }
      formattedItems.add({
        'fee_type': key,
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
    } on PostgrestException catch (pe) {
      if (mounted) {
        final isDuplicate = pe.code == '23505' ||
            pe.message.contains('uq_invoice_apartment_period') ||
            (pe.details?.toString().contains('uq_invoice_apartment_period') ??
                false);
        final errorText = isDuplicate
            ? 'Hóa đơn kỳ này đã tồn tại cho căn hộ đã chọn.'
            : formatErrorMessage(pe);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        final isDuplicate = errorStr.contains('23505') ||
            errorStr.contains('uq_invoice_apartment_period');
        final errorText = isDuplicate
            ? 'Hóa đơn kỳ này đã tồn tại cho căn hộ đã chọn.'
            : formatErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(invoiceDetailProvider(widget.invoice.id));

    return RoleGuard(
      permission: AppPermissions.invoiceManagement,
      child: Scaffold(
        appBar: AppBar(title: Text('Sửa Hóa đơn ${widget.invoice.period}')),
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

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Form(
                    key: _formKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;

                        if (isDesktop) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cột trái: Thông tin chung & Tổng tiền mới
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildGeneralInfoCard(constraints),
                                      const SizedBox(height: 20),
                                      _buildTotalAndSubmitCard(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Cột phải: Chi tiết các khoản phí
                                Expanded(
                                  flex: 7,
                                  child: _buildFeeItemsCard(constraints),
                                ),
                              ],
                            ),
                          );
                        }

                        // Giao diện Mobile / Tablet (< 900dp)
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildGeneralInfoCard(constraints),
                              const SizedBox(height: 16),
                              _buildFeeItemsCard(constraints),
                              const SizedBox(height: 20),
                              _buildTotalAndSubmitCard(),
                              const SizedBox(height: 32),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralInfoCard(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 420;
    final isPaid = widget.invoice.isPaid || widget.invoice.status == 'paid';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPaid)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: AppTheme.radiusSm,
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hóa đơn đã thanh toán. Theo chuẩn mực kế toán, số liệu đã hạch toán là bất biến. Để điều chỉnh, vui lòng tạo Phiếu giảm trừ (Credit Note).',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppTheme.radiusSm,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Thông tin chung',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: AppTheme.radiusSm,
              border: Border.all(color: AppTheme.border),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.apartment_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Căn hộ: ${widget.invoice.apartment?.code ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (widget.invoice.apartment?.area != null)
                  Text(
                    '${widget.invoice.apartment!.area} m²',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (isCompact) ...[
            TextFormField(
              controller: _periodController,
              enabled: !isPaid,
              decoration: const InputDecoration(
                labelText: 'Kỳ hóa đơn',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                hintText: 'MM/yyyy (VD: 09/2026)',
              ),
              validator: validateInvoicePeriod,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: isPaid ? null : _selectDueDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Hạn thanh toán',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(_dateFormat.format(_dueDate)),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _periodController,
                    enabled: !isPaid,
                    decoration: const InputDecoration(
                      labelText: 'Kỳ hóa đơn',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      hintText: 'MM/yyyy (VD: 09/2026)',
                    ),
                    validator: validateInvoicePeriod,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: isPaid ? null : _selectDueDate,
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
          ],
          const SizedBox(height: 14),
          if (isPaid)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Trạng thái hóa đơn',
                prefixIcon: Icon(Icons.check_circle_rounded, color: AppTheme.success),
              ),
              child: const Text('Đã thanh toán (Khóa sổ kế toán)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
            )
          else
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Trạng thái hóa đơn',
                prefixIcon: Icon(Icons.info_outline),
              ),
              initialValue: _status,
              items: const [
                DropdownMenuItem(
                  value: 'unpaid',
                  child: Text('Chưa thanh toán'),
                ),
                DropdownMenuItem(
                  value: 'pending_confirmation',
                  child: Text('Chờ xác nhận'),
                ),
                DropdownMenuItem(
                  value: 'cancelled',
                  child: Text('Đã hủy'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFeeItemsCard(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 420;
    final isPaid = widget.invoice.isPaid;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text(
                'Chi tiết các khoản phí',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: _addNewItem,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Thêm phí'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: item.feeTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Tên loại phí',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Nhập tên loại phí'
                                  : null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.error,
                          size: 20,
                        ),
                        tooltip: 'Xóa khoản phí',
                        onPressed: () => _removeItem(idx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isCompact) ...[
                    TextFormField(
                      controller: item.unitPriceController,
                      enabled: !isPaid,
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoneyInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Đơn giá (đ)',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      validator: (val) =>
                          parseMoney(val ?? '') <= 0 ? 'Vui lòng nhập đơn giá' : null,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: item.quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Số lượng',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      validator: (val) => validateNonNegativeNumber(
                        val,
                        'Số lượng',
                        true,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Thành tiền:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(item.subtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: item.unitPriceController,
                            enabled: !isPaid,
                            keyboardType: TextInputType.number,
                            inputFormatters: [MoneyInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Đơn giá (đ)',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            validator: (val) =>
                                parseMoney(val ?? '') <= 0 ? 'Vui lòng nhập đơn giá' : null,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: item.quantityController,
                            enabled: !isPaid,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Số lượng',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            validator: (val) => validateNonNegativeNumber(
                              val,
                              'Số lượng',
                              true,
                            ),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Thành tiền',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _currencyFormat.format(item.subtotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalAndSubmitCard() {
    final isPaid = widget.invoice.isPaid || widget.invoice.status == 'paid';

    return AppCard(
      color: AppTheme.primary.withValues(alpha: 0.05),
      borderColor: AppTheme.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text(
                'TỔNG CỘNG MỚI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.primary,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _currencyFormat.format(_totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isPaid ? Colors.grey.shade400 : AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusMd,
              ),
            ),
            onPressed: (_isSubmitting || isPaid) ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isPaid ? 'HÓA ĐƠN ĐÃ KHÓA SỔ (BẤT BIẾN)' : 'LƯU THAY ĐỔI',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
