import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(
      apartmentBalanceProvider(widget.apartmentId),
    );
    final entriesAsync = ref.watch(
      apartmentLedgerEntriesProvider(widget.apartmentId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ Cái Công Nợ Căn Hộ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () {
              ref.invalidate(apartmentBalanceProvider(widget.apartmentId));
              ref.invalidate(
                apartmentLedgerEntriesProvider(widget.apartmentId),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(apartmentBalanceProvider(widget.apartmentId));
          ref.invalidate(apartmentLedgerEntriesProvider(widget.apartmentId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header căn hộ & Tòa nhà
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.apartment, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Text(
                      'Căn hộ: ${widget.apartmentCode}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: const Text(
                    'Sổ Phụ Công Nợ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Tổng quan số dư công nợ
            balanceAsync.when(
              data: (balance) => _buildBalanceCard(context, balance),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Lỗi tải số dư: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons (Lập phiếu điều chỉnh & Khóa sổ kỳ)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Lập phiếu điều chỉnh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => CreateCreditNoteDialog(
                          buildingId: widget.buildingId,
                          apartmentId: widget.apartmentId,
                          apartmentCode: widget.apartmentCode,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.lock_clock_outlined,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      'Khóa sổ kỳ kế toán',
                      style: TextStyle(color: Colors.orange),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ClosePeriodDialog(
                          buildingId: widget.buildingId,
                          initialPeriod: _selectedPeriod,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Danh sách bút toán dòng thời gian
            const Text(
              'Lịch Sử Bút Toán Công Nợ (Append-Only)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Chưa có phát sinh bút toán sổ cái cho căn hộ này.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: entries
                      .map((entry) => _buildLedgerItemCard(context, entry))
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Lỗi tải danh sách bút toán: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, double balance) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (balance > 0) {
      statusColor = Colors.deepOrange;
      statusText = 'Còn nợ';
      statusIcon = Icons.warning_amber_rounded;
    } else if (balance == 0) {
      statusColor = Colors.green;
      statusText = 'Đã thanh toán đủ';
      statusIcon = Icons.check_circle_outline;
    } else {
      statusColor = Colors.blue;
      statusText = 'Nộp thừa/Ký quỹ';
      statusIcon = Icons.savings_outlined;
    }

    final formattedMoney = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    ).format(balance.abs());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Số dư công nợ hiện tại',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              balance < 0 ? '- $formattedMoney' : formattedMoney,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerItemCard(
    BuildContext context,
    ApartmentLedgerEntryModel entry,
  ) {
    final isDebit = entry.isDebit;
    final prefix = isDebit ? '+' : '-';
    final amountColor = isDebit ? Colors.deepOrange : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.entryCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blueGrey,
                  ),
                ),
                Text(
                  entry.formattedCreatedAtWithTime,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.entryTypeVietnamese,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                    ),
                  ),
                ),
                Text(
                  '$prefix${entry.formattedAmount}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.description,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kỳ: ${entry.formattedPeriod}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  'Dư nợ sau GD: ${entry.formattedBalanceAfter}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
