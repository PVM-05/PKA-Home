import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/utility_fee_calculator.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../../../data/providers/fee_schedule_provider.dart';
import '../../../data/models/apartment_model.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );

  ApartmentModel? _selectedApartment;
  String? _selectedBuilding;
  final _periodController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 5));

  // Tiền quản lý
  final _managementPriceController = TextEditingController(text: '16.500');

  // Tiền điện
  final _elecQtyController = TextEditingController();
  final _elecPriceController = TextEditingController(text: '3.500');
  bool _isTieredElectricity = false; // true: EVN 6 bậc, false: Đơn giá cố định

  // Tiền nước
  final _waterQtyController = TextEditingController();
  final _waterPriceController = TextEditingController(text: '18.000');

  // Phí gửi xe (Theo quy định tòa nhà: 100.000đ/xe máy, 1.200.000đ/ô tô)
  final _motorbikeQtyController = TextEditingController();
  final _carQtyController = TextEditingController();

  double _motorbikeFee = AppConstants.kMotorbikeFee;
  double _carFee = AppConstants.kCarFee;
  bool _hasLoadedRates = false;
  bool _isFixedRent = false;
  bool _isDraft = false; // true: Lưu nháp (pending), false: Phát hành ngay (unpaid)

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodController.text =
        '${now.month.toString().padLeft(2, '0')}/${now.year}';

    // Thêm listener để tự động tính lại tổng khi có thay đổi
    _managementPriceController.addListener(_updateState);
    _elecQtyController.addListener(_updateState);
    _elecPriceController.addListener(_updateState);
    _waterQtyController.addListener(_updateState);
    _waterPriceController.addListener(_updateState);
    _motorbikeQtyController.addListener(_updateState);
    _carQtyController.addListener(_updateState);
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
    _motorbikeQtyController.dispose();
    _carQtyController.dispose();
    super.dispose();
  }

  double _getManagementTotal() {
    final price = parseMoney(_managementPriceController.text).toDouble();
    if (_isFixedRent) {
      return price;
    }
    final area = _selectedApartment?.area ?? 0.0;
    return area * price;
  }

  double _getElecTotal() {
    final qty = double.tryParse(_elecQtyController.text) ?? 0.0;
    if (_isTieredElectricity) {
      if (qty <= 0) return 0.0;
      final result = UtilityFeeCalculator.calculateElectricityEVN6Tiers(qty);
      return result.totalAmount.toDouble();
    }
    final price = parseMoney(_elecPriceController.text).toDouble();
    return qty * price;
  }

  double _getWaterTotal() {
    final qty = double.tryParse(_waterQtyController.text) ?? 0.0;
    final price = parseMoney(_waterPriceController.text).toDouble();
    return qty * price;
  }

  void _applyFeeRates(Map<String, double> rates) {
    if (rates.containsKey('management')) {
      _managementPriceController.text = formatMoney(rates['management']!.round());
    }
    if (rates.containsKey('electricity')) {
      _elecPriceController.text = formatMoney(rates['electricity']!.round());
    }
    if (rates.containsKey('water')) {
      _waterPriceController.text = formatMoney(rates['water']!.round());
    }
    if (rates.containsKey('parking_motorcycle')) {
      _motorbikeFee = rates['parking_motorcycle']!;
    }
    if (rates.containsKey('parking_car')) {
      _carFee = rates['parking_car']!;
    }
    if (mounted) setState(() {});
  }

  double _getMotorbikeTotal() {
    final qty = double.tryParse(_motorbikeQtyController.text) ?? 0.0;
    return qty * _motorbikeFee;
  }

  double _getCarTotal() {
    final qty = double.tryParse(_carQtyController.text) ?? 0.0;
    return qty * _carFee;
  }

  double _getParkingTotal() => _getMotorbikeTotal() + _getCarTotal();

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
        const SnackBar(
          content: Text('Vui lòng chọn căn hộ'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final items = <Map<String, dynamic>>[];

      // Phí quản lý / Tiền thuê phòng
      if (_getManagementTotal() > 0) {
        items.add({
          'fee_type': _isFixedRent ? 'rent' : 'management',
          'unit_price': _isFixedRent
              ? _getManagementTotal()
              : parseMoney(_managementPriceController.text),
          'quantity': _isFixedRent ? 1.0 : (_selectedApartment!.area ?? 0),
        });
      }

      // Phí điện (Đơn giá phẳng hoặc EVN 6 bậc)
      final elecQty = double.tryParse(_elecQtyController.text) ?? 0;
      if (elecQty > 0) {
        final double elecUnitPrice;
        if (_isTieredElectricity) {
          final totalElec = _getElecTotal();
          elecUnitPrice = (totalElec / elecQty).roundToDouble();
        } else {
          elecUnitPrice = parseMoney(_elecPriceController.text).toDouble();
        }

        items.add({
          'fee_type': 'electricity',
          'unit_price': elecUnitPrice,
          'quantity': elecQty,
        });
      }

      // Phí nước
      final waterQty = double.tryParse(_waterQtyController.text) ?? 0;
      if (waterQty > 0) {
        items.add({
          'fee_type': 'water',
          'unit_price': parseMoney(_waterPriceController.text),
          'quantity': waterQty,
        });
      }

      // Phí gửi xe máy
      final mbQty = double.tryParse(_motorbikeQtyController.text) ?? 0;
      if (mbQty > 0) {
        items.add({
          'fee_type': 'parking_motorbike',
          'unit_price': _motorbikeFee,
          'quantity': mbQty,
        });
      }

      // Phí gửi ô tô
      final carQty = double.tryParse(_carQtyController.text) ?? 0;
      if (carQty > 0) {
        items.add({
          'fee_type': 'parking_car',
          'unit_price': _carFee,
          'quantity': carQty,
        });
      }

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hóa đơn phải có ít nhất 1 loại phí > 0'),
            backgroundColor: AppTheme.warning,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      await ref.read(managementRepositoryProvider).createInvoice(
            _selectedApartment!.id,
            _periodController.text.trim(),
            _dueDate,
            items,
            status: _isDraft ? 'pending' : 'unpaid',
          );

      ref.invalidate(invoicesProvider); // Làm mới danh sách hóa đơn

      if (mounted) {
        final successMsg = _isDraft
            ? 'Đã lưu bản nháp hóa đơn thành công (Chờ soát xét, chưa phát hành cho cư dân)!'
            : 'Lập và phát hành hóa đơn thành công!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
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
    ref.listen<AsyncValue<Map<String, double>>>(feeScheduleMapProvider, (
      prev,
      next,
    ) {
      next.whenData((rates) {
        if (!_hasLoadedRates) {
          _hasLoadedRates = true;
          _applyFeeRates(rates);
        }
      });
    });

    final feeRatesAsync = ref.watch(feeScheduleMapProvider);
    if (!_hasLoadedRates &&
        feeRatesAsync.hasValue &&
        feeRatesAsync.value != null) {
      _hasLoadedRates = true;
      _applyFeeRates(feeRatesAsync.value!);
    }

    final apartmentsAsync = ref.watch(apartmentsProvider);
    final total = _getManagementTotal() +
        _getElecTotal() +
        _getWaterTotal() +
        _getParkingTotal();

    return RoleGuard(
      permission: AppPermissions.invoiceManagement,
      child: Scaffold(
        appBar: AppBar(title: const Text('Lập hóa đơn mới')),
        body: SafeArea(
          child: apartmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: AppErrorCard(
                error: err,
                onRetry: () => ref.invalidate(apartmentsProvider),
              ),
            ),
            data: (apartments) {
              final occupiedApartments =
                  apartments.where((a) => !a.isEmpty).toList();
              final buildings = occupiedApartments
                  .map((a) => a.buildingCode.toUpperCase())
                  .where((b) => b.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

              if (_selectedBuilding == null && buildings.isNotEmpty) {
                _selectedBuilding = buildings.first;
              }

              final displayedApartments = occupiedApartments
                  .where(
                    (a) =>
                        _selectedBuilding == null ||
                        a.buildingCode.toUpperCase() == _selectedBuilding,
                  )
                  .toList()
                ..sort((a, b) => a.code.compareTo(b.code));

              final currentSelectedApartment =
                  displayedApartments.contains(_selectedApartment)
                      ? _selectedApartment
                      : null;

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
                                // Cột trái: Thông tin căn hộ & Tổng cộng
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildGeneralInfoCard(
                                        occupiedApartments,
                                        buildings,
                                        displayedApartments,
                                        currentSelectedApartment,
                                        constraints,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildSummaryAndSubmitCard(total),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Cột phải: Các khoản mục phí chi tiết
                                Expanded(
                                  flex: 7,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildManagementFeeCard(constraints),
                                      const SizedBox(height: 16),
                                      _buildElectricityFeeCard(constraints),
                                      const SizedBox(height: 16),
                                      _buildWaterFeeCard(constraints),
                                      const SizedBox(height: 16),
                                      _buildParkingFeeCard(constraints),
                                    ],
                                  ),
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
                              _buildGeneralInfoCard(
                                occupiedApartments,
                                buildings,
                                displayedApartments,
                                currentSelectedApartment,
                                constraints,
                              ),
                              const SizedBox(height: 16),
                              _buildManagementFeeCard(constraints),
                              const SizedBox(height: 16),
                              _buildElectricityFeeCard(constraints),
                              const SizedBox(height: 16),
                              _buildWaterFeeCard(constraints),
                              const SizedBox(height: 16),
                              _buildParkingFeeCard(constraints),
                              const SizedBox(height: 24),
                              _buildSummaryAndSubmitCard(total),
                              const SizedBox(height: 40),
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

  Widget _buildGeneralInfoCard(
    List<ApartmentModel> occupiedApartments,
    List<String> buildings,
    List<ApartmentModel> displayedApartments,
    ApartmentModel? currentSelectedApartment,
    BoxConstraints constraints,
  ) {
    final isCompact = constraints.maxWidth < 420;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppTheme.radiusSm,
                ),
                child: const Icon(
                  Icons.apartment_rounded,
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
          if (occupiedApartments.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningBackground,
                borderRadius: AppTheme.radiusSm,
                border: Border.all(color: AppTheme.warningBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.warningText,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Không có căn hộ nào đang có người ở. Vui lòng kiểm tra lại danh sách cư dân.',
                      style: TextStyle(
                        color: AppTheme.warningText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (buildings.isNotEmpty) ...[
              const Text(
                'Chọn Tòa nhà:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: buildings.map((b) {
                    final isSelected = _selectedBuilding == b;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(
                          'Tòa $b',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.background,
                        onSelected: (selected) {
                          if (selected && _selectedBuilding != b) {
                            setState(() {
                              _selectedBuilding = b;
                              _selectedApartment = null;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<ApartmentModel>(
              key: ValueKey(_selectedBuilding),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Chọn Căn hộ',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              initialValue: currentSelectedApartment,
              items: displayedApartments.map((apt) {
                return DropdownMenuItem(
                  value: apt,
                  child: Text(
                    '${apt.code} (${apt.area ?? 0} m²)',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) async {
                setState(() {
                  _selectedApartment = val;
                  if (val != null &&
                      val.rentPrice != null &&
                      val.rentPrice! > 0) {
                    _isFixedRent = true;
                    _managementPriceController.text =
                        val.rentPrice!.toInt().toString();
                  }
                });
                if (val != null) {
                  try {
                    final counts = await ref
                        .read(vehicleRepositoryProvider)
                        .getVehicleCounts(val.id);
                    final motorbikes = counts['motorbike'] ?? 0;
                    final cars = counts['car'] ?? 0;
                    _motorbikeQtyController.text =
                        motorbikes > 0 ? motorbikes.toString() : '';
                    _carQtyController.text =
                        cars > 0 ? cars.toString() : '';
                    if (mounted) setState(() {});
                  } catch (_) {}
                }
              },
              validator: (val) =>
                  val == null ? 'Vui lòng chọn căn hộ' : null,
            ),
          ],
          if (_selectedApartment != null &&
              !_isFixedRent &&
              (_selectedApartment!.area == null ||
                  _selectedApartment!.area! <= 0)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningBackground,
                borderRadius: AppTheme.radiusSm,
                border: Border.all(color: AppTheme.warningBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.warningText,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Căn hộ này chưa có diện tích (0 m²). Tiền phí quản lý sẽ bằng 0 đ.',
                      style: TextStyle(
                        color: AppTheme.warningText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (isCompact) ...[
            TextFormField(
              controller: _periodController,
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
              onTap: () => _selectDueDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Hạn thanh toán',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_dueDate)),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _periodController,
                    decoration: const InputDecoration(
                      labelText: 'Kỳ hóa đơn',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      hintText: 'MM/yyyy (VD: 09/2026)',
                    ),
                    validator: validateInvoicePeriod,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDueDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hạn thanh toán',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_dueDate)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManagementFeeCard(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 420;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                _isFixedRent ? 'Tiền thuê phòng' : 'Phí quản lý',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _currencyFormat.format(_getManagementTotal()),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: const Text('Theo diện tích m²'),
                  selected: !_isFixedRent,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isFixedRent = false;
                        _managementPriceController.text = '16.500';
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: const Text('Tiền phòng cố định'),
                  selected: _isFixedRent,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isFixedRent = true;
                        if (_selectedApartment?.rentPrice != null &&
                            _selectedApartment!.rentPrice! > 0) {
                          _managementPriceController.text =
                              formatMoney(_selectedApartment!.rentPrice!.round());
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isCompact) ...[
            TextFormField(
              initialValue: _isFixedRent
                  ? '1 phòng'
                  : (_selectedApartment?.area?.toString() ?? '0'),
              readOnly: true,
              key: ValueKey('${_selectedApartment?.id}_$_isFixedRent'),
              decoration: InputDecoration(
                labelText: _isFixedRent ? 'Số lượng' : 'Diện tích (m²)',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _managementPriceController,
              decoration: InputDecoration(
                labelText: _isFixedRent
                    ? 'Tiền thuê (đ/tháng)'
                    : 'Đơn giá (đ/m²)',
                suffixText: 'đ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              validator: (v) => (v == null || parseMoney(v) <= 0)
                  ? 'Vui lòng nhập ${_isFixedRent ? "tiền thuê phòng" : "đơn giá quản lý"} hợp lệ'
                  : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _isFixedRent
                        ? '1 phòng'
                        : (_selectedApartment?.area?.toString() ?? '0'),
                    readOnly: true,
                    key: ValueKey('${_selectedApartment?.id}_$_isFixedRent'),
                    decoration: InputDecoration(
                      labelText: _isFixedRent ? 'Số lượng' : 'Diện tích (m²)',
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _managementPriceController,
                    decoration: InputDecoration(
                      labelText: _isFixedRent
                          ? 'Tiền thuê (đ/tháng)'
                          : 'Đơn giá (đ/m²)',
                      suffixText: 'đ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    validator: (v) => (v == null || parseMoney(v) <= 0)
                        ? 'Vui lòng nhập ${_isFixedRent ? "tiền thuê phòng" : "đơn giá quản lý"} hợp lệ'
                        : null,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildElectricityFeeCard(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 420;
    final elecQty = double.tryParse(_elecQtyController.text) ?? 0.0;
    final tieredResult = _isTieredElectricity && elecQty > 0
        ? UtilityFeeCalculator.calculateElectricityEVN6Tiers(elecQty)
        : null;

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
                'Tiền điện',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _currencyFormat.format(_getElecTotal()),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: const Text('Đơn giá phẳng'),
                  selected: !_isTieredElectricity,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _isTieredElectricity = false);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: const Text('Biểu giá EVN 6 bậc'),
                  selected: _isTieredElectricity,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _isTieredElectricity = true);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isTieredElectricity) ...[
            TextFormField(
              controller: _elecQtyController,
              decoration: const InputDecoration(
                labelText: 'Số điện tiêu thụ (kWh)',
                suffixText: 'kWh',
                prefixIcon: Icon(Icons.bolt),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => validateNonNegativeNumber(v, 'Số điện'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 6),
                      Text(
                        'Tính tự động theo biểu giá điện sinh hoạt 6 bậc EVN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (tieredResult != null && tieredResult.breakdown.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...tieredResult.breakdown.map((b) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${b.name}: ${b.formattedUnits} kWh × ${_currencyFormat.format(b.rate)}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              Text(
                                _currencyFormat.format(b.amount),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ] else if (isCompact) ...[
            TextFormField(
              controller: _elecQtyController,
              decoration: const InputDecoration(
                labelText: 'Số điện tiêu thụ (kWh)',
                suffixText: 'kWh',
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  validateNonNegativeNumber(v, 'Số điện'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _elecPriceController,
              decoration: const InputDecoration(
                labelText: 'Đơn giá (đ/kWh)',
                suffixText: 'đ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              validator: (v) => (v == null || parseMoney(v) <= 0)
                  ? 'Vui lòng nhập đơn giá điện hợp lệ'
                  : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _elecQtyController,
                    decoration: const InputDecoration(
                      labelText: 'Số điện tiêu thụ (kWh)',
                      suffixText: 'kWh',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        validateNonNegativeNumber(v, 'Số điện'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _elecPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Đơn giá (đ/kWh)',
                      suffixText: 'đ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    validator: (v) => (v == null || parseMoney(v) <= 0)
                        ? 'Vui lòng nhập đơn giá điện hợp lệ'
                        : null,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaterFeeCard(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 420;

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
                'Tiền nước',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _currencyFormat.format(_getWaterTotal()),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isCompact) ...[
            TextFormField(
              controller: _waterQtyController,
              decoration: const InputDecoration(
                labelText: 'Số khối nước (m³)',
                suffixText: 'm³',
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  validateNonNegativeNumber(v, 'Số khối nước'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _waterPriceController,
              decoration: const InputDecoration(
                labelText: 'Đơn giá (đ/m³)',
                suffixText: 'đ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              validator: (v) => (v == null || parseMoney(v) <= 0)
                  ? 'Vui lòng nhập đơn giá nước hợp lệ'
                  : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _waterQtyController,
                    decoration: const InputDecoration(
                      labelText: 'Số khối nước (m³)',
                      suffixText: 'm³',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        validateNonNegativeNumber(v, 'Số khối nước'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _waterPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Đơn giá (đ/m³)',
                      suffixText: 'đ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    validator: (v) => (v == null || parseMoney(v) <= 0)
                        ? 'Vui lòng nhập đơn giá nước hợp lệ'
                        : null,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParkingFeeCard(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 420;

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
                'Phí gửi xe',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _currencyFormat.format(_getParkingTotal()),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isCompact) ...[
            TextFormField(
              controller: _motorbikeQtyController,
              decoration: InputDecoration(
                labelText:
                    'Số xe máy (${_currencyFormat.format(_motorbikeFee)}/xe)',
                prefixIcon: const Icon(Icons.two_wheeler_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  validateNonNegativeInt(v, 'Số xe máy'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _carQtyController,
              decoration: InputDecoration(
                labelText:
                    'Số ô tô (${_currencyFormat.format(_carFee)}/xe)',
                prefixIcon: const Icon(Icons.directions_car_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  validateNonNegativeInt(v, 'Số ô tô'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _motorbikeQtyController,
                    decoration: InputDecoration(
                      labelText:
                          'Số xe máy (${_currencyFormat.format(_motorbikeFee)}/xe)',
                      prefixIcon: const Icon(Icons.two_wheeler_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        validateNonNegativeInt(v, 'Số xe máy'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _carQtyController,
                    decoration: InputDecoration(
                      labelText:
                          'Số ô tô (${_currencyFormat.format(_carFee)}/xe)',
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        validateNonNegativeInt(v, 'Số ô tô'),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Hệ thống tự động điền số xe theo dữ liệu đăng ký phương tiện của căn hộ.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndSubmitCard(double total) {
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
                'TỔNG CỘNG',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _currencyFormat.format(total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Tùy chọn trạng thái hóa đơn
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trạng thái phát hành:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Phát hành ngay'),
                        selected: !_isDraft,
                        onSelected: (val) {
                          if (val) setState(() => _isDraft = false);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.drafts_outlined, size: 16),
                        label: const Text('Lưu bản nháp'),
                        selected: _isDraft,
                        onSelected: (val) {
                          if (val) setState(() => _isDraft = true);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isDraft
                      ? 'Bản nháp được lưu để soát xét nội bộ, cư dân chưa nhìn thấy hóa đơn này.'
                      : 'Hóa đơn sẽ được phát hành ngay lập tức tới cư dân kèm thông báo thanh toán.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _isDraft ? Colors.blueGrey.shade700 : AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.radiusMd,
              ),
            ),
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isDraft ? 'LƯU BẢN NHÁP HÓA ĐƠN' : 'XÁC NHẬN PHÁT HÀNH HÓA ĐƠN',
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
