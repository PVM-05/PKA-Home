import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/accounting_voucher_dialog.dart';
import '../../../core/widgets/building_switcher_dropdown.dart';
import '../../../data/providers/maintenance_fund_provider.dart';
import '../../../data/providers/building_provider.dart';

class MaintenanceFundLedgerScreen extends ConsumerStatefulWidget {
  const MaintenanceFundLedgerScreen({super.key});

  @override
  ConsumerState<MaintenanceFundLedgerScreen> createState() => _MaintenanceFundLedgerScreenState();
}

class _MaintenanceFundLedgerScreenState extends ConsumerState<MaintenanceFundLedgerScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  void _showCreateVoucherSheet(BuildContext context, String? buildingId) {
    if (buildingId == null || buildingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn tòa nhà trước khi lập phiếu.')),
      );
      return;
    }

    String type = 'INCOME';
    String category = 'MAINTENANCE_FEE';
    final amountController = TextEditingController();
    final personController = TextEditingController();
    final descController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type == 'INCOME' ? 'Lập Phiếu Thu Quỹ' : 'Lập Phiếu Chi Quỹ',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Loại phiếu
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'INCOME', label: Text('Thu quỹ (+)')),
                        ButtonSegment(value: 'EXPENSE', label: Text('Chi quỹ (-)')),
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
                    const SizedBox(height: 16),
                    // Danh mục
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục giao dịch',
                        border: OutlineInputBorder(),
                      ),
                      items: type == 'INCOME'
                          ? const [
                              DropdownMenuItem(value: 'MAINTENANCE_FEE', child: Text('Thu phí bảo trì')),
                              DropdownMenuItem(value: 'BANK_INTEREST', child: Text('Lãi tiền gửi ngân hàng')),
                              DropdownMenuItem(value: 'OTHER', child: Text('Khoản thu khác')),
                            ]
                          : const [
                              DropdownMenuItem(value: 'EQUIPMENT_REPAIR', child: Text('Sửa chữa thiết bị')),
                              DropdownMenuItem(value: 'OTHER', child: Text('Khoản chi bảo trì khác')),
                            ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Số tiền
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số tiền (VNĐ)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Người nộp / nhận
                    TextField(
                      controller: personController,
                      decoration: InputDecoration(
                        labelText: type == 'INCOME' ? 'Họ tên người nộp tiền' : 'Họ tên đơn vị / người nhận tiền',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Nội dung
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung chi tiết',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type == 'INCOME' ? AppTheme.primary : AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final rawAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                              final person = personController.text.trim();
                              final desc = descController.text.trim();

                              if (rawAmount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ.')),
                                );
                                return;
                              }
                              if (person.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vui lòng nhập họ tên người nộp/nhận.')),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              final repo = ref.read(maintenanceFundRepositoryProvider);
                              final result = await repo.recordTransaction(
                                buildingId: buildingId,
                                transactionType: type,
                                category: category,
                                amount: rawAmount,
                                description: desc.isNotEmpty ? desc : (type == 'INCOME' ? 'Thu quỹ bảo trì' : 'Chi bảo trì'),
                                recipientOrPayer: person,
                                referenceType: 'MANUAL',
                              );

                              if (!context.mounted) return;
                              Navigator.of(ctx).pop();

                              if (result != null && result['success'] == true) {
                                ref.invalidate(activeMaintenanceFundProvider);
                                ref.invalidate(maintenanceFundLedgerProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lập chứng từ ${result['voucher_number']} thành công!'),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Không thể ghi sổ quỹ. Vui lòng kiểm tra số dư.')),
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(type == 'INCOME' ? 'Xác nhận thu quỹ' : 'Xác nhận chi quỹ'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBuilding = ref.watch(activeBuildingProvider).valueOrNull;
    final fundAsync = ref.watch(activeMaintenanceFundProvider);
    final ledgerAsync = ref.watch(maintenanceFundLedgerProvider);
    final currentFilter = ref.watch(maintenanceFundLedgerFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ Quỹ Bảo Trì 2%'),
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
        onRefresh: () async {
          ref.invalidate(activeMaintenanceFundProvider);
          ref.invalidate(maintenanceFundLedgerProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Thẻ số dư tổng quan
            fundAsync.when(
              data: (fund) {
                final balance = fund?.totalBalance ?? 0.0;
                final interestEarned = fund?.annualInterestEarned ?? 0.0;
                final interestRate = fund?.interestRatePercent ?? 5.2;

                return AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Số dư quỹ khả dụng',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              activeBuilding?.name ?? 'Toàn tòa nhà',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currencyFormat.format(balance),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.trending_up, color: AppTheme.success, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Lãi tiền gửi ($interestRate%/năm): +${_currencyFormat.format(interestEarned)}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => AppErrorCard(error: err),
            ),
            const SizedBox(height: 16),

            // Bộ lọc loại chứng từ
            Row(
              children: [
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: currentFilter == 'ALL',
                  onSelected: (_) => ref.read(maintenanceFundLedgerFilterProvider.notifier).state = 'ALL',
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Thu quỹ'),
                  selected: currentFilter == 'INCOME',
                  onSelected: (_) => ref.read(maintenanceFundLedgerFilterProvider.notifier).state = 'INCOME',
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Chi quỹ'),
                  selected: currentFilter == 'EXPENSE',
                  onSelected: (_) => ref.read(maintenanceFundLedgerFilterProvider.notifier).state = 'EXPENSE',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Danh sách nhật ký sổ cái
            Text(
              'Nhật ký giao dịch chứng từ',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ledgerAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.menu_book_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có giao dịch chứng từ nào.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isIncome = tx.isIncome;

                    return AppCard(
                      padding: const EdgeInsets.all(12),
                      child: InkWell(
                        onTap: () {
                          AccountingVoucherDialog.show(
                            context,
                            transaction: tx,
                            buildingName: activeBuilding?.name ?? 'Tòa nhà PKA-Home',
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isIncome ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isIncome ? AppTheme.success : AppTheme.error,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        tx.voucherNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        '${isIncome ? '+' : '-'}${_currencyFormat.format(tx.amount)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isIncome ? AppTheme.success : AppTheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tx.categoryDisplayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isIncome ? AppTheme.primary : AppTheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tx.description,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt),
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                      Text(
                                        'Số dư sau GD: ${_currencyFormat.format(tx.balanceAfter)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
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
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (err, _) => AppErrorCard(error: err),
            ),
          ],
        ),
      ),
    );
  }
}
