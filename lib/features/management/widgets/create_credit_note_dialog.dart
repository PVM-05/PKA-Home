import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/accounting_providers.dart';

class CreateCreditNoteDialog extends ConsumerStatefulWidget {
  final String buildingId;
  final String apartmentId;
  final String apartmentCode;
  final String? invoiceId;

  const CreateCreditNoteDialog({
    super.key,
    required this.buildingId,
    required this.apartmentId,
    required this.apartmentCode,
    this.invoiceId,
  });

  @override
  ConsumerState<CreateCreditNoteDialog> createState() => _CreateCreditNoteDialogState();
}

class _CreateCreditNoteDialogState extends ConsumerState<CreateCreditNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  String _noteType = 'CREDIT';
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền điều chỉnh phải lớn hơn 0 đ')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(accountingRepositoryProvider);
      final result = await repo.issueCreditNote(
        buildingId: widget.buildingId,
        apartmentId: widget.apartmentId,
        invoiceId: widget.invoiceId,
        noteType: _noteType,
        amount: amount,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result != null && result['success'] == true) {
          ref.invalidate(apartmentBalanceProvider(widget.apartmentId));
          ref.invalidate(apartmentLedgerEntriesProvider(widget.apartmentId));
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã lập thành công phiếu điều chỉnh ${result['credit_note_code']}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?['error']?.toString() ?? 'Lỗi khi lập phiếu điều chỉnh'),
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
      title: Text('Lập Phiếu Điều Chỉnh - Căn ${widget.apartmentCode}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Loại điều chỉnh:', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Giảm nợ (Credit)'),
                      value: 'CREDIT',
                      groupValue: _noteType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => _noteType = val);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Tăng nợ (Debit)'),
                      value: 'DEBIT',
                      groupValue: _noteType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => _noteType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền điều chỉnh (VNĐ)',
                  hintText: 'VD: 250000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số tiền';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Lý do điều chỉnh (Bắt buộc)',
                  hintText: 'VD: Sai lệch chỉ số đồng hồ nước kỳ tháng 10...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập lý do điều chỉnh';
                  return null;
                },
              ),
            ],
          ),
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
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Lập Phiếu'),
        ),
      ],
    );
  }
}
