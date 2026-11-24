import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/issue_rating_model.dart';
import '../../../data/providers/issue_rating_provider.dart';

/// Màn hình Khảo sát & Đánh giá dịch vụ sự cố dành cho Ban Quản Lý
class ServiceRatingOverviewScreen extends ConsumerStatefulWidget {
  const ServiceRatingOverviewScreen({super.key});

  @override
  ConsumerState<ServiceRatingOverviewScreen> createState() =>
      _ServiceRatingOverviewScreenState();
}

class _ServiceRatingOverviewScreenState
    extends ConsumerState<ServiceRatingOverviewScreen> {
  String _selectedFilter = 'all'; // 'all', '5_star', '4_star', 'low_star'

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratingsAsync = ref.watch(allIssueRatingsProvider);

    return RoleGuard(
      permission: AppPermissions.issueManagement,
      child: Scaffold(
        appBar: AppBar(title: const Text('Đánh giá chất lượng dịch vụ')),
        body: ratingsAsync.when(
          loading: () => ListView(
            padding: AppSpacing.p16,
            children: [
              AppSkeletonShimmer.cardList(count: 3, itemHeight: 132),
            ],
          ),
          error: (err, _) => ListView(
            padding: AppSpacing.p16,
            children: [
              AppErrorCard(
                error: err,
                onRetry: () => ref.invalidate(allIssueRatingsProvider),
              ),
            ],
          ),
          data: (ratings) {
            if (ratings.isEmpty) {
              return RefreshIndicator(
                color: colorScheme.primary,
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  ref.invalidate(allIssueRatingsProvider);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppSpacing.p16,
                  children: const [
                    AppEmptyState(
                      icon: Icons.star_outline_rounded,
                      title: 'Chưa có lượt đánh giá nào',
                      description:
                          'Khi cư dân hoàn thành đánh giá các sự cố kỹ thuật, kết quả khảo sát và thống kê KPI sẽ hiển thị tại đây.',
                    ),
                  ],
                ),
              );
            }

            // Tính toán số liệu thống kê
            final totalRatings = ratings.length;
            final avgOverall =
                ratings.map((r) => r.overallRating).reduce((a, b) => a + b) /
                totalRatings;
            final avgSpeed =
                ratings.map((r) => r.speedRating).reduce((a, b) => a + b) /
                totalRatings;
            final avgAttitude =
                ratings.map((r) => r.attitudeRating).reduce((a, b) => a + b) /
                totalRatings;
            final avgQuality =
                ratings.map((r) => r.qualityRating).reduce((a, b) => a + b) /
                totalRatings;
            final highSatisfactionCount = ratings
                .where((r) => r.overallRating >= 4.0)
                .length;
            final satisfactionRate = (highSatisfactionCount / totalRatings * 100)
                .toStringAsFixed(0);

            // Áp dụng bộ lọc
            final filteredRatings = ratings.where((r) {
              if (_selectedFilter == '5_star') return r.overallRating >= 4.8;
              if (_selectedFilter == '4_star') {
                return r.overallRating >= 3.8 && r.overallRating < 4.8;
              }
              if (_selectedFilter == 'low_star') return r.overallRating < 3.8;
              return true;
            }).toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: RefreshIndicator(
                  color: colorScheme.primary,
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    ref.invalidate(allIssueRatingsProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.p16,
                    children: [
                      // ─── Header: Tổng quan KPI & Điểm số ───
                      _buildKpiCard(
                        context,
                        avgOverall: avgOverall,
                        satisfactionRate: satisfactionRate,
                        totalRatings: totalRatings,
                        avgSpeed: avgSpeed,
                        avgAttitude: avgAttitude,
                        avgQuality: avgQuality,
                      ),
                      AppSpacing.h16,

                      // ─── Thanh lọc FilterChips ───
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              context,
                              'all',
                              'Tất cả (${ratings.length})',
                            ),
                            AppSpacing.w8,
                            _buildFilterChip(
                              context,
                              '5_star',
                              '5 sao (${ratings.where((r) => r.overallRating >= 4.8).length})',
                            ),
                            AppSpacing.w8,
                            _buildFilterChip(
                              context,
                              '4_star',
                              '4 sao (${ratings.where((r) => r.overallRating >= 3.8 && r.overallRating < 4.8).length})',
                            ),
                            AppSpacing.w8,
                            _buildFilterChip(
                              context,
                              'low_star',
                              'Cần cải thiện (<4★) (${ratings.where((r) => r.overallRating < 3.8).length})',
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.h16,

                      // ─── Danh sách từng đánh giá ───
                      if (filteredRatings.isEmpty)
                        const AppEmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'Không có đánh giá phù hợp',
                          description:
                              'Không có đánh giá nào phù hợp với bộ lọc đã chọn.',
                        )
                      else
                        ...filteredRatings.map(
                          (rating) => _buildRatingItemCard(context, rating),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String key, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: context.labelMedium?.tabularFigures().copyWith(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required double avgOverall,
    required String satisfactionRate,
    required int totalRatings,
    required double avgSpeed,
    required double avgAttitude,
    required double avgQuality,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Điểm dịch vụ toàn khu',
                    style: context.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.h4,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rate_rounded,
                        color: warningColor,
                        size: 28,
                      ),
                      AppSpacing.w4,
                      Text(
                        '${avgOverall.toStringAsFixed(1)} / 5.0',
                        style: context.headlineMedium
                            ?.tabularFigures()
                            .copyWith(
                              fontWeight: FontWeight.bold,
                              color: warningColor,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r12,
                ),
                child: Column(
                  children: [
                    Text(
                      '$satisfactionRate%',
                      style: context.titleLarge?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                        color: successColor,
                      ),
                    ),
                    Text(
                      'Tỷ lệ hài lòng',
                      style: context.labelSmall?.copyWith(color: successColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.h16,
          const Divider(),
          AppSpacing.h8,

          // 3 Tiêu chí trung bình
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn(context, 'Tốc độ', avgSpeed),
              _buildMetricColumn(context, 'Thái độ', avgAttitude),
              _buildMetricColumn(context, 'Kỹ thuật', avgQuality),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(BuildContext context, String title, double score) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    return Column(
      children: [
        Text(
          title,
          style: context.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.h4,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rate_rounded, size: 15, color: warningColor),
            const SizedBox(width: 2),
            Text(
              score.toStringAsFixed(1),
              style: context.bodyMedium?.tabularFigures().copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingItemCard(
    BuildContext context,
    IssueRatingModel rating,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final label = IssueRatingModel.getSatisfactionLabel(rating.overallRating);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Căn hộ + Tên cư dân + Ngày
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r8,
                ),
                child: Text(
                  rating.reporterName ?? 'Cư dân',
                  style: context.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              Text(
                dateFormat.format(rating.createdAt),
                style: context.labelSmall?.tabularFigures().copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.h12,

          // Điểm số & nhãn
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.r8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rate_rounded,
                      size: 16,
                      color: warningColor,
                    ),
                    AppSpacing.w4,
                    Text(
                      '${rating.overallRating.toStringAsFixed(1)} / 5.0',
                      style: context.labelMedium?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                        color: warningColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                label,
                style: context.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AppSpacing.h12,

          // Breakdown
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildSmallChip(context, 'Tốc độ', rating.speedRating),
              _buildSmallChip(context, 'Thái độ', rating.attitudeRating),
              _buildSmallChip(context, 'Kỹ thuật', rating.qualityRating),
            ],
          ),

          // Lời nhận xét
          if (rating.comment != null && rating.comment!.trim().isNotEmpty) ...[
            AppSpacing.h12,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: AppRadius.r8,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                '"${rating.comment}"',
                style: context.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallChip(BuildContext context, String title, int score) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      '$title: $score★',
      style: context.labelSmall?.tabularFigures().copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
