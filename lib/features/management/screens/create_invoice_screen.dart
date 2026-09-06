import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/apartment_model.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  ApartmentModel? _selectedApartment;
  final _periodController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 5));

  // Tiền quản lý
  final _managementPriceController = TextEditingController(text: '16500');
  
  // Tiền điện
  final _elecQtyController = TextEditingController();
  final _elecPriceController = TextEditingController(text: '3500');

  // Tiền nước
  final _waterQtyController = TextEditingController();
  final _waterPriceController = TextEditingController(text: '18000');

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodController.text = '${now.month.toString().padLeft(2, '0')}/${now.year}';
    
    // Thêm listener để tự động tính lại tổng khi có thay đổi
    _managementPriceController.addListener(_updateState);
    _elecQtyController.addListener(_updateState);
    _elecPriceController.addListener(_updateState);
    _waterQtyController.addListener(_updateState);
    _waterPriceController.addListener(_updateState);
  }
  
  void _updateState() {
    setState(() {});
  }

  @override
  void dispose() {
    _periodController.dispose();
    _managementPriceController.dispose();
    _elecQtyController.dispose();
    _elecPriceController.dispose();
    _waterQtyController.dispose();
    _waterPriceController.dispose();
    super.dispose();
  }

  double _getManagementTotal() {
    final area = _selectedApartment?.area ?? 0.0;
    final price = double.tryParse(_managementPriceController.text) ?? 0.0;
    return area * price;
  }

  double _getElecTotal() {
    final qty = double.tryParse(_elecQtyController.text) ?? 0.0;
    final price = double.tryParse(_elecPriceController.text) ?? 0.0;
    return qty * price;
  }

  double _getWaterTotal() {
    final qty = double.tryParse(_waterQtyController.text) ?? 0.0;
    final price = double.tryParse(_waterPriceController.text) ?? 0.0;
    return qty * price;
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn căn hộ'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final items = <Map<String, dynamic>>[];
      
      // Phí quản lý
      if (_getManagementTotal() > 0) {
        items.add({
          'fee_type': 'Phí quản lý',
          'unit_price': double.tryParse(_managementPriceController.text) ?? 0,
          'quantity': _selectedApartment!.area ?? 0,
        });
      }
      
      // Phí điện
      final elecQty = double.tryParse(_elecQtyController.text) ?? 0;
      if (elecQty > 0) {
        items.add({
          'fee_type': 'Tiền điện',
          'unit_price': double.tryParse(_elecPriceController.text) ?? 0,
          'quantity': elecQty,
        });
      }

      // Phí nước
      final waterQty = double.tryParse(_waterQtyController.text) ?? 0;
      if (waterQty > 0) {
        items.add({
          'fee_type': 'Tiền nước',
          'unit_price': double.tryParse(_waterPriceController.text) ?? 0,
          'quantity': waterQty,
        });
      }

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hóa đơn phải có ít nhất 1 loại phí > 0'), backgroundColor: AppTheme.warning),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      await ref.read(managementRepositoryProvider).createInvoice(
        _selectedApartment!.id,
        _periodController.text.trim(),
        _dueDate,
        items,
      );
      
      ref.invalidate(invoicesProvider); // Làm mới danh sách hóa đơn
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lập hóa đơn thành công!'), backgroundColor: AppTheme.success),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lập hóa đơn: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final total = _getManagementTotal() + _getElecTotal() + _getWaterTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lập hóa đơn mới'),
      ),
      body: SafeArea(
        child: apartmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
          data: (apartments) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thông tin chung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<ApartmentModel>(
                              decoration: const InputDecoration(labelText: 'Chọn Căn hộ', prefixIcon: Icon(Icons.apartment_outlined)),
                              initialValue: _selectedApartment,
                              items: apartments.map((apt) {
                                return DropdownMenuItem(
                                  value: apt,
                                  child: Text('${apt.code} (${apt.area ?? 0} m²)'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedApartment = val),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _periodController,
                                    decoration: const InputDecoration(labelText: 'Kỳ hóa đơn', prefixIcon: Icon(Icons.circle)),
                                    validator: (val) => (val == null || val.isEmpty) ? 'Vui lòng nhập kỳ' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectDueDate(context),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(labelText: 'Hạn thanh toán', prefixIcon: Icon(Icons.circle)),
                                      child: Text(DateFormat('dd/MM/yyyy').format(_dueDate)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Phí quản lý
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Phí quản lý', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(_currencyFormat.format(_getManagementTotal()), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _selectedApartment?.area?.toString() ?? '0',
                                    readOnly: true,
                                    key: ValueKey(_selectedApartment?.id), // Để rebuild khi đổi căn hộ
                                    decoration: const InputDecoration(labelText: 'Diện tích (m²)', filled: true),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _managementPriceController,
                                    decoration: const InputDecoration(labelText: 'Đơn giá (đ/m²)'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tiền điện
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tiền điện', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(_currencyFormat.format(_getElecTotal()), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _elecQtyController,
                                    decoration: const InputDecoration(labelText: 'Số điện tiêu thụ (kWh)'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _elecPriceController,
                                    decoration: const InputDecoration(labelText: 'Đơn giá (đ/kWh)'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tiền nước
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tiền nước', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(_currencyFormat.format(_getWaterTotal()), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _waterQtyController,
                                    decoration: const InputDecoration(labelText: 'Số khối nước (m³)'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _waterPriceController,
                                    decoration: const InputDecoration(labelText: 'Đơn giá (đ/m³)'),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tổng cộng
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TỔNG CỘNG', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          Text(_currencyFormat.format(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('XÁC NHẬN LẬP HÓA ĐƠN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
