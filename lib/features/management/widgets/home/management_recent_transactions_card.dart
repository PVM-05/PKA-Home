import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../../core/widgets/bounceable.dart';
import '../../../../core/motion/app_spring_motion.dart';
import '../../../../data/providers/payment_provider.dart';

/// Card danh sách các giao dịch thanh toán gần đây nhất tại trang chủ BQL
class ManagementRecentTransactionsCard extends ConsumerWidget {
  const ManagementRecentTransactionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(paymentTransactionsProvider);
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const AppCard(
            padding: AppSpacing.p16,
            child: Center(
              child: Text(
                'Chưa có giao dịch thanh toán nào.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }

        final recent = transactions.take(4).toList();
        return AppCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = recent[index];
              return Bounceable(
                onTap: () {},
                child: ListTile(
                  leading: Container(
                    padding: AppSpacing.p8,
                    decoration: BoxDecoration(
                      color: AppStatusColors.paid.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r8,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppStatusColors.paid,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    tx.title ?? 'Giao dịch thanh toán',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  subtitle: Text(
                    '${tx.transactionCode} • ${DateFormat('dd/MM HH:mm').format(tx.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  trailing: Text(
                    formatCurrency.format(tx.amount),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                  ),
                ),
              );
            },
          ),
        ).animateSpringEntry();
      },
      loading: () => AppSkeletonShimmer.cardList(
        count: 3,
        itemHeight: 64,
        borderRadius: AppRadius.r12,
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
