import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../data/models/parcel_model.dart';
import '../../../data/models/visitor_pass_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/front_desk_provider.dart';
import '../../../data/providers/resident_apartment_provider.dart';
import '../widgets/create_visitor_pass_sheet.dart';
import '../widgets/visitor_pass_qr_sheet.dart';

class ResidentVisitorParcelScreen extends ConsumerStatefulWidget {
  const ResidentVisitorParcelScreen({super.key});

  @override
  ConsumerState<ResidentVisitorParcelScreen> createState() =>
      _ResidentVisitorParcelScreenState();
}

class _ResidentVisitorParcelScreenState
    extends ConsumerState<ResidentVisitorParcelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _getEffectiveApartmentId() {
    final selectedId = ref.watch(selectedApartmentIdProvider);
    if (selectedId != null && selectedId.isNotEmpty) {
      return selectedId;
    }
    final apartmentsAsync = ref.watch(residentApartmentsProvider);
    final list = apartmentsAsync.valueOrNull ?? [];
    if (list.isNotEmpty) {
      final first = list.first;
      final id =
          (first['apartment_id'] as String?) ??
          ((first['apartments'] as Map?)?['id'] as String?);
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  void _openCreateVisitorSheet(String apartmentId, String hostUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateVisitorPassSheet(
        apartmentId: apartmentId,
        hostUserId: hostUserId,
        onPassCreated: (pass) {
          _showQrDialog(pass);
        },
      ),
    );
  }

  void _showQrDialog(VisitorPassModel pass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VisitorPassQrSheet(pass: pass),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apartmentId = _getEffectiveApartmentId();
    final authUser = ref.watch(authProvider).valueOrNull;

    if (apartmentId == null || authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đón Khách & Bưu Kiện')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppStateView.emptyContent(
              icon: Icons.apartment_outlined,
              title: 'Chưa có thông tin căn hộ',
              message:
                  'Tài khoản của bạn chưa liên kết với căn hộ nào để quản lý đón khách và bưu kiện.',
            ),
          ),
        ),
      );
    }

    final hostUserId = authUser.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đón Khách & Bưu Kiện'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined), text: 'Khách Viếng Thăm'),
            Tab(
              icon: Icon(Icons.inventory_2_outlined),
              text: 'Bưu Kiện Của Tôi',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVisitorPassesTab(apartmentId, hostUserId),
          _buildParcelsTab(apartmentId),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateVisitorSheet(apartmentId, hostUserId),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Đón Khách Mới'),
            )
          : null,
    );
  }

  // ─── TAB 1: KHÁCH VIẾNG THĂM ───
  Widget _buildVisitorPassesTab(String apartmentId, String hostUserId) {
    final passesAsync = ref.watch(residentVisitorPassesProvider(apartmentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(residentVisitorPassesProvider(apartmentId));
      },
      child: passesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Lỗi khi tải danh sách khách: $err',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(
                    residentVisitorPassesProvider(apartmentId),
                  ),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (passes) {
          if (passes.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có đăng ký đón khách nào',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đăng ký đón người thân, bạn bè hoặc người giao hàng trước để ra vào thuận tiện',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openCreateVisitorSheet(apartmentId, hostUserId),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Tạo Thẻ Khách Đầu Tiên'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: passes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pass = passes[index];
              return _buildVisitorPassCard(pass);
            },
          );
        },
      ),
    );
  }

  Widget _buildVisitorPassCard(VisitorPassModel pass) {
    Color statusColor;
    switch (pass.status) {
      case 'checked_in':
        statusColor = Colors.green;
        break;
      case 'checked_out':
        statusColor = Colors.blueGrey;
        break;
      case 'cancelled':
        statusColor = AppTheme.error;
        break;
      case 'expired':
        statusColor = Colors.orange;
        break;
      case 'pending':
      default:
        statusColor = AppTheme.primary;
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showQrDialog(pass),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pass.visitorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      pass.statusDisplayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      pass.passCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${pass.purposeDisplayName}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (pass.licensePlate != null &&
                  pass.licensePlate!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Biển số: ${pass.licensePlate!}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Dự kiến: ${_dateFormat.format(pass.expectedArrival)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showQrDialog(pass),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Xem Mã QR'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TAB 2: BƯU KIỆN CỦA TÔI ───
  Widget _buildParcelsTab(String apartmentId) {
    final parcelsAsync = ref.watch(residentParcelsProvider(apartmentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(residentParcelsProvider(apartmentId));
      },
      child: parcelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Lỗi khi tải danh sách bưu kiện: $err',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(residentParcelsProvider(apartmentId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (parcels) {
          if (parcels.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Không có bưu kiện nào tại lễ tân',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Khi có shipper giao hàng đến sảnh lễ tân, thông tin kiện hàng và mã PIN sẽ hiển thị tại đây',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: parcels.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final parcel = parcels[index];
              return _buildParcelCard(parcel);
            },
          );
        },
      ),
    );
  }

  Widget _buildParcelCard(ParcelModel parcel) {
    final isArrived = parcel.status == 'arrived';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parcel.carrierDisplayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (parcel.trackingNumber != null)
                          Text(
                            'Vận đơn: ${parcel.trackingNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isArrived
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isArrived
                          ? Colors.amber.withValues(alpha: 0.5)
                          : Colors.green.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    parcel.statusDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isArrived ? Colors.orange[800] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Thông tin mô tả & Kệ lưu trữ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shelves, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vị trí: ${parcel.shelfLocation}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'Đến lúc: ${_dateFormat.format(parcel.arrivedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Khung MÃ PIN NHẬN HÀNG NỔI BẬT NẾU CHỜ NHẬN
            if (isArrived) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'MÃ PIN NHẬN HÀNG BẢO MẬT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          parcel.pickupPin,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6.0,
                            fontFamily: 'monospace',
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Sao chép mã PIN',
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: parcel.pickupPin),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép mã PIN nhận hàng'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cung cấp mã PIN 6 số này cho lễ tân tại quầy để nhận kiện hàng',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đã bàn giao lúc: ${parcel.collectedAt != null ? _dateFormat.format(parcel.collectedAt!) : 'Không rõ'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
