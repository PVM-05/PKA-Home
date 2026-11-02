import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/parking_slot_model.dart';
import '../../../data/models/visitor_parking_ticket_model.dart';
import '../../../data/providers/parking_provider.dart';

class ParkingManagementScreen extends ConsumerStatefulWidget {
  const ParkingManagementScreen({super.key});

  @override
  ConsumerState<ParkingManagementScreen> createState() => _ParkingManagementScreenState();
}

class _ParkingManagementScreenState extends ConsumerState<ParkingManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showCheckInDialog() {
    final plateController = TextEditingController();
    final noteController = TextEditingController();
    String selectedType = 'motorcycle';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.login_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Check-in Xe Vãng Lai'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Biển số xe',
                    hintText: 'Ví dụ: 30A-999.88',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Loại phương tiện:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.two_wheeler, size: 16),
                            SizedBox(width: 6),
                            Text('Xe máy'),
                          ],
                        ),
                        selected: selectedType == 'motorcycle',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedType = 'motorcycle');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car, size: 16),
                            SizedBox(width: 6),
                            Text('Ô tô'),
                          ],
                        ),
                        selected: selectedType == 'car',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedType = 'car');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú / Khách phòng nào',
                    hintText: 'Ví dụ: Khách thăm phòng A0101...',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final plate = plateController.text.trim().toUpperCase();
                if (plate.isEmpty) return;
                Navigator.pop(ctx);

                final repo = ref.read(parkingRepositoryProvider);
                final res = await repo.createVisitorTicket(
                  licensePlate: plate,
                  vehicleType: selectedType,
                  note: noteController.text.trim(),
                );

                if (mounted) {
                  ref.invalidate(activeVisitorTicketsProvider);
                  ref.invalidate(parkingCapacityStatsProvider);
                  if (res['success'] == true && res['ticket'] is VisitorParkingTicketModel) {
                    _showTicketDetailModal(res['ticket'] as VisitorParkingTicketModel);
                  }
                }
              },
              child: const Text('Tạo Vé Xe'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTicketDetailModal(VisitorParkingTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vé Xe Điện Tử: ${ticket.ticketCode}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Biển số: ${ticket.licensePlate} (${ticket.displayVehicleType})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              width: 180,
              child: QrImageView(
                data: ticket.qrPayload,
                version: QrVersions.auto,
                size: 180,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Giờ vào: ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.checkInAt)}',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutDialog(VisitorParkingTicketModel ticket) async {
    final repo = ref.read(parkingRepositoryProvider);
    final feeRes = await repo.calculateVisitorFee(ticket.id);
    final fee = (feeRes['fee_amount'] as num?)?.toDouble() ?? ticket.feeAmount;
    final hours = (feeRes['total_hours'] as num?)?.toInt() ?? 1;

    final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formattedFee = format.format(fee).trim();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Check-out & Thu Phí'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Biển số: ${ticket.licensePlate}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Loại xe: ${ticket.displayVehicleType}'),
            Text('Thời gian đã đỗ: $hours giờ'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng tiền thu:', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(formattedFee, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await repo.checkoutVisitorTicket(ticketId: ticket.id, paymentMethod: 'cash');
              ref.invalidate(activeVisitorTicketsProvider);
              ref.invalidate(parkingCapacityStatsProvider);
            },
            child: const Text('Thu Tiền Mặt'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await repo.checkoutVisitorTicket(ticketId: ticket.id, paymentMethod: 'vietqr');
              ref.invalidate(activeVisitorTicketsProvider);
              ref.invalidate(parkingCapacityStatsProvider);
            },
            child: const Text('Quét VietQR'),
          ),
        ],
      ),
    );
  }

  void _showAssignSlotDialog(ParkingSlotModel slot) {
    final plateController = TextEditingController();
    final aptController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gán Ô Đỗ ${slot.slotNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: plateController,
              decoration: const InputDecoration(
                labelText: 'Biển số xe',
                hintText: 'Ví dụ: 30A-123.45',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aptController,
              decoration: const InputDecoration(
                labelText: 'Mã căn hộ',
                hintText: 'Ví dụ: A0101',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final plate = plateController.text.trim().toUpperCase();
              final apt = aptController.text.trim().toUpperCase();
              if (plate.isEmpty) return;
              Navigator.pop(ctx);

              final repo = ref.read(parkingRepositoryProvider);
              await repo.assignSlot(
                slotId: slot.id,
                vehicleId: 'veh-${slot.id}',
                apartmentId: 'apt-${slot.id}',
                licensePlate: plate,
                apartmentCode: apt,
              );
              ref.invalidate(parkingSlotsProvider);
              ref.invalidate(parkingCapacityStatsProvider);
            },
            child: const Text('Xác nhận gán'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(parkingCapacityStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Bãi Xe & Ô Đỗ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.grid_view_rounded), text: 'Sơ đồ Ô đỗ'),
            Tab(icon: Icon(Icons.local_parking_rounded), text: 'Trạm soát vé cổng'),
          ],
        ),
      ),
      body: Column(
        children: [
          // KPI strip sức chứa
          statsAsync.when(
            data: (stats) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: _buildKpiBox(
                      icon: Icons.directions_car,
                      label: 'Ô tô hầm',
                      value: '${stats.carOccupied}/${stats.carTotal}',
                      subtext: 'Trống ${stats.carAvailable}',
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiBox(
                      icon: Icons.two_wheeler,
                      label: 'Xe máy hầm',
                      value: '${stats.motoOccupied}/${stats.motoTotal}',
                      subtext: 'Trống ${stats.motoAvailable}',
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiBox(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Xe vãng lai',
                      value: '${stats.visitorCount}',
                      subtext: 'Đang gửi',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 70, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Nội dung 2 tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSlotsTab(),
                _buildGateWorkstationTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(subtext, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSlotsTab() {
    final slotsAsync = ref.watch(parkingSlotsProvider);
    final filter = ref.watch(parkingFilterProvider);

    return Column(
      children: [
        // Thanh bộ lọc
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Tìm số ô, biển số, mã căn...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) {
                    ref.read(parkingFilterProvider.notifier).state = filter.copyWith(searchQuery: val);
                  },
                ),
              ),
            ],
          ),
        ),

        // Chips lọc nhanh
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tất cả'),
                selected: filter.zone == null && filter.type == null,
                onSelected: (_) {
                  ref.read(parkingFilterProvider.notifier).state = const ParkingFilter();
                },
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Tầng B1'),
                selected: filter.zone == 'B1',
                onSelected: (val) {
                  ref.read(parkingFilterProvider.notifier).state = filter.copyWith(zone: val ? 'B1' : null);
                },
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Tầng B2'),
                selected: filter.zone == 'B2',
                onSelected: (val) {
                  ref.read(parkingFilterProvider.notifier).state = filter.copyWith(zone: val ? 'B2' : null);
                },
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Ô tô'),
                selected: filter.type == 'car',
                onSelected: (val) {
                  ref.read(parkingFilterProvider.notifier).state = filter.copyWith(type: val ? 'car' : null);
                },
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Xe máy'),
                selected: filter.type == 'motorcycle',
                onSelected: (val) {
                  ref.read(parkingFilterProvider.notifier).state = filter.copyWith(type: val ? 'motorcycle' : null);
                },
              ),
            ],
          ),
        ),

        // Lưới các ô đỗ
        Expanded(
          child: slotsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Lỗi: $err')),
            data: (slots) {
              if (slots.isEmpty) {
                return const Center(child: Text('Không có ô đỗ nào phù hợp tiêu chí tìm kiếm'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 140,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  return _buildSlotCard(slot);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard(ParkingSlotModel slot) {
    Color cardColor;
    Color borderColor;

    if (slot.isOccupied) {
      cardColor = AppTheme.primary.withValues(alpha: 0.05);
      borderColor = AppTheme.primary.withValues(alpha: 0.3);
    } else if (slot.isMaintenance) {
      cardColor = Colors.orange.withValues(alpha: 0.05);
      borderColor = Colors.orange.withValues(alpha: 0.3);
    } else {
      cardColor = Colors.green.withValues(alpha: 0.05);
      borderColor = Colors.green.withValues(alpha: 0.3);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slot.slotNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Icon(
                slot.isCar ? Icons.directions_car : Icons.two_wheeler,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          if (slot.isOccupied) ...[
            Text(
              slot.licensePlate ?? 'Đã có xe',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    slot.apartmentCode ?? 'Căn hộ',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () async {
                    final repo = ref.read(parkingRepositoryProvider);
                    await repo.releaseSlot(slot.id);
                    ref.invalidate(parkingSlotsProvider);
                    ref.invalidate(parkingCapacityStatsProvider);
                  },
                  child: const Text(
                    'Giải phóng',
                    style: TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              slot.displayStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: slot.isAvailable ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => _showAssignSlotDialog(slot),
                child: const Text('Gán xe', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGateWorkstationTab() {
    final ticketsAsync = ref.watch(activeVisitorTicketsProvider);

    return Column(
      children: [
        // Thanh tác vụ gác cổng
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCheckInDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Check-in Xe Vào'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Danh sách xe đang gửi
        Expanded(
          child: ticketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Lỗi: $err')),
            data: (tickets) {
              if (tickets.isEmpty) {
                return const Center(
                  child: Text('Hiện không có xe vãng lai nào đang gửi trong bãi'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: tickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  return AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  ticket.isCar ? Icons.directions_car : Icons.two_wheeler,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  ticket.licensePlate,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ticket.displayStatus,
                                style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Loại xe: ${ticket.displayVehicleType}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Mã vé: ${ticket.ticketCode}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vào lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.checkInAt)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        if (ticket.note != null && ticket.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Ghi chú: ${ticket.note}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                        const Divider(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showTicketDetailModal(ticket),
                              icon: const Icon(Icons.qr_code, size: 18),
                              label: const Text('Xem mã QR vé'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showCheckoutDialog(ticket),
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('Check-out & Thu tiền'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
