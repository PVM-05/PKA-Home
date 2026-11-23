import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/apartment_ledger_entry_model.dart';
import '../../../data/providers/accounting_providers.dart';
import '../widgets/close_period_dialog.dart';
import '../widgets/create_credit_note_dialog.dart';

class ApartmentLedgerScreen extends ConsumerStatefulWidget {
  final String apartmentId;
  final String apartmentCode;
  final String buildingId;

  const ApartmentLedgerScreen({
    super.key,
    required this.apartmentId,
    required this.apartmentCode,
    required this.buildingId,
  });

  @override
  ConsumerState<ApartmentLedgerScreen> createState() =>
      _ApartmentLedgerScreenState();
}

class _ApartmentLedgerScreenState extends ConsumerState<ApartmentLedgerScreen> {
  String? _selectedPeriod;

  void _refreshAll() {
    ref.invalidate(apartmentBalanceProvider(widget.apartmentId));
    ref.invalidate(apartmentLedgerEntriesProvider(widget.apartmentId));
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(
      apartmentBalanceProvider(widget.apartmentId),
    );
    final entriesAsync = ref.watch(
      apartmentLedgerEntriesProvider(widget.apartmentId),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ Cái Công Nợ Căn Hộ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: () async => _refreshAll(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.p16,
              children: [
                // Header căn hộ & Sổ phụ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.apartment,
                            color: colorScheme.primary,
                          ),
                          AppSpacing.w8,
                          Flexible(
                            child: Text(
                              'Căn hộ: ${widget.apartmentCode}',
                              style: context.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)
                                  .tabularFigures(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.w8,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: AppRadius.r16,
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Text(
                        'Sổ Phụ Công Nợ',
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.h16,

                // Card Tổng quan số dư công nợ
                balanceAsync.when(
                  data: (balance) => _buildBalanceCard(context, balance),
                  loading: () => Padding(
                    padding: AppSpacing.p8,
                    child: AppSkeletonShimmer.cardList(
                      count: 1,
                      itemHeight: 110,
                    ),
                  ),
                  error: (err, _) => AppErrorCard(
                    error: err,
                    onRetry: _refreshAll,
                  ),
                ),
                AppSpacing.h16,

                // Action Buttons (Lập phiếu điều chỉnh & Khóa sổ kỳ)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;
                    final adjustButton = ElevatedButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Lập phiếu điều chỉnh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => CreateCreditNoteDialog(
                            buildingId: widget.buildingId,
                            apartmentId: widget.apartmentId,
                            apartmentCode: widget.apartmentCode,
                          ),
                        );
                      },
                    );

                    final closePeriodButton = OutlinedButton.icon(
                      icon: Icon(
                        Icons.lock_clock_outlined,
                        color: warningColor,
                      ),
                      label: Text(
                        'Khóa sổ kỳ kế toán',
                        style: TextStyle(color: warningColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: warningColor),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => ClosePeriodDialog(
                            buildingId: widget.buildingId,
                            initialPeriod: _selectedPeriod,
                          ),
                        );
                      },
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          adjustButton,
                          AppSpacing.h8,
                          closePeriodButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: adjustButton),
                        AppSpacing.w8,
                        Expanded(child: closePeriodButton),
                      ],
                    );
                  },
                ),
                AppSpacing.h24,

                // Danh sách bút toán dòng thời gian
                Text(
                  'Lịch Sử Bút Toán Công Nợ (Append-Only)',
                  style: context.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.h8,

                entriesAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const AppCard(
                        padding: AppSpacing.p24,
                        child: AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Chưa có phát sinh bút toán',
                          description:
                              'Chưa có phát sinh bút toán sổ cái cho căn hộ này.',
                        ),
                      );
                    }

                    return Column(
                      children: entries
                          .map((entry) => _buildLedgerItemCard(context, entry))
                          .toList(),
                    );
                  },
                  loading: () => Padding(
                    padding: AppSpacing.p8,
                    child: AppSkeletonShimmer.cardList(
                      count: 3,
                      itemHeight: 110,
                    ),
                  ),
                  error: (err, _) => AppErrorCard(
                    error: err,
                    onRetry: _refreshAll,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, double balance) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (balance > 0) {
      statusColor = warningColor;
      statusText = 'Còn nợ';
      statusIcon = Icons.warning_amber_rounded;
    } else if (balance == 0) {
      statusColor = successColor;
      statusText = 'Đã thanh toán đủ';
      statusIcon = Icons.check_circle_outline;
    } else {
      statusColor = secondaryColor;
      statusText = 'Nộp thừa/Ký quỹ';
      statusIcon = Icons.savings_outlined;
    }

    final formattedMoney = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    ).format(balance.abs());

    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Số dư công nợ hiện tại',
                style: context.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.r12,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    AppSpacing.w4,
                    Text(
                      statusText,
                      style: context.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.h8,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              balance < 0 ? '- $formattedMoney' : formattedMoney,
              style: context.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: statusColor)
                  .tabularFigures(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerItemCard(
    BuildContext context,
    ApartmentLedgerEntryModel entry,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    final isDebit = entry.isDebit;
    final prefix = isDebit ? '+' : '-';
    final amountColor = isDebit ? warningColor : successColor;

    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: AppSpacing.p12,
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
                entry.entryCode,
                style: context.labelMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    )
                    .tabularFigures(),
              ),
              Text(
                entry.formattedCreatedAtWithTime,
                style: context.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)
                    .tabularFigures(),
              ),
            ],
          ),
          AppSpacing.h6,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r6,
                ),
                child: Text(
                  entry.entryTypeVietnamese,
                  style: context.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ),
              Text(
                '$prefix${entry.formattedAmount}',
                style: context.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: amountColor)
                    .tabularFigures(),
              ),
            ],
          ),
          AppSpacing.h6,
          Text(
            entry.description,
            style: context.bodySmall?.copyWith(color: colorScheme.onSurface),
          ),
          const Divider(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Kỳ: ${entry.formattedPeriod}',
                style: context.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)
                    .tabularFigures(),
              ),
              Text(
                'Dư nợ sau GD: ${entry.formattedBalanceAfter}',
                style: context.labelSmall
                    ?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    )
                    .tabularFigures(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
