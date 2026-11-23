import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/utility_fee_calculator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/providers/fee_schedule_provider.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../widgets/invoice/create_invoice_fee_cards.dart';

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
  bool _isTieredElectricity = false;

  // Tiền nước
  final _waterQtyController = TextEditingController();
  final _waterPriceController = TextEditingController(text: '18.000');

  // Phí gửi xe
  final _motorbikeQtyController = TextEditingController();
  final _carQtyController = TextEditingController();

  double _motorbikeFee = AppConstants.kMotorbikeFee;
  double _carFee = AppConstants.kCarFee;
  bool _hasLoadedRates = false;
  bool _isFixedRent = false;
  bool _isDraft = false;
  bool _isSubmitting = false;

  bool get _hasUnsavedChanges =>
      _selectedApartment != null ||
      _periodController.text.trim().isNotEmpty ||
      _elecQtyController.text.trim().isNotEmpty ||
      _waterQtyController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodController.text =
        '${now.month.toString().padLeft(2, '0')}/${now.year}';

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
      _managementPriceController.text = formatMoney(
        rates['management']!.round(),
      );
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
      AppSnackBar.showWarning(context, 'Vui lòng chọn căn hộ');
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
        AppSnackBar.showWarning(
          context,
          'Hóa đơn phải có ít nhất 1 loại phí > 0',
        );
        setState(() => _isSubmitting = false);
        return;
      }

      await ref
          .read(managementRepositoryProvider)
          .createInvoice(
            _selectedApartment!.id,
            _periodController.text.trim(),
            _dueDate,
            items,
            status: _isDraft ? 'pending' : 'unpaid',
          );

      ref.invalidate(invoicesProvider);

      if (mounted) {
        final successMsg = _isDraft
            ? 'Đã lưu bản nháp hóa đơn thành công (Chờ soát xét, chưa phát hành cho cư dân)!'
            : 'Lập và phát hành hóa đơn thành công!';
        AppSnackBar.showSuccess(context, successMsg);
        Navigator.of(context).pop();
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
    final total =
        _getManagementTotal() +
        _getElecTotal() +
        _getWaterTotal() +
        _getParkingTotal();
    final formattedTotal = _currencyFormat.format(total);

    return RoleGuard(
      permission: AppPermissions.invoiceManagement,
      child: AppUnsavedChangesGuard(
        hasUnsavedChanges: _hasUnsavedChanges && !_isSubmitting,
        child: Scaffold(
          appBar: AppBar(title: const Text('Lập hóa đơn mới')),
          body: SafeArea(
            child: apartmentsAsync.when(
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
                    onRetry: () => ref.invalidate(apartmentsProvider),
                  ),
                ),
              ),
              data: (apartments) {
                final occupiedApartments = apartments
                    .where((a) => !a.isEmpty)
                    .toList();
                final buildings =
                    occupiedApartments
                        .map((a) => a.buildingCode.toUpperCase())
                        .where((b) => b.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();

                if (_selectedBuilding == null && buildings.isNotEmpty) {
                  _selectedBuilding = buildings.first;
                }

                final displayedApartments =
                    occupiedApartments
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
                          final isCompact = constraints.maxWidth < 420;

                          final managementCard =
                              CreateInvoiceManagementFeeCard(
                                isCompact: isCompact,
                                isFixedRent: _isFixedRent,
                                selectedApartment: _selectedApartment,
                                managementPriceController:
                                    _managementPriceController,
                                formattedTotal: _currencyFormat.format(
                                  _getManagementTotal(),
                                ),
                                onModeChanged: (isFixed) {
                                  setState(() {
                                    _isFixedRent = isFixed;
                                    if (!isFixed) {
                                      _managementPriceController.text =
                                          '16.500';
                                    } else if (_selectedApartment?.rentPrice !=
                                            null &&
                                        _selectedApartment!.rentPrice! > 0) {
                                      _managementPriceController.text =
                                          formatMoney(
                                            _selectedApartment!.rentPrice!
                                                .round(),
                                          );
                                    }
                                  });
                                },
                              );

                          final electricityCard =
                              CreateInvoiceElectricityFeeCard(
                                isCompact: isCompact,
                                isTieredElectricity: _isTieredElectricity,
                                elecQtyController: _elecQtyController,
                                elecPriceController: _elecPriceController,
                                currencyFormat: _currencyFormat,
                                formattedTotal: _currencyFormat.format(
                                  _getElecTotal(),
                                ),
                                onModeChanged: (isTiered) {
                                  setState(
                                    () => _isTieredElectricity = isTiered,
                                  );
                                },
                              );

                          final waterCard = CreateInvoiceWaterFeeCard(
                            isCompact: isCompact,
                            waterQtyController: _waterQtyController,
                            waterPriceController: _waterPriceController,
                            formattedTotal: _currencyFormat.format(
                              _getWaterTotal(),
                            ),
                          );

                          final parkingCard = CreateInvoiceParkingFeeCard(
                            isCompact: isCompact,
                            motorbikeQtyController: _motorbikeQtyController,
                            carQtyController: _carQtyController,
                            motorbikeFee: _motorbikeFee,
                            carFee: _carFee,
                            currencyFormat: _currencyFormat,
                            formattedTotal: _currencyFormat.format(
                              _getParkingTotal(),
                            ),
                          );

                          final summaryCard = CreateInvoiceSummarySubmitCard(
                            formattedTotal: formattedTotal,
                            isDraft: _isDraft,
                            isSubmitting: _isSubmitting,
                            onDraftChanged: (draft) {
                              setState(() => _isDraft = draft);
                            },
                            onSubmit: _submit,
                          );

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
                                        _buildGeneralInfoCard(
                                          occupiedApartments,
                                          buildings,
                                          displayedApartments,
                                          currentSelectedApartment,
                                          isCompact,
                                        ),
                                        AppSpacing.h20,
                                        summaryCard,
                                      ],
                                    ),
                                  ),
                                  AppSpacing.w24,
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        managementCard,
                                        AppSpacing.h16,
                                        electricityCard,
                                        AppSpacing.h16,
                                        waterCard,
                                        AppSpacing.h16,
                                        parkingCard,
                                      ],
                                    ),
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
                                _buildGeneralInfoCard(
                                  occupiedApartments,
                                  buildings,
                                  displayedApartments,
                                  currentSelectedApartment,
                                  isCompact,
                                ),
                                AppSpacing.h16,
                                managementCard,
                                AppSpacing.h16,
                                electricityCard,
                                AppSpacing.h16,
                                waterCard,
                                AppSpacing.h16,
                                parkingCard,
                                AppSpacing.h24,
                                summaryCard,
                                AppSpacing.h40,
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

  Widget _buildGeneralInfoCard(
    List<ApartmentModel> occupiedApartments,
    List<String> buildings,
    List<ApartmentModel> displayedApartments,
    ApartmentModel? currentSelectedApartment,
    bool isCompact,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: AppSpacing.p8,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r8,
                ),
                child: Icon(
                  Icons.apartment_rounded,
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
          if (occupiedApartments.isEmpty)
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: warningColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.r8,
                border: Border.all(color: warningColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: warningColor,
                    size: 20,
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: Text(
                      'Không có căn hộ nào đang có người ở. Vui lòng kiểm tra lại danh sách cư dân.',
                      style: context.bodySmall?.copyWith(
                        color: warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (buildings.isNotEmpty) ...[
              Text(
                'Chọn Tòa nhà:',
                style: context.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.h8,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: buildings.map((b) {
                  final isSelected = _selectedBuilding == b;
                  return ChoiceChip(
                    label: Text(
                      'Tòa $b',
                      style: context.labelMedium?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerLow,
                    onSelected: (selected) {
                      if (selected && _selectedBuilding != b) {
                        setState(() {
                          _selectedBuilding = b;
                          _selectedApartment = null;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              AppSpacing.h12,
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
                    style: context.bodyMedium?.tabularFigures(),
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
                    _managementPriceController.text = val.rentPrice!
                        .toInt()
                        .toString();
                  }
                });
                if (val != null) {
                  try {
                    final counts = await ref
                        .read(vehicleRepositoryProvider)
                        .getVehicleCounts(val.id);
                    final motorbikes = counts['motorbike'] ?? 0;
                    final cars = counts['car'] ?? 0;
                    _motorbikeQtyController.text = motorbikes > 0
                        ? motorbikes.toString()
                        : '';
                    _carQtyController.text = cars > 0 ? cars.toString() : '';
                    if (mounted) setState(() {});
                  } catch (e) {
                    debugPrint(
                      'Không thể tự động tải số lượng xe căn hộ ${val.code}: $e',
                    );
                    if (mounted) {
                      AppSnackBar.showWarning(
                        context,
                        'Không thể tự động nạp số lượng xe của căn hộ ${val.code}. Vui lòng nhập thủ công nếu cần.',
                      );
                    }
                  }
                }
              },
              validator: (val) => val == null ? 'Vui lòng chọn căn hộ' : null,
            ),
          ],
          if (_selectedApartment != null &&
              !_isFixedRent &&
              (_selectedApartment!.area == null ||
                  _selectedApartment!.area! <= 0)) ...[
            AppSpacing.h12,
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: warningColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.r8,
                border: Border.all(color: warningColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: warningColor,
                    size: 20,
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: Text(
                      'Căn hộ này chưa có diện tích (0 m²). Tiền phí quản lý sẽ bằng 0 đ.',
                      style: context.bodySmall?.copyWith(
                        color: warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          AppSpacing.h16,
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
            AppSpacing.h12,
            InkWell(
              borderRadius: AppRadius.r8,
              onTap: () => _selectDueDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Hạn thanh toán',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_dueDate),
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
                    decoration: const InputDecoration(
                      labelText: 'Kỳ hóa đơn',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      hintText: 'MM/yyyy (VD: 09/2026)',
                    ),
                    validator: validateInvoicePeriod,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ),
                AppSpacing.w16,
                Expanded(
                  child: InkWell(
                    borderRadius: AppRadius.r8,
                    onTap: () => _selectDueDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hạn thanh toán',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(_dueDate),
                        style: context.bodyMedium?.tabularFigures(),
                      ),
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
}
