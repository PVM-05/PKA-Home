import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/accounting_providers.dart';

class ClosePeriodDialog extends ConsumerStatefulWidget {
  final String buildingId;
  final String? initialPeriod;

  const ClosePeriodDialog({
    super.key,
    required this.buildingId,
    this.initialPeriod,
  });

  @override
  ConsumerState<ClosePeriodDialog> createState() => _ClosePeriodDialogState();
}

class _ClosePeriodDialogState extends ConsumerState<ClosePeriodDialog> {
  late final TextEditingController _periodController;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final defaultPeriod = widget.initialPeriod ?? DateFormat('yyyy-MM').format(DateTime.now());
    _periodController = TextEditingController(text: defaultPeriod);
  }

  @override
  void dispose() {
    _periodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final period = _periodController.text.trim();
    if (period.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(accountingRepositoryProvider);
      final result = await repo.closeAccountingPeriod(
        buildingId: widget.buildingId,
        period: period,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result != null && result['success'] == true) {
          ref.invalidate(accountingPeriodsProvider(widget.buildingId));
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã khóa sổ thành công kỳ kế toán $period'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?['error']?.toString() ?? 'Lỗi khi khóa sổ kỳ kế toán'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_clock_outlined, color: Colors.orange),
          SizedBox(width: 8),
          Text('Khóa Sổ Kỳ Kế Toán'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lưu ý: Sau khi khóa sổ, toàn bộ hóa đơn và số liệu sổ cái trong kỳ này sẽ bị khóa cứng (bất biến) để đảm bảo tính toàn vẹn kiểm toán.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _periodController,
              decoration: const InputDecoration(
                labelText: 'Kỳ kế toán (YYYY-MM)',
                hintText: 'VD: 2026-10',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú khóa sổ (Tùy chọn)',
                hintText: 'VD: Đã đối soát xong với báo cáo ngân hàng...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Xác Nhận Khóa Sổ'),
        ),
      ],
    );
  }
}
