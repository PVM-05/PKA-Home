import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/signature_pad_dialog.dart';
import '../../../data/models/apartment_handover_model.dart';
import '../../../data/models/handover_item_model.dart';
import '../../../data/providers/handover_provider.dart';

class InspectionWorkstationScreen extends ConsumerStatefulWidget {
  final String buildingId;
  final String apartmentId;
  final String apartmentCode;
  final String? initialType;
  final String? existingHandoverId;

  const InspectionWorkstationScreen({
    super.key,
    required this.buildingId,
    required this.apartmentId,
    required this.apartmentCode,
    this.initialType = 'move_in',
    this.existingHandoverId,
  });

  @override
  ConsumerState<InspectionWorkstationScreen> createState() => _InspectionWorkstationScreenState();
}

class _InspectionWorkstationScreenState extends ConsumerState<InspectionWorkstationScreen> {
  final _electricityController = TextEditingController(text: '1540.0');
  final _waterController = TextEditingController(text: '85.0');
  final _depositController = TextEditingController(text: '10000000.0');
  final _staffNotesController = TextEditingController();

  late String _handoverType;
  List<HandoverItemModel> _items = [];
  Uint8List? _staffSignatureBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _handoverType = widget.initialType ?? 'move_in';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final repo = ref.read(handoverRepositoryProvider);
    if (widget.existingHandoverId != null) {
      final existing = await repo.fetchHandoverDetail(widget.existingHandoverId!);
      if (existing != null && mounted) {
        setState(() {
          _handoverType = existing.handoverType;
          _electricityController.text = existing.initialElectricityReading.toString();
          _waterController.text = existing.initialWaterReading.toString();
          _depositController.text = existing.depositHeld.toString();
          _staffNotesController.text = existing.staffNotes ?? '';
          _items = List.from(existing.items);
        });
        return;
      }
    }

    // Nếu tạo mới: nạp danh mục tài sản mặc định của căn hộ
    final assets = await repo.fetchAssetsByApartment(widget.apartmentId);
    if (mounted) {
      setState(() {
        _items = assets.map((a) {
          return HandoverItemModel(
            id: 'item_${DateTime.now().microsecondsSinceEpoch}_${a.id}',
            handoverId: widget.existingHandoverId ?? '',
            assetId: a.id,
            itemName: a.name,
            roomArea: a.roomArea,
            quantity: a.quantity,
            condition: a.condition == 'brand_new' ? 'good' : a.condition,
            repairCost: 0.0,
          );
        }).toList();
      });
    }
  }

  double get _totalDeduction {
    return _items.fold(0.0, (sum, item) => sum + item.repairCost);
  }

  double get _depositRefund {
    final deposit = double.tryParse(_depositController.text) ?? 0.0;
    final refund = deposit - _totalDeduction;
    return refund > 0 ? refund : 0.0;
  }

  void _openSignaturePad() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (_) => const SignaturePadDialog(
        title: 'Chữ ký Ban Quản Lý',
        signerRole: 'Đại diện Ban Quản Lý',
      ),
    );

    if (bytes != null && mounted) {
      setState(() {
        _staffSignatureBytes = bytes;
      });
    }
  }

  Future<void> _saveAndSendToResident() async {
    if (_staffSignatureBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng ký tên đại diện Ban Quản Lý trước khi gửi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(handoverRepositoryProvider);
      final depositHeld = double.tryParse(_depositController.text) ?? 0.0;
      final elec = double.tryParse(_electricityController.text) ?? 0.0;
      final water = double.tryParse(_waterController.text) ?? 0.0;

      final handoverModel = ApartmentHandoverModel(
        id: widget.existingHandoverId ?? 'ho_${DateTime.now().millisecondsSinceEpoch}',
        apartmentId: widget.apartmentId,
        buildingId: widget.buildingId,
        handoverType: _handoverType,
        reportCode: 'HO-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-0001',
        handoverDate: DateTime.now(),
        conductedBy: 'staff-01',
        initialElectricityReading: elec,
        initialWaterReading: water,
        depositHeld: depositHeld,
        totalDeduction: _totalDeduction,
        depositRefund: _depositRefund,
        status: 'pending_resident',
        staffNotes: _staffNotesController.text,
        staffSignedAt: DateTime.now(),
        lookupCode: 'HK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        apartmentCode: widget.apartmentCode,
        items: _items,
      );

      await repo.createHandover(handoverModel, _items);
      await repo.signByStaff(handoverModel.id, _staffSignatureBytes!, notes: _staffNotesController.text);

      ref.refresh(buildingHandoversProvider(widget.buildingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi biên bản bàn giao cho cư dân xác nhận thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu biên bản: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạm kiểm kê & bàn giao'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveAndSendToResident,
            icon: const Icon(Icons.send, color: Colors.white, size: 18),
            label: const Text('Gửi cư dân', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Thẻ tổng quan căn hộ
                  Card(
                    color: const Color(0xFF1E3A8A).withOpacity(0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: const Color(0xFF1E3A8A).withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.apartment, size: 36, color: Color(0xFF1E3A8A)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Căn hộ ${widget.apartmentCode}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _handoverType == 'move_in' ? 'Nhận nhà (Move-in)' : 'Trả nhà (Move-out)',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: _handoverType,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'move_in', child: Text('Nhận nhà')),
                              DropdownMenuItem(value: 'move_out', child: Text('Trả nhà')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _handoverType = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Chỉ số công tơ điện nước
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chốt chỉ số đồng hồ bàn giao',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _electricityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Chỉ số điện (kWh)',
                                    prefixIcon: Icon(Icons.bolt, color: Colors.amber),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _waterController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Chỉ số nước (m³)',
                                    prefixIcon: Icon(Icons.water_drop, color: Colors.blue),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_handoverType == 'move_out') ...[
                    const SizedBox(height: 16),
                    // 3. Tài chính cấn trừ cọc
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chiết tính hoàn tiền đặt cọc',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _depositController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Tiền đặt cọc đang giữ (VNĐ)',
                                prefixIcon: Icon(Icons.account_balance_wallet),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Tổng tiền trừ hư hại/thiếu:'),
                                      Text(
                                        '-${_formatCurrency(_totalDeduction)}',
                                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Số tiền cọc hoàn trả cư dân:',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _formatCurrency(_depositRefund),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 4. Danh mục kiểm kê tài sản
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Danh mục kiểm kê hiện trường',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _addNewItem,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Thêm món đồ'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Center(
                        child: Text('Chưa có hạng mục kiểm kê nào. Bấm "Thêm món đồ" để tạo mới.'),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _buildItemCard(item, index);
                      },
                    ),

                  const SizedBox(height: 20),

                  // 5. Ghi chú & Chữ ký Ban Quản Lý
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Xác nhận đại diện Ban Quản Lý',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _staffNotesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Ghi chú thêm của BQL',
                              hintText: 'Nhập ghi chú tổng thể khi bàn giao...',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _openSignaturePad,
                                icon: const Icon(Icons.draw),
                                label: Text(_staffSignatureBytes != null ? 'Ký lại BQL' : 'Ký tên BQL'),
                              ),
                              const SizedBox(width: 12),
                              if (_staffSignatureBytes != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Đã có chữ ký',
                                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildItemCard(HandoverItemModel item, int index) {
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Tình trạng: ', style: TextStyle(fontSize: 13)),
                DropdownButton<String>(
                  value: item.condition,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'good', child: Text('Tốt / Hoạt động')),
                    DropdownMenuItem(value: 'minor_scratch', child: Text('Trầy xước nhẹ')),
                    DropdownMenuItem(value: 'damaged', child: Text('Hư hỏng')),
                    DropdownMenuItem(value: 'missing', child: Text('Thất lạc')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _items[index] = item.copyWith(condition: val);
                      });
                    }
                  },
                ),
              ],
            ),
            if (item.hasDamage) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Chi phí bồi thường (VNĐ)',
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final cost = double.tryParse(val) ?? 0.0;
                        setState(() {
                          _items[index] = item.copyWith(repairCost: cost);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addNewItem() {
    final nameController = TextEditingController();
    String area = 'living_room';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Thêm món đồ kiểm kê'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên món đồ (VD: Tủ lạnh)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: area,
                decoration: const InputDecoration(labelText: 'Khu vực phòng'),
                items: const [
                  DropdownMenuItem(value: 'living_room', child: Text('Phòng khách')),
                  DropdownMenuItem(value: 'bedroom', child: Text('Phòng ngủ')),
                  DropdownMenuItem(value: 'kitchen', child: Text('Nhà bếp')),
                  DropdownMenuItem(value: 'bathroom', child: Text('Nhà vệ sinh')),
                  DropdownMenuItem(value: 'balcony', child: Text('Ban công / Logia')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => area = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  _items.add(
                    HandoverItemModel(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      handoverId: widget.existingHandoverId ?? '',
                      itemName: name,
                      roomArea: area,
                      condition: 'good',
                    ),
                  );
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }
}
