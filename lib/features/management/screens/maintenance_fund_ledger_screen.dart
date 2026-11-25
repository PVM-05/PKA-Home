import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/accounting_voucher_dialog.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/building_switcher_dropdown.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/maintenance_fund_provider.dart';

class MaintenanceFundLedgerScreen extends ConsumerStatefulWidget {
  const MaintenanceFundLedgerScreen({super.key});

  @override
  ConsumerState<MaintenanceFundLedgerScreen> createState() =>
      _MaintenanceFundLedgerScreenState();
}

class _MaintenanceFundLedgerScreenState
    extends ConsumerState<MaintenanceFundLedgerScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );

  void _showCreateVoucherSheet(BuildContext context, String? buildingId) {
    if (buildingId == null || buildingId.isEmpty) {
      AppSnackBar.showError(
        context,
        'Vui lòng chọn tòa nhà trước khi lập phiếu.',
      );
      return;
    }

    String type = 'INCOME';
    String category = 'MAINTENANCE_FEE';
    final amountController = TextEditingController();
    final personController = TextEditingController();
    final descController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final colorScheme = Theme.of(sheetCtx).colorScheme;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              type == 'INCOME'
                                  ? 'Lập Phiếu Thu Quỹ'
                                  : 'Lập Phiếu Chi Quỹ',
                              style: sheetCtx.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Đóng',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                          ),
                        ],
                      ),
                      AppSpacing.h12,
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'INCOME',
                            label: Text('Thu quỹ (+)'),
                          ),
                          ButtonSegment(
                            value: 'EXPENSE',
                            label: Text('Chi quỹ (-)'),
                          ),
                        ],
                        selected: {type},
                        onSelectionChanged: (val) {
                          setSheetState(() {
                            type = val.first;
                            if (type == 'INCOME') {
                              category = 'MAINTENANCE_FEE';
                            } else {
                              category = 'EQUIPMENT_REPAIR';
                            }
                          });
                        },
                      ),
                      AppSpacing.h16,
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục giao dịch',
                          border: OutlineInputBorder(),
                        ),
                        items: type == 'INCOME'
                            ? const [
                                DropdownMenuItem(
                                  value: 'MAINTENANCE_FEE',
                                  child: Text('Thu phí bảo trì'),
                                ),
                                DropdownMenuItem(
                                  value: 'BANK_INTEREST',
                                  child: Text('Lãi tiền gửi ngân hàng'),
                                ),
                                DropdownMenuItem(
                                  value: 'OTHER',
                                  child: Text('Khoản thu khác'),
                                ),
                              ]
                            : const [
                                DropdownMenuItem(
                                  value: 'EQUIPMENT_REPAIR',
                                  child: Text('Sửa chữa thiết bị'),
                                ),
                                DropdownMenuItem(
                                  value: 'OTHER',
                                  child: Text('Khoản chi bảo trì khác'),
                                ),
                              ],
                        onChanged: (val) {
                          if (val != null) setSheetState(() => category = val);
                        },
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số tiền (VNĐ)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monetization_on_outlined),
                        ),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: personController,
                        decoration: InputDecoration(
                          labelText: type == 'INCOME'
                              ? 'Họ tên người nộp tiền'
                              : 'Họ tên đơn vị / người nhận tiền',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung chi tiết',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                      AppSpacing.h20,
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: type == 'INCOME'
                              ? colorScheme.primary
                              : colorScheme.error,
                          foregroundColor: type == 'INCOME'
                              ? colorScheme.onPrimary
                              : colorScheme.onError,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final rawAmount =
                                    double.tryParse(
                                      amountController.text.trim(),
                                    ) ??
                                    0.0;
                                final person = personController.text.trim();
                                final desc = descController.text.trim();

                                if (rawAmount <= 0) {
                                  AppSnackBar.showError(
                                    context,
                                    'Vui lòng nhập số tiền hợp lệ.',
                                  );
                                  return;
                                }
                                if (person.isEmpty) {
                                  AppSnackBar.showError(
                                    context,
                                    'Vui lòng nhập họ tên người nộp/nhận.',
                                  );
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);
                                final repo = ref.read(
                                  maintenanceFundRepositoryProvider,
                                );
                                final result = await repo.recordTransaction(
                                  buildingId: buildingId,
                                  transactionType: type,
                                  category: category,
                                  amount: rawAmount,
                                  description: desc.isNotEmpty
                                      ? desc
                                      : (type == 'INCOME'
                                            ? 'Thu quỹ bảo trì'
                                            : 'Chi bảo trì'),
                                  recipientOrPayer: person,
                                  referenceType: 'MANUAL',
                                );

                                if (!context.mounted) return;
                                Navigator.of(sheetCtx).pop();

                                if (result != null &&
                                    result['success'] == true) {
                                  ref.invalidate(activeMaintenanceFundProvider);
                                  ref.invalidate(maintenanceFundLedgerProvider);
                                  AppSnackBar.showSuccess(
                                    context,
                                    'Lập chứng từ ${result['voucher_number']} thành công!',
                                  );
                                } else {
                                  AppSnackBar.showError(
                                    context,
                                    'Không thể ghi sổ quỹ. Vui lòng kiểm tra số dư.',
                                  );
                                }
                              },
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
                                type == 'INCOME'
                                    ? 'Xác nhận thu quỹ'
                                    : 'Xác nhận chi quỹ',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _refreshAll() {
    ref.invalidate(activeMaintenanceFundProvider);
    ref.invalidate(maintenanceFundLedgerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBuilding = ref.watch(activeBuildingProvider).valueOrNull;
    final fundAsync = ref.watch(activeMaintenanceFundProvider);
    final ledgerAsync = ref.watch(maintenanceFundLedgerProvider);
    final currentFilter = ref.watch(maintenanceFundLedgerFilterProvider);
    final colorScheme = theme.colorScheme;

    return RoleGuard(
      permission: AppPermissions.maintenanceFundLedger,
      child: Scaffold(
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Sổ Quỹ Bảo Trì 2%'),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: BuildingSwitcherDropdown(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Lập phiếu'),
          onPressed: () => _showCreateVoucherSheet(context, activeBuilding?.id),
        ),
        body: RefreshIndicator(
          onRefresh: () async => _refreshAll(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: isDesktop
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.p16,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildFundBalanceCard(
                                        fundAsync,
                                        activeBuilding,
                                      ),
                                      AppSpacing.h16,
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor:
                                              colorScheme.onPrimary,
                                          minimumSize: const Size(0, 48),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _showCreateVoucherSheet(
                                              context,
                                              activeBuilding?.id,
                                            ),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        label: const Text(
                                          'Lập phiếu thu / chi quỹ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
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
                                      _buildFilterChips(currentFilter),
                                      AppSpacing.h16,
                                      _buildTransactionsHeader(theme),
                                      AppSpacing.h8,
                                      _buildTransactionsList(
                                        ledgerAsync,
                                        activeBuilding,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.h32,
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                          children: [
                            _buildFundBalanceCard(fundAsync, activeBuilding),
                            AppSpacing.h16,
                            _buildFilterChips(currentFilter),
                            AppSpacing.h16,
                            _buildTransactionsHeader(theme),
                            AppSpacing.h8,
                            _buildTransactionsList(ledgerAsync, activeBuilding),
                            AppSpacing.h32,
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFundBalanceCard(
    AsyncValue<dynamic> fundAsync,
    dynamic activeBuilding,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);

    return fundAsync.when(
      data: (fund) {
        final balance = fund?.totalBalance ?? 0.0;
        final interestEarned = fund?.annualInterestEarned ?? 0.0;
        final interestRate = fund?.interestRatePercent ?? 5.2;

        return AppCard(
          padding: AppSpacing.p16,
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
                    'Số dư quỹ khả dụng',
                    style: context.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r6,
                    ),
                    child: Text(
                      activeBuilding?.name ?? 'Toàn tòa nhà',
                      style: context.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              AppSpacing.h6,
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _currencyFormat.format(balance),
                  style: context.headlineMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      )
                      .tabularFigures(),
                ),
              ),
              AppSpacing.h8,
              Row(
                children: [
                  Icon(Icons.trending_up, color: successColor, size: 16),
                  AppSpacing.w4,
                  Expanded(
                    child: Text(
                      'Lãi tiền gửi ($interestRate%/năm): +${_currencyFormat.format(interestEarned)}',
                      style: context.labelSmall
                          ?.copyWith(
                            color: successColor,
                            fontWeight: FontWeight.w600,
                          )
                          .tabularFigures(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (fund != null && fund.bankAccountNumber.isNotEmpty) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.w6,
                    Expanded(
                      child: Text(
                        '${fund.bankName} - ${fund.bankAccountNumber}',
                        style: context.labelSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)
                            .tabularFigures(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: AppSpacing.p12,
        child: AppSkeletonShimmer.cardList(count: 1, itemHeight: 110),
      ),
      error: (err, _) => AppErrorCard(error: err, onRetry: _refreshAll),
    );
  }

  Widget _buildFilterChips(String currentFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tất cả'),
            selected: currentFilter == 'ALL',
            onSelected: (_) =>
                ref.read(maintenanceFundLedgerFilterProvider.notifier).state =
                    'ALL',
          ),
          AppSpacing.w8,
          FilterChip(
            label: const Text('Thu quỹ'),
            selected: currentFilter == 'INCOME',
            onSelected: (_) =>
                ref.read(maintenanceFundLedgerFilterProvider.notifier).state =
                    'INCOME',
          ),
          AppSpacing.w8,
          FilterChip(
            label: const Text('Chi quỹ'),
            selected: currentFilter == 'EXPENSE',
            onSelected: (_) =>
                ref.read(maintenanceFundLedgerFilterProvider.notifier).state =
                    'EXPENSE',
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsHeader(ThemeData theme) {
    return Text(
      'Nhật ký giao dịch chứng từ',
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTransactionsList(
    AsyncValue<dynamic> ledgerAsync,
    dynamic activeBuilding,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final errorColor = AppTheme.getSemanticError(context);

    return ledgerAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Padding(
            padding: AppSpacing.p16,
            child: AppEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Chưa có chứng từ',
              description: 'Chưa có giao dịch chứng từ nào.',
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          separatorBuilder: (_, _) => AppSpacing.h8,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isIncome = tx.isIncome;
            final txColor = isIncome ? successColor : errorColor;

            return AppCard(
              padding: AppSpacing.p12,
              child: InkWell(
                borderRadius: AppRadius.r12,
                onTap: () {
                  AccountingVoucherDialog.show(
                    context,
                    transaction: tx,
                    buildingName: activeBuilding?.name ?? 'Tòa nhà Vivona',
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: AppSpacing.p12,
                      decoration: BoxDecoration(
                        color: txColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.r12,
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: txColor,
                        size: 22,
                      ),
                    ),
                    AppSpacing.w12,
                    Expanded(
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
                                tx.voucherNumber,
                                style: context.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)
                                    .tabularFigures(),
                              ),
                              Text(
                                '${isIncome ? '+' : '-'}${_currencyFormat.format(tx.amount)}',
                                style: context.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: txColor,
                                    )
                                    .tabularFigures(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx.categoryDisplayName,
                            style: context.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isIncome
                                  ? colorScheme.primary
                                  : errorColor,
                            ),
                          ),
                          AppSpacing.h4,
                          Text(
                            tx.description,
                            style: context.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          AppSpacing.h6,
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(tx.createdAt),
                                style: context.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    )
                                    .tabularFigures(),
                              ),
                              Text(
                                'Số dư sau GD: ${_currencyFormat.format(tx.balanceAfter)}',
                                style: context.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurfaceVariant,
                                    )
                                    .tabularFigures(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => Padding(
        padding: AppSpacing.p12,
        child: AppSkeletonShimmer.cardList(count: 3, itemHeight: 96),
      ),
      error: (err, _) => AppErrorCard(error: err, onRetry: _refreshAll),
    );
  }
}
