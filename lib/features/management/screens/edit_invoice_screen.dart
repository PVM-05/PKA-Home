import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/invoice_fee_helper.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/invoice_items_provider.dart';
import '../../../data/providers/management_provider.dart';

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
  }) : feeTypeController = TextEditingController(text: feeName),
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
  bool _hasModified = false;

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
    _hasModified = true;
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
    if (widget.invoice.isPaid || widget.invoice.status == 'paid') return;
    setState(() {
      _hasModified = true;
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
    if (widget.invoice.isPaid || widget.invoice.status == 'paid') return;
    if (_items.length <= 1) {
      AppSnackBar.showWarning(
        context,
        'Hóa đơn phải có ít nhất một khoản phí.',
      );
      return;
    }
    setState(() {
      _hasModified = true;
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
      setState(() {
        _hasModified = true;
        _dueDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Vui lòng thêm ít nhất một khoản phí.',
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
        AppSnackBar.showWarning(
          context,
          'Tên loại phí không được để trống.',
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
      await ref
          .read(managementRepositoryProvider)
          .updateInvoice(
            invoiceId: widget.invoice.id,
            period: _periodController.text.trim(),
            dueDate: _dueDate,
            status: _status,
            items: formattedItems,
          );

      ref.invalidate(invoicesProvider);
      ref.invalidate(invoiceDetailProvider(widget.invoice.id));

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Cập nhật hóa đơn thành công!');
        Navigator.of(context).pop(true);
      }
    } on PostgrestException catch (pe) {
      if (mounted) {
        final isDuplicate =
            pe.code == '23505' ||
            pe.message.contains('uq_invoice_apartment_period') ||
            (pe.details?.toString().contains('uq_invoice_apartment_period') ??
                false);
        final errorText = isDuplicate
            ? 'Hóa đơn kỳ này đã tồn tại cho căn hộ đã chọn.'
            : formatErrorMessage(pe);
        AppSnackBar.showError(context, errorText);
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        final isDuplicate =
            errorStr.contains('23505') ||
            errorStr.contains('uq_invoice_apartment_period');
        final errorText = isDuplicate
            ? 'Hóa đơn kỳ này đã tồn tại cho căn hộ đã chọn.'
            : formatErrorMessage(e);
        AppSnackBar.showError(context, errorText);
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
      child: AppUnsavedChangesGuard(
        hasUnsavedChanges: _hasModified && !_isSubmitting,
        child: Scaffold(
          appBar: AppBar(title: Text('Sửa Hóa đơn ${widget.invoice.period}')),
          body: SafeArea(
            child: detailAsync.when(
              loading: () => ListView(
                padding: AppSpacing.p16,
                children: [
                  AppSkeletonShimmer.cardList(count: 4, itemHeight: 120),
                ],
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: AppSpacing.p16,
                  child: AppErrorCard(
                    error: err,
                    onRetry: () => ref.invalidate(
                      invoiceDetailProvider(widget.invoice.id),
                    ),
                  ),
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
                              padding: AppSpacing.p24,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildGeneralInfoCard(constraints),
                                        AppSpacing.h20,
                                        _buildTotalAndSubmitCard(),
                                      ],
                                    ),
                                  ),
                                  AppSpacing.w24,
                                  Expanded(
                                    flex: 7,
                                    child: _buildFeeItemsCard(constraints),
                                  ),
                                ],
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            padding: AppSpacing.p16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildGeneralInfoCard(constraints),
                                AppSpacing.h16,
                                _buildFeeItemsCard(constraints),
                                AppSpacing.h20,
                                _buildTotalAndSubmitCard(),
                                AppSpacing.h32,
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
      ),
    );
  }

  Widget _buildGeneralInfoCard(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 420;
    final isPaid = widget.invoice.isPaid || widget.invoice.status == 'paid';
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    final successColor = AppTheme.getSemanticSuccess(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPaid)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: warningColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.r8,
                border: Border.all(color: warningColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_rounded, color: warningColor, size: 22),
                  AppSpacing.w10,
                  Expanded(
                    child: Text(
                      'Hóa đơn đã thanh toán. Theo chuẩn mực kế toán, số liệu đã hạch toán là bất biến. Để điều chỉnh, vui lòng tạo Phiếu giảm trừ (Credit Note).',
                      style: context.bodySmall?.copyWith(
                        color: warningColor,
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
                padding: AppSpacing.p8,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r8,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              AppSpacing.w10,
              Expanded(
                child: Text(
                  'Thông tin chung',
                  style: context.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h16,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: AppRadius.r8,
              border: Border.all(color: colorScheme.outlineVariant),
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
                    Icon(
                      Icons.apartment_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    AppSpacing.w8,
                    Flexible(
                      child: Text(
                        'Căn hộ: ${widget.invoice.apartment?.code ?? 'N/A'}',
                        style: context.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold)
                            .tabularFigures(),
                      ),
                    ),
                  ],
                ),
                if (widget.invoice.apartment?.area != null)
                  Text(
                    '${widget.invoice.apartment!.area} m²',
                    style: context.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)
                        .tabularFigures(),
                  ),
              ],
            ),
          ),
          AppSpacing.h16,
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
            AppSpacing.h12,
            InkWell(
              borderRadius: AppRadius.r8,
              onTap: isPaid ? null : _selectDueDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Hạn thanh toán',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _dateFormat.format(_dueDate),
                  style: context.bodyMedium?.tabularFigures(),
                ),
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
                AppSpacing.w12,
                Expanded(
                  child: InkWell(
                    borderRadius: AppRadius.r8,
                    onTap: isPaid ? null : _selectDueDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hạn thanh toán',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(
                        _dateFormat.format(_dueDate),
                        style: context.bodyMedium?.tabularFigures(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          AppSpacing.h16,
          if (isPaid)
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Trạng thái hóa đơn',
                prefixIcon: Icon(
                  Icons.check_circle_rounded,
                  color: successColor,
                ),
              ),
              child: Text(
                'Đã thanh toán (Khóa sổ kế toán)',
                style: context.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: successColor,
                ),
              ),
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
                DropdownMenuItem(value: 'cancelled', child: Text('Đã hủy')),
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
    final isPaid = widget.invoice.isPaid || widget.invoice.status == 'paid';
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Chi tiết các khoản phí',
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: isPaid ? null : _addNewItem,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Thêm phí'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: AppRadius.r8,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: item.feeTypeController,
                          enabled: !isPaid,
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
                        icon: Icon(
                          Icons.delete_outline,
                          color: isPaid
                              ? colorScheme.onSurface.withValues(alpha: 0.38)
                              : errorColor,
                          size: 20,
                        ),
                        tooltip: 'Xóa khoản phí',
                        onPressed: isPaid ? null : () => _removeItem(idx),
                      ),
                    ],
                  ),
                  AppSpacing.h12,
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
                      validator: (val) => parseMoney(val ?? '') <= 0
                          ? 'Vui lòng nhập đơn giá'
                          : null,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    AppSpacing.h8,
                    TextFormField(
                      controller: item.quantityController,
                      enabled: !isPaid,
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
                      validator: (val) =>
                          validateNonNegativeNumber(val, 'Số lượng', true),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    AppSpacing.h8,
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          'Thành tiền:',
                          style: context.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(item.subtotal),
                          style: context.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              )
                              .tabularFigures(),
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
                            validator: (val) => parseMoney(val ?? '') <= 0
                                ? 'Vui lòng nhập đơn giá'
                                : null,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          ),
                        ),
                        AppSpacing.w8,
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: item.quantityController,
                            enabled: !isPaid,
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
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          ),
                        ),
                        AppSpacing.w8,
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Thành tiền',
                                style: context.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _currencyFormat.format(item.subtotal),
                                  style: context.labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      )
                                      .tabularFigures(),
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
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      color: colorScheme.primary.withValues(alpha: 0.06),
      borderColor: colorScheme.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'TỔNG CỘNG MỚI',
                style: context.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _currencyFormat.format(_totalAmount),
                  style: context.headlineMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      )
                      .tabularFigures(),
                ),
              ),
            ],
          ),
          AppSpacing.h16,
          const Divider(height: 1),
          AppSpacing.h16,
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isPaid
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.primary,
              foregroundColor: isPaid
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
            ),
            onPressed: (_isSubmitting || isPaid) ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    isPaid ? 'HÓA ĐƠN ĐÃ KHÓA SỔ (BẤT BIẾN)' : 'LƯU THAY ĐỔI',
                    textAlign: TextAlign.center,
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPaid
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
