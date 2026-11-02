import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/resident_lifecycle_provider.dart';
import 'create_apartment_invitation_sheet.dart';

class ApartmentContractSheet extends ConsumerWidget {
  final String apartmentId;
  final String apartmentCode;

  const ApartmentContractSheet({
    super.key,
    required this.apartmentId,
    required this.apartmentCode,
  });

  void _showTerminationDialog(BuildContext context, WidgetRef ref, ResidentLeaseContractModel contract) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận kết thúc lưu trú'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn kết thúc lưu trú của cư dân ${contract.fullName}?'),
            const SizedBox(height: 8),
            const Text(
              'Hệ thống sẽ lưu vết lịch sử vĩnh viễn, chốt ngày chuyển đi và bảo toàn mọi hóa đơn cũ.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú bàn giao & hoàn cọc',
                hintText: 'Ví dụ: Đã kiểm tra đồng hồ và hoàn trả đủ tiền cọc...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(residentLifecycleRepositoryProvider);
              final res = await repo.terminateResidentStay(
                userId: contract.userId,
                apartmentId: contract.apartmentId,
                note: noteController.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Đã cập nhật trạng thái lưu trú.'),
                    backgroundColor: res['success'] == true ? AppTheme.primary : AppTheme.error,
                  ),
                );
                ref.invalidate(apartmentContractsProvider(contract.apartmentId));
              }
            },
            child: const Text('Xác nhận kết thúc'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsAsync = ref.watch(apartmentContractsProvider(apartmentId));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_outlined, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hợp Đồng & Lưu Trú Căn Hộ $apartmentCode',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Quản lý hợp đồng thuê, cọc giữ chỗ và lịch sử lưu trú',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => CreateApartmentInvitationSheet(
                        apartmentId: apartmentId,
                        apartmentCode: apartmentCode,
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Mời Thành Viên Mới'),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: contractsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
              data: (contracts) {
                if (contracts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Chưa có dữ liệu hợp đồng lưu trú cho căn hộ này.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: contracts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = contracts[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: item.isActive ? Colors.white : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.isActive ? AppTheme.border : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.displayRole,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: item.isActive
                                          ? Colors.teal.withValues(alpha: 0.1)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.displayStatus,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: item.isActive ? Colors.teal.shade800 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '${item.formattedStartDate} - ${item.formattedEndDate}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              if (item.depositAmount > 0) ...[
                                const Spacer(),
                                const Icon(Icons.savings_outlined, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  'Cọc: ${item.formattedDeposit}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),

                          if (item.contractNumber != null && item.contractNumber!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Số HĐ: ${item.contractNumber}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],

                          if (item.isActive && item.relationRole != 'owner') ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showTerminationDialog(context, ref, item),
                                icon: const Icon(Icons.exit_to_app, size: 16, color: AppTheme.error),
                                label: const Text('Kết thúc lưu trú', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}
