import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_theme.dart';
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
    final ratingsAsync = ref.watch(allIssueRatingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RoleGuard(
      permission: AppPermissions.issueManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đánh giá chất lượng dịch vụ'),
        ),
        body: ratingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text('Lỗi tải đánh giá: $err', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(allIssueRatingsProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (ratings) {
            if (ratings.isEmpty) {
              return RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  ref.invalidate(allIssueRatingsProvider);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: _buildEmptyState(context),
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
            final highSatisfactionCount =
                ratings.where((r) => r.overallRating >= 4.0).length;
            final satisfactionRate =
                (highSatisfactionCount / totalRatings * 100).toStringAsFixed(0);

            // Áp dụng bộ lọc
            final filteredRatings = ratings.where((r) {
              if (_selectedFilter == '5_star') return r.overallRating >= 4.8;
              if (_selectedFilter == '4_star') {
                return r.overallRating >= 3.8 && r.overallRating < 4.8;
              }
              if (_selectedFilter == 'low_star') return r.overallRating < 3.8;
              return true;
            }).toList();

            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async {
                HapticFeedback.lightImpact();
                ref.invalidate(allIssueRatingsProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── Header: Tổng quan KPI & Điểm số ───
                  _buildKpiCard(
                    avgOverall: avgOverall,
                    satisfactionRate: satisfactionRate,
                    totalRatings: totalRatings,
                    avgSpeed: avgSpeed,
                    avgAttitude: avgAttitude,
                    avgQuality: avgQuality,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // ─── Thanh lọc FilterChips ───
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'Tất cả (${ratings.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          '5_star',
                          '5 sao (${ratings.where((r) => r.overallRating >= 4.8).length})',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          '4_star',
                          '4 sao (${ratings.where((r) => r.overallRating >= 3.8 && r.overallRating < 4.8).length})',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'low_star',
                          'Cần cải thiện (<4★) (${ratings.where((r) => r.overallRating < 3.8).length})',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Danh sách từng đánh giá ───
                  if (filteredRatings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        'Không có đánh giá nào phù hợp với bộ lọc đã chọn',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ...filteredRatings.map((rating) => _buildRatingItemCard(rating, isDark)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
      selectedColor: AppTheme.primary,
      checkmarkColor: Colors.white,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildKpiCard({
    required double avgOverall,
    required String satisfactionRate,
    required int totalRatings,
    required double avgSpeed,
    required double avgAttitude,
    required double avgQuality,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Điểm dịch vụ toàn khu',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 4),
                      Text(
                        '${avgOverall.toStringAsFixed(1)} / 5.0',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$satisfactionRate%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                    const Text(
                      'Tỷ lệ hài lòng',
                      style: TextStyle(fontSize: 11, color: AppTheme.success),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // 3 Tiêu chí trung bình
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn('Tốc độ', avgSpeed),
              _buildMetricColumn('Thái độ', avgAttitude),
              _buildMetricColumn('Kỹ thuật', avgQuality),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String title, double score) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rate_rounded, size: 15, color: Colors.amber),
            const SizedBox(width: 2),
            Text(
              score.toStringAsFixed(1),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingItemCard(IssueRatingModel rating, bool isDark) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final label = IssueRatingModel.getSatisfactionLabel(rating.overallRating);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Căn hộ + Tên cư dân + Ngày
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rating.reporterName ?? 'Cư dân',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  dateFormat.format(rating.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Điểm số & nhãn
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rate_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${rating.overallRating.toStringAsFixed(1)} / 5.0',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Breakdown
            Row(
              children: [
                _buildSmallChip('Tốc độ', rating.speedRating),
                const SizedBox(width: 8),
                _buildSmallChip('Thái độ', rating.attitudeRating),
                const SizedBox(width: 8),
                _buildSmallChip('Kỹ thuật', rating.qualityRating),
              ],
            ),

            // Lời nhận xét
            if (rating.comment != null && rating.comment!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${rating.comment}"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmallChip(String title, int score) {
    return Text(
      '$title: $score★',
      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_outline_rounded, size: 56, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có lượt đánh giá nào',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Khi cư dân hoàn thành đánh giá các sự cố kỹ thuật, kết quả khảo sát và thống kê KPI sẽ hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
