import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/utils/utility_fee_calculator.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/apartment_model.dart';

/// Thẻ nhập Phí quản lý hoặc Tiền thuê phòng cố định.
class CreateInvoiceManagementFeeCard extends StatelessWidget {
  final bool isCompact;
  final bool isFixedRent;
  final ApartmentModel? selectedApartment;
  final TextEditingController managementPriceController;
  final String formattedTotal;
  final ValueChanged<bool> onModeChanged;

  const CreateInvoiceManagementFeeCard({
    super.key,
    required this.isCompact,
    required this.isFixedRent,
    required this.selectedApartment,
    required this.managementPriceController,
    required this.formattedTotal,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                isFixedRent ? 'Tiền thuê phòng' : 'Phí quản lý',
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                formattedTotal,
                style: context.titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    )
                    .tabularFigures(),
              ),
            ],
          ),
          AppSpacing.h12,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Theo diện tích m²'),
                selected: !isFixedRent,
                onSelected: (selected) {
                  if (selected) onModeChanged(false);
                },
              ),
              ChoiceChip(
                label: const Text('Tiền phòng cố định'),
                selected: isFixedRent,
                onSelected: (selected) {
                  if (selected) onModeChanged(true);
                },
              ),
            ],
          ),
          AppSpacing.h12,
          if (isCompact) ...[
            _buildQuantityField(),
            AppSpacing.h12,
            _buildPriceField(),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildQuantityField()),
                AppSpacing.w16,
                Expanded(child: _buildPriceField()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      initialValue: isFixedRent
          ? '1 phòng'
          : (selectedApartment?.area?.toString() ?? '0'),
      readOnly: true,
      key: ValueKey('${selectedApartment?.id}_$isFixedRent'),
      decoration: InputDecoration(
        labelText: isFixedRent ? 'Số lượng' : 'Diện tích (m²)',
        filled: true,
      ),
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: managementPriceController,
      decoration: InputDecoration(
        labelText: isFixedRent ? 'Tiền thuê (đ/tháng)' : 'Đơn giá (đ/m²)',
        suffixText: 'đ',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [MoneyInputFormatter()],
      validator: (v) => (v == null || parseMoney(v) <= 0)
          ? 'Vui lòng nhập ${isFixedRent ? "tiền thuê phòng" : "đơn giá quản lý"} hợp lệ'
          : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}

/// Thẻ nhập Tiền điện (đơn giá phẳng hoặc biểu giá EVN 6 bậc).
class CreateInvoiceElectricityFeeCard extends StatelessWidget {
  final bool isCompact;
  final bool isTieredElectricity;
  final TextEditingController elecQtyController;
  final TextEditingController elecPriceController;
  final NumberFormat currencyFormat;
  final String formattedTotal;
  final ValueChanged<bool> onModeChanged;

  const CreateInvoiceElectricityFeeCard({
    super.key,
    required this.isCompact,
    required this.isTieredElectricity,
    required this.elecQtyController,
    required this.elecPriceController,
    required this.currencyFormat,
    required this.formattedTotal,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    final elecQty = double.tryParse(elecQtyController.text) ?? 0.0;
    final tieredResult = isTieredElectricity && elecQty > 0
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
            runSpacing: 4,
            children: [
              Text(
                'Tiền điện',
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                formattedTotal,
                style: context.titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    )
                    .tabularFigures(),
              ),
            ],
          ),
          AppSpacing.h12,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Đơn giá phẳng'),
                selected: !isTieredElectricity,
                onSelected: (selected) {
                  if (selected) onModeChanged(false);
                },
              ),
              ChoiceChip(
                label: const Text('Biểu giá EVN 6 bậc'),
                selected: isTieredElectricity,
                onSelected: (selected) {
                  if (selected) onModeChanged(true);
                },
              ),
            ],
          ),
          AppSpacing.h12,
          if (isTieredElectricity) ...[
            TextFormField(
              controller: elecQtyController,
              decoration: const InputDecoration(
                labelText: 'Số điện tiêu thụ (kWh)',
                suffixText: 'kWh',
                prefixIcon: Icon(Icons.bolt),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => validateNonNegativeNumber(v, 'Số điện'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            AppSpacing.h12,
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: warningColor.withValues(alpha: 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(color: warningColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: warningColor),
                      AppSpacing.w6,
                      Expanded(
                        child: Text(
                          'Tính tự động theo biểu giá điện sinh hoạt 6 bậc EVN',
                          style: context.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (tieredResult != null &&
                      tieredResult.breakdown.isNotEmpty) ...[
                    AppSpacing.h8,
                    ...tieredResult.breakdown.map(
                      (b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${b.name}: ${b.formattedUnits} kWh × ${currencyFormat.format(b.rate)}',
                                style: context.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    )
                                    .tabularFigures(),
                              ),
                            ),
                            AppSpacing.w8,
                            Text(
                              currencyFormat.format(b.amount),
                              style: context.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)
                                  .tabularFigures(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (isCompact) ...[
            _buildQtyField(),
            AppSpacing.h12,
            _buildPriceField(),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildQtyField()),
                AppSpacing.w16,
                Expanded(child: _buildPriceField()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyField() {
    return TextFormField(
      controller: elecQtyController,
      decoration: const InputDecoration(
        labelText: 'Số điện tiêu thụ (kWh)',
        suffixText: 'kWh',
      ),
      keyboardType: TextInputType.number,
      validator: (v) => validateNonNegativeNumber(v, 'Số điện'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: elecPriceController,
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
    );
  }
}

/// Thẻ nhập Tiền nước.
class CreateInvoiceWaterFeeCard extends StatelessWidget {
  final bool isCompact;
  final TextEditingController waterQtyController;
  final TextEditingController waterPriceController;
  final String formattedTotal;

  const CreateInvoiceWaterFeeCard({
    super.key,
    required this.isCompact,
    required this.waterQtyController,
    required this.waterPriceController,
    required this.formattedTotal,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                'Tiền nước',
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                formattedTotal,
                style: context.titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    )
                    .tabularFigures(),
              ),
            ],
          ),
          AppSpacing.h12,
          if (isCompact) ...[
            _buildQtyField(),
            AppSpacing.h12,
            _buildPriceField(),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildQtyField()),
                AppSpacing.w16,
                Expanded(child: _buildPriceField()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyField() {
    return TextFormField(
      controller: waterQtyController,
      decoration: const InputDecoration(
        labelText: 'Số khối nước (m³)',
        suffixText: 'm³',
      ),
      keyboardType: TextInputType.number,
      validator: (v) => validateNonNegativeNumber(v, 'Số khối nước'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: waterPriceController,
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
    );
  }
}

/// Thẻ nhập Phí gửi xe máy / ô tô (tự động điền từ dữ liệu phương tiện).
class CreateInvoiceParkingFeeCard extends StatelessWidget {
  final bool isCompact;
  final TextEditingController motorbikeQtyController;
  final TextEditingController carQtyController;
  final double motorbikeFee;
  final double carFee;
  final NumberFormat currencyFormat;
  final String formattedTotal;

  const CreateInvoiceParkingFeeCard({
    super.key,
    required this.isCompact,
    required this.motorbikeQtyController,
    required this.carQtyController,
    required this.motorbikeFee,
    required this.carFee,
    required this.currencyFormat,
    required this.formattedTotal,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                'Phí gửi xe',
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                formattedTotal,
                style: context.titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    )
                    .tabularFigures(),
              ),
            ],
          ),
          AppSpacing.h12,
          if (isCompact) ...[
            _buildMotorbikeField(),
            AppSpacing.h12,
            _buildCarField(),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildMotorbikeField()),
                AppSpacing.w16,
                Expanded(child: _buildCarField()),
              ],
            ),
          ],
          AppSpacing.h8,
          Text(
            'Hệ thống tự động điền số xe theo dữ liệu đăng ký phương tiện của căn hộ.',
            style: context.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotorbikeField() {
    return TextFormField(
      controller: motorbikeQtyController,
      decoration: InputDecoration(
        labelText: 'Số xe máy (${currencyFormat.format(motorbikeFee)}/xe)',
        prefixIcon: const Icon(Icons.two_wheeler_outlined),
      ),
      keyboardType: TextInputType.number,
      validator: (v) => validateNonNegativeInt(v, 'Số xe máy'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildCarField() {
    return TextFormField(
      controller: carQtyController,
      decoration: InputDecoration(
        labelText: 'Số ô tô (${currencyFormat.format(carFee)}/xe)',
        prefixIcon: const Icon(Icons.directions_car_outlined),
      ),
      keyboardType: TextInputType.number,
      validator: (v) => validateNonNegativeInt(v, 'Số ô tô'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}

/// Thẻ Tóm tắt tổng tiền, chọn trạng thái phát hành và nút xác nhận.
class CreateInvoiceSummarySubmitCard extends StatelessWidget {
  final String formattedTotal;
  final bool isDraft;
  final bool isSubmitting;
  final ValueChanged<bool> onDraftChanged;
  final VoidCallback onSubmit;

  const CreateInvoiceSummarySubmitCard({
    super.key,
    required this.formattedTotal,
    required this.isDraft,
    required this.isSubmitting,
    required this.onDraftChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
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
                'TỔNG CỘNG',
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formattedTotal,
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
          Container(
            padding: AppSpacing.p12,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: AppRadius.r12,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trạng thái phát hành:',
                  style: context.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                AppSpacing.h8,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Phát hành ngay'),
                      selected: !isDraft,
                      onSelected: (val) {
                        if (val) onDraftChanged(false);
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.drafts_outlined, size: 16),
                      label: const Text('Lưu bản nháp'),
                      selected: isDraft,
                      onSelected: (val) {
                        if (val) onDraftChanged(true);
                      },
                    ),
                  ],
                ),
                AppSpacing.h6,
                Text(
                  isDraft
                      ? 'Bản nháp được lưu để soát xét nội bộ, cư dân chưa nhìn thấy hóa đơn này.'
                      : 'Hóa đơn sẽ được phát hành ngay lập tức tới cư dân kèm thông báo thanh toán.',
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.h16,
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isDraft
                  ? colorScheme.secondary
                  : colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
            ),
            onPressed: isSubmitting ? null : onSubmit,
            child: isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: colorScheme.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isDraft
                        ? 'LƯU BẢN NHÁP HÓA ĐƠN'
                        : 'XÁC NHẬN PHÁT HÀNH HÓA ĐƠN',
                    textAlign: TextAlign.center,
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
