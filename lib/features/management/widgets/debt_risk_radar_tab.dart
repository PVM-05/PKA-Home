import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
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
              Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(formatErrorMessage(e), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Nợ rủi ro cao',
                  value: '${_moneyFormat.format(kpi.highRiskDebt)} đ',
                  subtitle: 'Nguy cơ khó thu hồi',
                  icon: Icons.trending_down_rounded,
                  color: AppTheme.getSemanticError(context),
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
    final colorScheme = Theme.of(context).colorScheme;
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
                  style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: context.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(String currentFilter) {
    final colorScheme = Theme.of(context).colorScheme;
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
              hintStyle: context.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            ),
            style: context.bodyMedium,
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
                _buildFilterChip('Rủi ro cao', 'high', currentFilter, color: AppTheme.textError),
                const SizedBox(width: 8),
                _buildFilterChip('Cần chú ý', 'medium', currentFilter, color: AppTheme.textWarning),
                const SizedBox(width: 8),
                _buildFilterChip('An toàn', 'low', currentFilter, color: AppTheme.textSuccess),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentFilter, {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = currentFilter == value;
    final activeColor = color ?? AppTheme.primary;
    return ChoiceChip(
      label: Text(label),
      labelStyle: context.bodySmall?.copyWith(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : colorScheme.onSurface,
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) {
        ref.read(debtRiskFilterProvider.notifier).state = value;
      },
    );
  }

  Widget _buildApartmentList(List<DebtRiskScoreModel> list) {
    if (list.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 48),
              const SizedBox(height: 12),
              Text(
                'Không có căn hộ nào nằm trong tiêu chí rủi ro này',
                style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Các căn hộ đều duy trì tình trạng thanh toán an toàn',
                style: context.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              'Sắp xếp theo Điểm rủi ro AI',
              style: context.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                  style: context.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
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
                      style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (apt.ownerPhone.isNotEmpty)
                      Text(
                        apt.ownerPhone,
                        style: context.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                          style: context.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: apt.riskLevel.color,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      apt.riskLevel.label,
                      style: context.labelSmall?.copyWith(
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
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),

          // Thông tin tài chính
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dư nợ hiện tại', style: context.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      '${_moneyFormat.format(apt.unpaidAmount)} đ',
                      style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.getSemanticError(context)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quá hạn', style: context.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      '${apt.overdueDays} ngày',
                      style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lịch sử trễ', style: context.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      '${apt.latePaymentCount} kỳ',
                      style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
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
                        style: context.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500),
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
                        Text(
                          'Chiến lược đề xuất: ',
                          style: context.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          apt.recommendedTier.shortName,
                          style: context.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: apt.recommendedTier.color,
                          ),
                        ),
                      ],
                    ),
                    if (apt.dunningCount > 0)
                      Text(
                        'Đã đôn đốc ${apt.dunningCount} lần (Gần nhất: ${apt.lastDunningTier?.shortName ?? ""})',
                        style: context.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: apt.recommendedTier.color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
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
