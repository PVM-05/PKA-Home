import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/debt_risk_score_model.dart';
import '../../../data/providers/debt_prediction_provider.dart';
import 'execute_dunning_dialog.dart';

class DebtRiskRadarTab extends ConsumerStatefulWidget {
  final String buildingId;

  const DebtRiskRadarTab({
    super.key,
    required this.buildingId,
  });

  @override
  ConsumerState<DebtRiskRadarTab> createState() => _DebtRiskRadarTabState();
}

class _DebtRiskRadarTabState extends ConsumerState<DebtRiskRadarTab> {
  final _searchController = TextEditingController();
  final _moneyFormat = NumberFormat('#,##0', 'vi_VN');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDunningDialog(DebtRiskScoreModel apt) {
    showDialog(
      context: context,
      builder: (ctx) => ExecuteDunningDialog(
        buildingId: widget.buildingId,
        apartmentId: apt.apartmentId,
        apartmentCode: apt.apartmentCode,
        ownerName: apt.ownerName,
        unpaidAmount: apt.unpaidAmount,
        overdueDays: apt.overdueDays,
        riskScore: apt.riskScore,
        initialTier: apt.recommendedTier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radarAsync = ref.watch(buildingDebtRadarProvider(widget.buildingId));
    final currentFilter = ref.watch(debtRiskFilterProvider);
    final apartments = ref.watch(filteredDebtRiskApartmentsProvider(widget.buildingId));

    return radarAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 40),
              const SizedBox(height: 12),
              Text('Không thể tải radar rủi ro nợ: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(buildingDebtRadarProvider(widget.buildingId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (radar) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(buildingDebtRadarProvider(widget.buildingId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Dải KPI Rủi ro nợ xấu
              _buildKpiSection(radar.kpi),

              const SizedBox(height: 20),

              // 2. Thanh tìm kiếm và bộ lọc phân loại
              _buildFilterBar(currentFilter),

              const SizedBox(height: 16),

              // 3. Danh sách căn hộ rủi ro
              _buildApartmentList(apartments),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiSection(DebtRadarKpiModel kpi) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Rủi ro cao',
                value: '${kpi.highRiskCount} căn',
                subtitle: 'Cần đôn đốc khẩn cấp',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Cần chú ý',
                value: '${kpi.mediumRiskCount} căn',
                subtitle: 'Đang trễ hạn 1-2 kỳ',
                icon: Icons.info_outline_rounded,
                color: AppTheme.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Tổng nợ quá hạn',
                value: '${_moneyFormat.format(kpi.totalOverdueDebt)} đ',
                subtitle: 'Toàn bộ danh mục nợ',
                icon: Icons.account_balance_wallet_outlined,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Nợ rủi ro cao',
                value: '${_moneyFormat.format(kpi.highRiskDebt)} đ',
                subtitle: 'Nguy cơ khó thu hồi',
                icon: Icons.trending_down_rounded,
                color: AppTheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(String currentFilter) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tìm theo mã căn hộ, họ tên chủ hộ hoặc số điện thoại...',
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(debtRiskSearchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (val) {
              ref.read(debtRiskSearchQueryProvider.notifier).state = val;
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 'all', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip('Rủi ro cao', 'high', currentFilter, color: AppTheme.error),
                const SizedBox(width: 8),
                _buildFilterChip('Cần chú ý', 'medium', currentFilter, color: AppTheme.warning),
                const SizedBox(width: 8),
                _buildFilterChip('An toàn', 'low', currentFilter, color: AppTheme.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentFilter, {Color? color}) {
    final isSelected = currentFilter == value;
    final activeColor = color ?? AppTheme.primary;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) {
        ref.read(debtRiskFilterProvider.notifier).state = value;
      },
    );
  }

  Widget _buildApartmentList(List<DebtRiskScoreModel> list) {
    if (list.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 48),
              SizedBox(height: 12),
              Text(
                'Không có căn hộ nào nằm trong tiêu chí rủi ro này',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Các căn hộ đều duy trì tình trạng thanh toán an toàn',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Danh sách căn hộ rủi ro (${list.length} căn)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const Text(
              'Sắp xếp theo Điểm rủi ro AI',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...list.map((apt) => _buildApartmentCard(apt)),
      ],
    );
  }

  Widget _buildApartmentCard(DebtRiskScoreModel apt) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card: Mã căn + Score Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  apt.apartmentCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apt.ownerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (apt.ownerPhone.isNotEmpty)
                      Text(
                        apt.ownerPhone,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              // Điểm rủi ro Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: apt.riskLevel.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: apt.riskLevel.color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed_rounded, size: 14, color: apt.riskLevel.color),
                        const SizedBox(width: 4),
                        Text(
                          '${apt.riskScore}/100',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: apt.riskLevel.color,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      apt.riskLevel.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: apt.riskLevel.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),

          // Thông tin tài chính
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dư nợ hiện tại', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '${_moneyFormat.format(apt.unpaidAmount)} đ',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quá hạn', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '${apt.overdueDays} ngày',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lịch sử trễ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '${apt.latePaymentCount} kỳ',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Yếu tố rủi ro chips
          if (apt.riskFactors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: apt.riskFactors.map((f) {
                final isHigh = f.severity == 'high';
                final color = isHigh ? AppTheme.error : AppTheme.warning;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: color),
                      const SizedBox(width: 4),
                      Text(
                        f.label,
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // Footer: Khuyến nghị đôn đốc & Nút hành động
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Chiến lược đề xuất: ',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        Text(
                          apt.recommendedTier.shortName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: apt.recommendedTier.color,
                          ),
                        ),
                      ],
                    ),
                    if (apt.dunningCount > 0)
                      Text(
                        'Đã đôn đốc ${apt.dunningCount} lần (Gần nhất: ${apt.lastDunningTier?.shortName ?? ""})',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: apt.recommendedTier.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openDunningDialog(apt),
                icon: const Icon(Icons.campaign_rounded, size: 16),
                label: const Text('Đôn đốc'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
