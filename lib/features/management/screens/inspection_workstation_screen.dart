import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
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
  ConsumerState<InspectionWorkstationScreen> createState() =>
      _InspectionWorkstationScreenState();
}

class _InspectionWorkstationScreenState
    extends ConsumerState<InspectionWorkstationScreen> {
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

  @override
  void dispose() {
    _electricityController.dispose();
    _waterController.dispose();
    _depositController.dispose();
    _staffNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final repo = ref.read(handoverRepositoryProvider);
    if (widget.existingHandoverId != null) {
      final existing =
          await repo.fetchHandoverDetail(widget.existingHandoverId!);
      if (existing != null && mounted) {
        setState(() {
          _handoverType = existing.handoverType;
          _electricityController.text =
              existing.initialElectricityReading.toString();
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
          backgroundColor: AppTheme.warning,
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
        id: widget.existingHandoverId ??
            'ho_${DateTime.now().millisecondsSinceEpoch}',
        apartmentId: widget.apartmentId,
        buildingId: widget.buildingId,
        handoverType: _handoverType,
        reportCode:
            'HO-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-0001',
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
        lookupCode:
            'HK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        apartmentCode: widget.apartmentCode,
        items: _items,
      );

      await repo.createHandover(handoverModel, _items);
      await repo.signByStaff(handoverModel.id, _staffSignatureBytes!,
          notes: _staffNotesController.text);

      ref.invalidate(buildingHandoversProvider(widget.buildingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Đã gửi biên bản bàn giao cho cư dân xác nhận thành công!'),
            backgroundColor: AppStatusColors.paid,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu biên bản: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạm kiểm kê & bàn giao'),
        elevation: 0.5,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveAndSendToResident,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Gửi cư dân'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: isDesktop
                    ? _buildDesktopLayout()
                    : _buildMobileLayout(),
              ),
            ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cột trái: Tổng quan, Chỉ số, Bảng cọc, Chữ ký
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildApartmentOverviewCard(),
                  const SizedBox(height: 16),
                  _buildMetersCard(),
                  if (_handoverType == 'move_out') ...[
                    const SizedBox(height: 16),
                    _buildDepositCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildStaffSignatureCard(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Cột phải: Danh mục kiểm kê tài sản
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildItemsHeader(),
                  const SizedBox(height: 12),
                  _buildItemsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildApartmentOverviewCard(),
          const SizedBox(height: 16),
          _buildMetersCard(),
          if (_handoverType == 'move_out') ...[
            const SizedBox(height: 16),
            _buildDepositCard(),
          ],
          const SizedBox(height: 16),
          _buildItemsHeader(),
          const SizedBox(height: 12),
          _buildItemsList(),
          const SizedBox(height: 20),
          _buildStaffSignatureCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildApartmentOverviewCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.apartment,
                    size: 28, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Căn hộ ${widget.apartmentCode}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _handoverType == 'move_in'
                          ? 'Nhận nhà (Move-in)'
                          : 'Trả nhà (Move-out)',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _handoverType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Loại bàn giao',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'move_in', child: Text('Nhận nhà (Move-in)')),
              DropdownMenuItem(
                  value: 'move_out', child: Text('Trả nhà (Move-out)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _handoverType = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetersCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chốt chỉ số đồng hồ bàn giao',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 280;
              if (isNarrow) {
                return Column(
                  children: [
                    TextField(
                      controller: _electricityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Chỉ số điện (kWh)',
                        prefixIcon: Icon(Icons.bolt, color: Colors.amber),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _waterController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Chỉ số nước (m³)',
                        prefixIcon: Icon(Icons.water_drop, color: Colors.blue),
                      ),
                    ),
                  ],
                );
              }
              return Row(
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDepositCard() {
    return AppCard(
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
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Tổng tiền trừ hư hại/thiếu:'),
                    Text(
                      '-${_formatCurrency(_totalDeduction)}',
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Số tiền cọc hoàn trả cư dân:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatCurrency(_depositRefund),
                      style: const TextStyle(
                        color: AppStatusColors.paid,
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
    );
  }

  Widget _buildItemsHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Danh mục kiểm kê hiện trường',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: _addNewItem,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Thêm món đồ'),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child:
              Text('Chưa có hạng mục kiểm kê nào. Bấm "Thêm món đồ" để tạo mới.'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildItemCard(item, index);
      },
    );
  }

  Widget _buildItemCard(HandoverItemModel item, int index) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                label: Text(
                  item.roomAreaDisplayName,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: item.condition,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tình trạng tài sản',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(
                value: 'good',
                child: Text('Tốt / Hoạt động'),
              ),
              DropdownMenuItem(
                value: 'minor_scratch',
                child: Text('Trầy xước nhẹ'),
              ),
              DropdownMenuItem(
                value: 'damaged',
                child: Text('Hư hỏng'),
              ),
              DropdownMenuItem(
                value: 'missing',
                child: Text('Thất lạc'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _items[index] = item.copyWith(condition: val);
                });
              }
            },
          ),
          if (item.hasDamage) ...[
            const SizedBox(height: 6),
            TextField(
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
          ],
        ],
      ),
    );
  }

  Widget _buildStaffSignatureCard() {
    return AppCard(
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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _openSignaturePad,
                icon: const Icon(Icons.draw),
                label: Text(
                  _staffSignatureBytes != null
                      ? 'Ký lại BQL'
                      : 'Ký tên BQL',
                ),
              ),
              if (_staffSignatureBytes != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppStatusColors.paid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          color: AppStatusColors.paid, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Đã có chữ ký',
                        style: TextStyle(
                          color: AppStatusColors.paid,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
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
                decoration: const InputDecoration(
                  labelText: 'Tên món đồ (VD: Tủ lạnh)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: area,
                decoration: const InputDecoration(labelText: 'Khu vực phòng'),
                items: const [
                  DropdownMenuItem(
                    value: 'living_room',
                    child: Text('Phòng khách'),
                  ),
                  DropdownMenuItem(
                    value: 'bedroom',
                    child: Text('Phòng ngủ'),
                  ),
                  DropdownMenuItem(
                    value: 'kitchen',
                    child: Text('Nhà bếp'),
                  ),
                  DropdownMenuItem(
                    value: 'bathroom',
                    child: Text('Nhà vệ sinh'),
                  ),
                  DropdownMenuItem(
                    value: 'balcony',
                    child: Text('Ban công / Logia'),
                  ),
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
