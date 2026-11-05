import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/security/visitor_pass_token_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/providers/front_desk_provider.dart';
import '../widgets/handover_parcel_dialog.dart';
import '../widgets/receive_parcel_sheet.dart';

class FrontDeskWorkstationScreen extends ConsumerStatefulWidget {
  const FrontDeskWorkstationScreen({super.key});

  @override
  ConsumerState<FrontDeskWorkstationScreen> createState() =>
      _FrontDeskWorkstationScreenState();
}

class _FrontDeskWorkstationScreenState
    extends ConsumerState<FrontDeskWorkstationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchVisitorCtrl = TextEditingController();
  final _searchParcelCtrl = TextEditingController();
  String _visitorSearch = '';
  String _parcelSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchVisitorCtrl.dispose();
    _searchParcelCtrl.dispose();
    super.dispose();
  }

  void _showScanVisitorDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Quét / Nhập Mã Vé Khách'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập mã vé hoặc quét mã QR từ điện thoại khách:'),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'VD: VP-202611-00001',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
                border: OutlineInputBorder(),
              ),
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
              final code = codeCtrl.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              _processVisitorCode(code);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _processVisitorCode(String rawCode) async {
    final trimmed = rawCode.trim();
    String code = trimmed;
    String? qrPayload;

    if (trimmed.startsWith('PKAPASS')) {
      final parseResult = VisitorPassTokenService.verifyAndParseQrPayload(
        trimmed,
      );
      if (!parseResult.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                parseResult.errorMessage ?? 'Mã QR vé khách không hợp lệ',
              ),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }
      code = parseResult.passCode ?? trimmed;
      qrPayload = trimmed;
    }

    try {
      final repo = ref.read(frontDeskRepositoryProvider);
      final res = await repo.checkInVisitor(
        passCode: code,
        qrPayload: qrPayload,
      );

      ref.invalidate(visitorPassesProvider);
      ref.invalidate(frontDeskStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] as String? ?? 'Xử lý vé thành công'),
            backgroundColor: res['success'] == true
                ? AppTheme.success
                : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(frontDeskStatsProvider);

    return RoleGuard(
      permission: AppPermissions.residentManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trạm Lễ Tân & An Ninh'),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.badge_outlined), text: 'Khách vào ra'),
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Bưu kiện sảnh',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Dải KPI thời gian thực
            statsAsync.when(
              data: (stats) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Khách hôm nay',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${stats.expectedVisitorsToday} lượt',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Trong tòa nhà',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${stats.visitorsInBuilding} người',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: stats.overdueParcels > 0
                                ? AppTheme.error.withValues(alpha: 0.1)
                                : Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: stats.overdueParcels > 0
                                  ? AppTheme.error.withValues(alpha: 0.3)
                                  : Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stats.overdueParcels > 0
                                    ? 'Tồn quá 3 ngày'
                                    : 'Bưu kiện kệ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: stats.overdueParcels > 0
                                      ? AppTheme.error
                                      : Colors.amber.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${stats.pendingParcels} kiện',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildVisitorsTab(), _buildParcelsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: KHÁCH VÀO RA ───
  Widget _buildVisitorsTab() {
    final visitorsAsync = ref.watch(
      visitorPassesProvider((status: null, apartmentId: null)),
    );
    final dateFormat = DateFormat('dd/MM HH:mm');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchVisitorCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo mã vé, tên khách, căn hộ...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _visitorSearch = val.toLowerCase().trim()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showScanVisitorDialog,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Quét vé'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: visitorsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(formatErrorMessage(err))),
            data: (passes) {
              final filtered = passes.where((p) {
                if (_visitorSearch.isEmpty) return true;
                return p.passCode.toLowerCase().contains(_visitorSearch) ||
                    p.visitorName.toLowerCase().contains(_visitorSearch) ||
                    (p.apartmentCode?.toLowerCase().contains(_visitorSearch) ??
                        false) ||
                    (p.licensePlate?.toLowerCase().contains(_visitorSearch) ??
                        false);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Không có dữ liệu vé khách viếng thăm'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final pass = filtered[index];
                  final isCheckedIn = pass.status == 'checked_in';

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    borderRadius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              pass.passCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isCheckedIn
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : (pass.status == 'pending'
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : Colors.grey.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                pass.statusDisplayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCheckedIn
                                      ? Colors.green.shade800
                                      : (pass.status == 'pending'
                                            ? Colors.blue.shade800
                                            : Colors.grey.shade700),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pass.visitorName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.apartment,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Căn hộ ${pass.apartmentCode ?? pass.apartmentId}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.directions_car_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pass.vehicleDisplayName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Dự kiến: ${dateFormat.format(pass.expectedArrival)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (pass.isCheckInAllowed)
                              ElevatedButton(
                                onPressed: () =>
                                    _processVisitorCode(pass.passCode),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(60, 32),
                                ),
                                child: const Text(
                                  'Vào',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            if (pass.isCheckOutAllowed)
                              OutlinedButton(
                                onPressed: () async {
                                  final repo = ref.read(
                                    frontDeskRepositoryProvider,
                                  );
                                  await repo.checkOutVisitor(
                                    passCode: pass.passCode,
                                  );
                                  ref.invalidate(visitorPassesProvider);
                                  ref.invalidate(frontDeskStatsProvider);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange.shade800,
                                  side: BorderSide(
                                    color: Colors.orange.shade800,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(60, 32),
                                ),
                                child: const Text(
                                  'Rời tòa',
                                  style: TextStyle(fontSize: 12),
                                ),
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

  // ─── TAB 2: BƯU KIỆN SẢNH ───
  Widget _buildParcelsTab() {
    final parcelsAsync = ref.watch(
      parcelsProvider((status: null, apartmentId: null)),
    );
    final dateFormat = DateFormat('dd/MM HH:mm');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchParcelCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiện hàng, căn hộ, mã vận đơn...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _parcelSearch = val.toLowerCase().trim()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => ReceiveParcelSheet.show(context),
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Nhận kiện'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: parcelsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(formatErrorMessage(err))),
            data: (parcels) {
              final filtered = parcels.where((p) {
                if (_parcelSearch.isEmpty) return true;
                return p.parcelCode.toLowerCase().contains(_parcelSearch) ||
                    (p.apartmentCode?.toLowerCase().contains(_parcelSearch) ??
                        false) ||
                    (p.trackingNumber?.toLowerCase().contains(_parcelSearch) ??
                        false) ||
                    (p.recipientName?.toLowerCase().contains(_parcelSearch) ??
                        false);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Không có kiện hàng nào tại quầy'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final parcel = filtered[index];
                  final isArrived = parcel.status == 'arrived';

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    borderRadius: 14,
                    borderColor: parcel.isOverdueStorage
                        ? AppTheme.error.withValues(alpha: 0.6)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              parcel.parcelCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isArrived
                                    ? (parcel.isOverdueStorage
                                          ? AppTheme.error.withValues(
                                              alpha: 0.1,
                                            )
                                          : Colors.amber.withValues(alpha: 0.1))
                                    : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                parcel.isOverdueStorage
                                    ? 'Tồn quá 3 ngày'
                                    : parcel.statusDisplayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isArrived
                                      ? (parcel.isOverdueStorage
                                            ? AppTheme.error
                                            : Colors.amber.shade900)
                                      : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    parcel.description ?? 'Bưu phẩm tiêu chuẩn',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Căn hộ: ${parcel.apartmentCode ?? parcel.apartmentId} ${parcel.recipientName != null ? "(${parcel.recipientName})" : ""}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${parcel.carrierDisplayName} - ${parcel.shelfLocation}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đến: ${dateFormat.format(parcel.arrivedAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (isArrived)
                              ElevatedButton.icon(
                                onPressed: () =>
                                    HandoverParcelDialog.show(context, parcel),
                                icon: const Icon(Icons.outbox, size: 16),
                                label: const Text('Bàn giao'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(60, 32),
                                ),
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
