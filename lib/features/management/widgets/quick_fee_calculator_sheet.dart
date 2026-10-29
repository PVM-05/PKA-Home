import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/utility_fee_calculator.dart';
import '../../../data/models/tiered_calculation_result_model.dart';

/// Modal Bottom Sheet công cụ tính nhanh và mô phỏng biểu phí cho Ban Quản Lý
class QuickFeeCalculatorSheet extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const QuickFeeCalculatorSheet({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<QuickFeeCalculatorSheet> createState() => _QuickFeeCalculatorSheetState();
}

class _QuickFeeCalculatorSheetState extends ConsumerState<QuickFeeCalculatorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers Tab 0 - Điện EVN
  final TextEditingController _elecConsumptionController = TextEditingController(text: '150');
  final TextEditingController _elecOldIndexController = TextEditingController();
  final TextEditingController _elecNewIndexController = TextEditingController();
  TieredCalculationResultModel? _elecResult;

  // Controllers Tab 1 - Nước định mức
  final TextEditingController _waterConsumptionController = TextEditingController(text: '20');
  final TextEditingController _waterResidentsController = TextEditingController(text: '4');
  TieredCalculationResultModel? _waterResult;

  // Controllers Tab 2 - Gửi xe pro-rata
  final TextEditingController _parkingMonthlyRateController = TextEditingController(text: '100000');
  final TextEditingController _parkingPeriodController = TextEditingController(text: '2026-10');
  final TextEditingController _parkingStartDayController = TextEditingController(text: '15');
  ProratedFeeResultModel? _parkingResult;

  // Controllers Tab 3 - Lãi phạt trễ hạn
  final TextEditingController _penaltyBaseAmountController = TextEditingController(text: '2000000');
  final TextEditingController _penaltyOverdueDaysController = TextEditingController(text: '10');
  LatePenaltyResultModel? _penaltyResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );

    // Tính toán ban đầu để hiển thị ngay kết quả mẫu trực quan
    _calculateElectricity();
    _calculateWater();
    _calculateParking();
    _calculatePenalty();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _elecConsumptionController.dispose();
    _elecOldIndexController.dispose();
    _elecNewIndexController.dispose();
    _waterConsumptionController.dispose();
    _waterResidentsController.dispose();
    _parkingMonthlyRateController.dispose();
    _parkingPeriodController.dispose();
    _parkingStartDayController.dispose();
    _penaltyBaseAmountController.dispose();
    _penaltyOverdueDaysController.dispose();
    super.dispose();
  }

  void _calculateElectricity() {
    final rawConsumption = double.tryParse(_elecConsumptionController.text.trim()) ?? 0.0;
    setState(() {
      _elecResult = UtilityFeeCalculator.calculateElectricityEVN6Tiers(rawConsumption);
    });
  }

  void _onElectricityIndexChanged() {
    final oldVal = double.tryParse(_elecOldIndexController.text.trim());
    final newVal = double.tryParse(_elecNewIndexController.text.trim());
    if (oldVal != null && newVal != null && newVal >= oldVal) {
      final consumption = newVal - oldVal;
      _elecConsumptionController.text = consumption.toStringAsFixed(0);
      _calculateElectricity();
    }
  }

  void _calculateWater() {
    final rawConsumption = double.tryParse(_waterConsumptionController.text.trim()) ?? 0.0;
    final residents = int.tryParse(_waterResidentsController.text.trim()) ?? 4;
    setState(() {
      _waterResult = UtilityFeeCalculator.calculateWaterQuota(
        consumption: rawConsumption,
        residentCount: residents,
      );
    });
  }

  void _calculateParking() {
    final monthlyRate = double.tryParse(_parkingMonthlyRateController.text.trim()) ?? 100000.0;
    final period = _parkingPeriodController.text.trim().isNotEmpty
        ? _parkingPeriodController.text.trim()
        : '2026-10';
    final startDay = int.tryParse(_parkingStartDayController.text.trim()) ?? 1;

    final parts = period.split('-');
    final year = int.tryParse(parts[0]) ?? 2026;
    final month = parts.length > 1 ? (int.tryParse(parts[1]) ?? 10) : 10;
    final cleanStartDay = startDay.clamp(1, 28);
    final startDate = DateTime(year, month, cleanStartDay);

    setState(() {
      _parkingResult = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: monthlyRate,
        startDate: startDate,
        period: period,
      );
    });
  }

  void _calculatePenalty() {
    final baseAmount = double.tryParse(_penaltyBaseAmountController.text.trim()) ?? 0.0;
    final overdueDays = int.tryParse(_penaltyOverdueDaysController.text.trim()) ?? 0;

    final now = DateTime.now();
    final dueDate = now.subtract(Duration(days: overdueDays));

    setState(() {
      _penaltyResult = UtilityFeeCalculator.calculateLatePaymentPenalty(
        totalAmount: baseAmount,
        dueDate: dueDate,
        asOfDate: now,
        gracePeriodDays: 3,
        penaltyRatePerDay: 0.0005,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Tiêu đề header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: AppTheme.primary, size: 26),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Công Cụ Tính Nhanh Biểu Phí',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Đóng',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Tab bar 4 loại biểu phí
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(
                key: Key('tab_electricity'),
                icon: Icon(Icons.bolt, size: 20),
                text: 'Điện EVN',
              ),
              Tab(
                key: Key('tab_water'),
                icon: Icon(Icons.water_drop, size: 20),
                text: 'Nước',
              ),
              Tab(
                key: Key('tab_parking'),
                icon: Icon(Icons.directions_car, size: 20),
                text: 'Gửi xe',
              ),
              Tab(
                key: Key('tab_penalty'),
                icon: Icon(Icons.warning_amber_rounded, size: 20),
                text: 'Lãi phạt',
              ),
            ],
          ),
          // Nội dung từng tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildElectricityTab(),
                _buildWaterTab(),
                _buildParkingTab(),
                _buildPenaltyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: ĐIỆN EVN 6 BẬC ---
  Widget _buildElectricityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner('Biểu giá điện lũy tiến 6 bậc chuẩn EVN (QĐ 2024).'),
          const SizedBox(height: 16),
          // Nhập sản lượng trực tiếp
          TextField(
            key: const Key('input_electricity_consumption'),
            controller: _elecConsumptionController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Sản lượng điện tiêu thụ (kWh)',
              hintText: 'Nhập số kWh ví dụ: 250',
              prefixIcon: Icon(Icons.electric_meter),
              border: OutlineInputBorder(),
              suffixText: 'kWh',
            ),
            onChanged: (_) => _calculateElectricity(),
          ),
          const SizedBox(height: 12),
          // Tùy chọn nhập chỉ số công tơ Cũ - Mới
          ExpansionTile(
            title: const Text(
              'Tính từ chỉ số công tơ cũ & mới',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            tilePadding: EdgeInsets.zero,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('input_electricity_old_index'),
                      controller: _elecOldIndexController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Chỉ số cũ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _onElectricityIndexChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('input_electricity_new_index'),
                      controller: _elecNewIndexController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Chỉ số mới',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _onElectricityIndexChanged(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const Key('btn_calculate_electricity'),
            onPressed: _calculateElectricity,
            icon: const Icon(Icons.calculate),
            label: const Text('Tính Tiền Điện'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          if (_elecResult != null) ...[
            _buildTotalAmountCard(
              title: 'Tổng tiền điện (chưa VAT):',
              amountText: _elecResult!.formattedTotalAmount,
              subtitle: 'Sản lượng tính: ${_elecResult!.formattedConsumption} kWh',
            ),
            const SizedBox(height: 16),
            const Text(
              'Bảng chi tiết các bậc thang:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTierBreakdownTable(_elecResult!.breakdown, unit: 'kWh'),
          ],
        ],
      ),
    );
  }

  // --- TAB 2: NƯỚC ĐỊNH MỨC ---
  Widget _buildWaterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner('Định mức nước 4 m³/người/tháng. Bậc 1: trong định mức, Bậc 2: vượt cấp 1, Bậc 3: vượt cấp 2.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('input_water_consumption'),
            controller: _waterConsumptionController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Sản lượng nước tiêu thụ (m³)',
              hintText: 'Nhập số khối ví dụ: 25',
              prefixIcon: Icon(Icons.water_drop_outlined),
              border: OutlineInputBorder(),
              suffixText: 'm³',
            ),
            onChanged: (_) => _calculateWater(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('input_water_residents'),
            controller: _waterResidentsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số nhân khẩu đăng ký',
              hintText: 'Mặc định 4 người',
              prefixIcon: Icon(Icons.people_alt_outlined),
              border: OutlineInputBorder(),
              suffixText: 'người',
            ),
            onChanged: (_) => _calculateWater(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('btn_calculate_water'),
            onPressed: _calculateWater,
            icon: const Icon(Icons.calculate),
            label: const Text('Tính Tiền Nước'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          if (_waterResult != null) ...[
            _buildTotalAmountCard(
              title: 'Tổng tiền nước:',
              amountText: _waterResult!.formattedTotalAmount,
              subtitle: 'Định mức áp dụng: ${_waterResult!.baseQuota?.toInt() ?? 0} m³ (${_waterResidentsController.text} nhân khẩu × 4 m³)',
            ),
            const SizedBox(height: 16),
            const Text(
              'Bảng phân bổ định mức & vượt mức:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTierBreakdownTable(_waterResult!.breakdown, unit: 'm³'),
          ],
        ],
      ),
    );
  }

  // --- TAB 3: GỬI XE PRO-RATA ---
  Widget _buildParkingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner('Tính phân bổ phí gửi xe theo số ngày sử dụng thực tế khi đăng ký hoặc hủy giữa tháng.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('input_parking_monthly_rate'),
            controller: _parkingMonthlyRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Đơn giá tháng trọn gói (VNĐ)',
              hintText: 'Ví dụ: 100000',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
              suffixText: 'đ/tháng',
            ),
            onChanged: (_) => _calculateParking(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('input_parking_period'),
            controller: _parkingPeriodController,
            decoration: const InputDecoration(
              labelText: 'Kỳ hóa đơn (YYYY-MM)',
              hintText: 'Ví dụ: 2026-10',
              prefixIcon: Icon(Icons.calendar_month),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calculateParking(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('input_parking_start_day'),
            controller: _parkingStartDayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ngày bắt đầu tính phí trong tháng (1 - 31)',
              hintText: 'Ví dụ: 15',
              prefixIcon: Icon(Icons.today),
              border: OutlineInputBorder(),
              suffixText: 'ngày',
            ),
            onChanged: (_) => _calculateParking(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('btn_calculate_parking'),
            onPressed: _calculateParking,
            icon: const Icon(Icons.calculate),
            label: const Text('Tính Phí Gửi Xe Pro-rata'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          if (_parkingResult != null) ...[
            _buildTotalAmountCard(
              title: 'Thành tiền phân bổ:',
              amountText: _parkingResult!.formattedTotalAmount,
              subtitle: 'Thời gian: ${_parkingResult!.daysUsed}/${_parkingResult!.daysInMonth} ngày (${_parkingResult!.isProrated ? 'Áp dụng pro-rata' : 'Tròn tháng'})',
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSummaryRow('Đơn giá niêm yết:', _parkingResult!.formattedMonthlyRate),
                    const Divider(height: 20),
                    _buildSummaryRow('Số ngày trong tháng:', '${_parkingResult!.daysInMonth} ngày'),
                    const Divider(height: 20),
                    _buildSummaryRow('Số ngày tính phí:', '${_parkingResult!.daysUsed} ngày'),
                    const Divider(height: 20),
                    _buildSummaryRow(
                      'Tỷ lệ pro-rata:',
                      '${((_parkingResult!.daysUsed / _parkingResult!.daysInMonth) * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 4: LÃI PHẠT TRỄ HẠN ---
  Widget _buildPenaltyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner('Thời gian ân hạn: 3 ngày. Sau ân hạn, tính lãi 0.05%/ngày trên dư nợ gốc quá hạn.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('input_penalty_base_amount'),
            controller: _penaltyBaseAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Dư nợ gốc của hóa đơn (VNĐ)',
              hintText: 'Ví dụ: 2000000',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              border: OutlineInputBorder(),
              suffixText: 'VNĐ',
            ),
            onChanged: (_) => _calculatePenalty(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('input_penalty_overdue_days'),
            controller: _penaltyOverdueDaysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số ngày quá hạn tính đến hiện tại',
              hintText: 'Ví dụ: 10',
              prefixIcon: Icon(Icons.timer_outlined),
              border: OutlineInputBorder(),
              suffixText: 'ngày',
            ),
            onChanged: (_) => _calculatePenalty(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('btn_calculate_penalty'),
            onPressed: _calculatePenalty,
            icon: const Icon(Icons.calculate),
            label: const Text('Tính Tiền Lãi Phạt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          if (_penaltyResult != null) ...[
            _buildTotalAmountCard(
              title: 'Tiền lãi phạt:',
              amountText: _penaltyResult!.formattedPenaltyAmount,
              subtitle: _penaltyResult!.statusVietnamese,
              isError: _penaltyResult!.penaltyAmount > 0,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSummaryRow('Dư nợ gốc:', _penaltyResult!.formattedTotalAmount),
                    const Divider(height: 20),
                    _buildSummaryRow('Số ngày quá hạn:', '${_penaltyResult!.daysOverdue} ngày'),
                    const Divider(height: 20),
                    _buildSummaryRow(
                      'Tình trạng ân hạn (3 ngày):',
                      _penaltyResult!.inGracePeriod ? 'Đang trong ân hạn (chưa tính lãi)' : 'Đã hết thời gian ân hạn',
                    ),
                    const Divider(height: 20),
                    _buildSummaryRow('Lãi suất phạt/ngày:', '0.05% / ngày'),
                    const Divider(height: 20),
                    _buildSummaryRow(
                      'Tổng tiền cần thanh toán:',
                      _penaltyResult!.formattedTotalWithPenalty,
                      isBold: true,
                      color: AppTheme.error,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildInfoBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.warningText, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.warningText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmountCard({
    required String title,
    required String amountText,
    required String subtitle,
    bool isError = false,
  }) {
    final bgColor = isError ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD);
    final primaryColor = isError ? AppTheme.error : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amountText,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierBreakdownTable(List<TierBreakdownItem> items, {required String unit}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final isUsed = item.units > 0;

          return Container(
            color: isUsed ? Colors.blue.withValues(alpha: 0.04) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isUsed ? AppTheme.primary : Colors.grey.shade300,
                  child: Text(
                    '${item.tier}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUsed ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isUsed ? FontWeight.bold : FontWeight.normal,
                          color: isUsed ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đơn giá: ${item.formattedRate}/$unit • Tính: ${item.formattedUnits} $unit',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.formattedAmount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isUsed ? FontWeight.bold : FontWeight.normal,
                    color: isUsed ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
