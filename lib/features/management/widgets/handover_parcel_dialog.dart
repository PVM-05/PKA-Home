import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/parcel_model.dart';
import '../../../data/providers/front_desk_provider.dart';

class HandoverParcelDialog extends ConsumerStatefulWidget {
  final ParcelModel parcel;

  const HandoverParcelDialog({super.key, required this.parcel});

  static Future<void> show(BuildContext context, ParcelModel parcel) {
    return showDialog(
      context: context,
      builder: (_) => HandoverParcelDialog(parcel: parcel),
    );
  }

  @override
  ConsumerState<HandoverParcelDialog> createState() => _HandoverParcelDialogState();
}

class _HandoverParcelDialogState extends ConsumerState<HandoverParcelDialog> {
  final _pinCtrl = TextEditingController();
  final _collectorCtrl = TextEditingController(text: 'Chủ hộ trực tiếp nhận');
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _collectorCtrl.dispose();
    super.dispose();
  }

  Future<void> _handover() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mã PIN lấy hàng 6 số');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(frontDeskRepositoryProvider);
      final res = await repo.collectParcel(
        parcelId: widget.parcel.id,
        pickupPin: pin,
        staffId: 'staff-current',
        collectedBy: _collectorCtrl.text.trim(),
      );

      if (res['success'] == true) {
        ref.invalidate(parcelsProvider);
        ref.invalidate(frontDeskStatsProvider);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bàn giao bưu kiện thành công cho cư dân!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        setState(() => _errorMessage = res['message'] as String? ?? 'Mã PIN không khớp');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.outbox_rounded, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Bàn giao kiện ${widget.parcel.parcelCode}')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Căn hộ: ${widget.parcel.apartmentCode ?? widget.parcel.apartmentId}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Hãng: ${widget.parcel.carrierDisplayName} - ${widget.parcel.shelfLocation}'),
                  if (widget.parcel.description != null) ...[
                    const SizedBox(height: 4),
                    Text('Mô tả: ${widget.parcel.description}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhập mã PIN lấy hàng (6 số từ cư dân): *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '••••••',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _collectorCtrl,
              decoration: const InputDecoration(
                labelText: 'Người nhận thực tế',
                hintText: 'VD: Chủ hộ, Con gái...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handover,
          child: Text(_isSubmitting ? 'Đang kiểm tra...' : 'Xác Nhận Bàn Giao'),
        ),
      ],
    );
  }
}

