import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/signature_pad_dialog.dart';
import '../../../data/models/apartment_handover_model.dart';
import '../../../data/models/handover_item_model.dart';
import '../../../data/providers/handover_provider.dart';

class ResidentHandoverDetailScreen extends ConsumerStatefulWidget {
  final String handoverId;

  const ResidentHandoverDetailScreen({
    super.key,
    required this.handoverId,
  });

  @override
  ConsumerState<ResidentHandoverDetailScreen> createState() => _ResidentHandoverDetailScreenState();
}

class _ResidentHandoverDetailScreenState extends ConsumerState<ResidentHandoverDetailScreen> {
  bool _isActionLoading = false;

  void _openResidentSignaturePad() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (_) => const SignaturePadDialog(
        title: 'Chữ ký Cư dân',
        signerRole: 'Cư dân / Người nhận bàn giao',
      ),
    );

    if (bytes != null && mounted) {
      setState(() => _isActionLoading = true);
      try {
        final repo = ref.read(handoverRepositoryProvider);
        await repo.signByResident(widget.handoverId, bytes);
        ref.refresh(handoverDetailProvider(widget.handoverId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác nhận bàn giao thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi ký xác nhận: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  void _openDisputeDialog() {
    final disputeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi ý kiến / Khiếu nại biên bản'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nếu bạn thấy thông tin kiểm kê hoặc chỉ số chưa chính xác, hãy nhập phản hồi để BQL kiểm tra lại:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: disputeController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nội dung phản ánh',
                hintText: 'VD: Chỉ số nước ghi nhầm, bồn rửa mặt đã bị xước từ trước...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = disputeController.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop();

              setState(() => _isActionLoading = true);
              try {
                final repo = ref.read(handoverRepositoryProvider);
                await repo.disputeByResident(widget.handoverId, text);
                ref.refresh(handoverDetailProvider(widget.handoverId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã gửi phản hồi khiếu nại tới Ban Quản Lý'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi gửi khiếu nại: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isActionLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Gửi khiếu nại'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(handoverDetailProvider(widget.handoverId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết biên bản bàn giao'),
        elevation: 0.5,
      ),
      body: detailAsync.when(
        data: (handover) {
          if (handover == null) {
            return const Center(child: Text('Không tìm thấy thông tin biên bản bàn giao'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Thẻ mã biên bản & trạng thái
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              handover.reportCode,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (handover.isConfirmed
                                        ? Colors.green
                                        : (handover.isPendingResident ? Colors.orange : Colors.blueGrey))
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                handover.statusDisplayName,
                                style: TextStyle(
                                  color: handover.isConfirmed
                                      ? Colors.green.shade800
                                      : (handover.isPendingResident ? Colors.orange.shade800 : Colors.blueGrey),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Căn hộ: ${handover.apartmentCode ?? 'A0110'} | Loại: ${handover.handoverTypeDisplayName}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nhân viên BQL: ${handover.staffName ?? 'Ban Quản Lý'} - Ngày: ${handover.handoverDate.day}/${handover.handoverDate.month}/${handover.handoverDate.year}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                        if (handover.residentNotes != null && handover.residentNotes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Ý kiến phản hồi: ${handover.residentNotes}',
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Chỉ số công tơ bàn giao
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chỉ số đồng hồ chốt bàn giao',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.bolt, color: Colors.amber, size: 28),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Chỉ số điện: ${handover.initialElectricityReading} kWh',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Chỉ số nước: ${handover.initialWaterReading} m³',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (handover.handoverType == 'move_out') ...[
                  const SizedBox(height: 16),
                  // 3. Đối soát tiền cọc
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chiết tính hoàn trả tiền đặt cọc',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tiền cọc ban đầu:'),
                              Text(
                                _formatCurrency(handover.depositHeld),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Khấu trừ hư hại thiết bị:'),
                              Text(
                                '-${_formatCurrency(handover.totalDeduction)}',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Số tiền thực nhận lại:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                _formatCurrency(handover.depositRefundCalculated),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 4. Danh sách tài sản kiểm kê
                const Text(
                  'Danh sách hạng mục kiểm kê',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                if (handover.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('Không có hạng mục kiểm kê nào trong biên bản')),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: handover.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = handover.items[index];
                      return Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.itemName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  Chip(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    label: Text(item.roomAreaDisplayName, style: const TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Tình trạng: ${item.conditionDisplayName}',
                                    style: TextStyle(
                                      color: item.hasDamage ? Colors.red.shade700 : Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (item.repairCost > 0) ...[
                                    const Spacer(),
                                    Text(
                                      'Phí: ${_formatCurrency(item.repairCost)}',
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                              if (item.note != null && item.note!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Ghi chú: ${item.note}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // 5. Khu vực hành động xác nhận
                if (handover.isConfirmed)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Biên bản đã được hai bên ký xác nhận thành công',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else if (handover.isPendingResident)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isActionLoading ? null : _openResidentSignaturePad,
                        icon: const Icon(Icons.draw),
                        label: const Text('Ký tên xác nhận', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isActionLoading ? null : _openDisputeDialog,
                        icon: const Icon(Icons.feedback_outlined, color: Colors.red, size: 18),
                        label: const Text('Có ý kiến / Khiếu nại', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }
}
