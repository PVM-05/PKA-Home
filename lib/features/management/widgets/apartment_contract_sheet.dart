import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
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
            Text(
              'Hệ thống sẽ lưu vết lịch sử vĩnh viễn, chốt ngày chuyển đi và bảo toàn mọi hóa đơn cũ.',
              style: context.bodySmall?.copyWith(color: AppTheme.textSecondary),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.assignment_outlined, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hợp Đồng & Lưu Trú Căn Hộ $apartmentCode',
                        style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Quản lý hợp đồng thuê, cọc giữ chỗ và lịch sử lưu trú',
                        style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
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
                error: (err, _) => Center(child: Text(formatErrorMessage(err))),
                data: (contracts) {
                  if (contracts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Chưa có dữ liệu hợp đồng lưu trú cho căn hộ này.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
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
                          color: item.isActive ? colorScheme.surface : colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
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
                                  item.fullName,
                                  style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.displayRole,
                                        style: context.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: item.isActive
                                            ? AppTheme.getSemanticSuccess(context).withValues(alpha: 0.12)
                                            : colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.displayStatus,
                                        style: context.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: item.isActive
                                              ? AppTheme.getSemanticSuccess(context)
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${item.formattedStartDate} - ${item.formattedEndDate}',
                                      style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                if (item.depositAmount > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.savings_outlined, size: 14, color: AppTheme.getSemanticWarning(context)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Cọc: ${item.formattedDeposit}',
                                        style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            if (item.contractNumber != null && item.contractNumber!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Số HĐ: ${item.contractNumber}',
                                style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],

                            if (item.isActive && item.relationRole != 'owner') ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _showTerminationDialog(context, ref, item),
                                  icon: Icon(Icons.exit_to_app, size: 16, color: colorScheme.error),
                                  label: Text('Kết thúc lưu trú', style: context.bodySmall?.copyWith(color: colorScheme.error)),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
