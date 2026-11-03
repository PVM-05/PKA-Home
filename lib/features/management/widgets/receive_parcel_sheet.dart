import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/providers/dashboard_providers.dart';
import '../../../data/providers/front_desk_provider.dart';

class ReceiveParcelSheet extends ConsumerStatefulWidget {
  const ReceiveParcelSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReceiveParcelSheet(),
    );
  }

  @override
  ConsumerState<ReceiveParcelSheet> createState() => _ReceiveParcelSheetState();
}

class _ReceiveParcelSheetState extends ConsumerState<ReceiveParcelSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedApartmentId;
  final _recipientCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _carrier = 'SPX';
  String _shelfLocation = 'Kệ A1';
  bool _isSubmitting = false;

  final List<String> _carriers = [
    'SPX',
    'GHTK',
    'GHN',
    'Viettel Post',
    'J&T',
    'NinjaVan',
    'Grab',
    'Khác',
  ];

  final List<String> _shelves = [
    'Kệ A1',
    'Kệ A2',
    'Kệ B1',
    'Kệ B2',
    'Tủ mát',
    'Bàn lễ tân',
    'Khu vực hàng cồng kềnh',
  ];

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _trackingCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn căn hộ nhận hàng'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(frontDeskRepositoryProvider);
      final newParcel = await repo.receiveParcel(
        apartmentId: _selectedApartmentId!,
        recipientName: _recipientCtrl.text.trim().isNotEmpty ? _recipientCtrl.text.trim() : null,
        carrier: _carrier,
        trackingNumber: _trackingCtrl.text.trim().isNotEmpty ? _trackingCtrl.text.trim() : null,
        description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        shelfLocation: _shelfLocation,
        staffId: 'staff-current',
      );

      ref.invalidate(parcelsProvider);
      ref.invalidate(frontDeskStatsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tiếp nhận thành công kiện hàng ${newParcel.parcelCode} - Mã PIN: ${newParcel.pickupPin}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsStreamProvider);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Tiếp Nhận Bưu Kiện Từ Shipper',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chọn căn hộ
              apartmentsAsync.when(
                data: (apartments) {
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Căn hộ nhận hàng *',
                      prefixIcon: Icon(Icons.apartment),
                      border: OutlineInputBorder(),
                    ),
                    items: apartments.map((apt) {
                      final aptId = apt['id'] as String? ?? '';
                      final code = apt['code'] as String? ?? 'N/A';
                      return DropdownMenuItem<String>(
                        value: aptId,
                        child: Text('Căn hộ $code'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedApartmentId = val),
                    validator: (val) => val == null ? 'Vui lòng chọn căn hộ' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Không tải được danh sách căn hộ'),
              ),
              const SizedBox(height: 12),

              // Tên người nhận
              TextFormField(
                controller: _recipientCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên người nhận trên kiện (tùy chọn)',
                  hintText: 'VD: Chị Lan, Anh Tuấn',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Đơn vị vận chuyển & Kệ lưu kho
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _carrier,
                      decoration: const InputDecoration(
                        labelText: 'Hãng vận chuyển',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _carriers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _carrier = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _shelfLocation,
                      decoration: const InputDecoration(
                        labelText: 'Vị trí kệ',
                        prefixIcon: Icon(Icons.shelves),
                        border: OutlineInputBorder(),
                      ),
                      items: _shelves.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _shelfLocation = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mã vận đơn
              TextFormField(
                controller: _trackingCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã vận đơn (tùy chọn)',
                  hintText: 'VD: SPXVN12345678',
                  prefixIcon: Icon(Icons.qr_code),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Mô tả gói hàng
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mô tả bưu kiện',
                  hintText: 'VD: Hộp giày, thùng hoa quả...',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSubmitting ? 'Đang lưu...' : 'Xác Nhận Lưu Vào Kệ Sảnh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

