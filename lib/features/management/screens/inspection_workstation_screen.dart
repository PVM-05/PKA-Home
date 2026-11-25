import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/supabase_config.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
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
  final bool isReadOnly;

  const InspectionWorkstationScreen({
    super.key,
    required this.buildingId,
    required this.apartmentId,
    required this.apartmentCode,
    this.initialType = 'move_in',
    this.existingHandoverId,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<InspectionWorkstationScreen> createState() =>
      _InspectionWorkstationScreenState();
}

class _InspectionWorkstationScreenState
    extends ConsumerState<InspectionWorkstationScreen> {
  // P0-#2: Để trống chỉ số mặc định, bắt buộc nhập số liệu thực tế tại hiện trường
  final _electricityController = TextEditingController();
  final _waterController = TextEditingController();
  final _depositController = TextEditingController();
  final _staffNotesController = TextEditingController();

  final Map<String, TextEditingController> _itemCostControllers = {};

  late String _handoverType;
  List<HandoverItemModel> _items = [];
  Uint8List? _staffSignatureBytes;
  String? _existingStaffSigUrl;
  String? _existingResidentSigUrl;
  bool _isConfirmedOrCompleted = false;
  bool _isLoading = false;

  bool get _effectiveReadOnly => widget.isReadOnly || _isConfirmedOrCompleted;

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
    for (final c in _itemCostControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final repo = ref.read(handoverRepositoryProvider);
    if (widget.existingHandoverId != null) {
      final existing = await repo.fetchHandoverDetail(
        widget.existingHandoverId!,
      );
      if (existing != null && mounted) {
        setState(() {
          _handoverType = existing.handoverType;
          _electricityController.text = existing.initialElectricityReading > 0
              ? existing.initialElectricityReading.toString()
              : '';
          _waterController.text = existing.initialWaterReading > 0
              ? existing.initialWaterReading.toString()
              : '';
          _depositController.text = existing.depositHeld > 0
              ? formatMoney(existing.depositHeld.toInt(), includeSymbol: false)
              : '';
          _staffNotesController.text = existing.staffNotes ?? '';
          _items = List.from(existing.items);
          _existingStaffSigUrl = existing.staffSignatureUrl;
          _existingResidentSigUrl = existing.residentSignatureUrl;
          if (existing.status == 'confirmed' ||
              existing.status == 'completed') {
            _isConfirmedOrCompleted = true;
          }
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

  // P0-#4: Sửa lỗi tính khấu trừ - Chỉ cộng khi tình trạng khác 'good' và có chi phí sửa
  double get _totalDeduction {
    return _items
        .where((item) => item.condition != 'good' && item.repairCost > 0)
        .fold(0.0, (sum, item) => sum + item.repairCost);
  }

  double get _depositRefund {
    final deposit = parseMoney(_depositController.text).toDouble();
    final refund = deposit - _totalDeduction;
    return refund > 0 ? refund : 0.0;
  }

  void _openSignaturePad() async {
    if (_effectiveReadOnly) return;
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

  // P0-#5: Gộp tạo biên bản và ký BQL thành 1 thao tác nguyên tử chống dữ liệu lửng lơ
  Future<void> _saveAndSendToResident() async {
    if (_effectiveReadOnly) return;

    final elecStr = _electricityController.text.trim();
    final waterStr = _waterController.text.trim();
    if (elecStr.isEmpty || waterStr.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Vui lòng nhập đầy đủ chỉ số đồng hồ điện và nước thực tế tại hiện trường.',
      );
      return;
    }

    final depositHeld = parseMoney(_depositController.text).toDouble();
    if (_handoverType == 'move_out' && depositHeld <= 0) {
      AppSnackBar.showWarning(
        context,
        'Vui lòng nhập số tiền cọc hiện đang giữ để chiết tính hoàn trả cư dân.',
      );
      return;
    }

    if (_staffSignatureBytes == null) {
      AppSnackBar.showWarning(
        context,
        'Vui lòng ký tên đại diện Ban Quản Lý trước khi gửi.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(handoverRepositoryProvider);
      final elec = double.tryParse(elecStr) ?? 0.0;
      final water = double.tryParse(waterStr) ?? 0.0;

      // P0-#2: Lấy auth.uid() thực tế và sinh mã biên bản chuẩn HO-YYYYMM-XXXXX
      final currentUserId = SupabaseConfig.isConfigured
          ? SupabaseConfig.client.auth.currentUser?.id
          : null;
      final conductedBy = currentUserId ?? 'staff-manager';

      final dateStr = DateFormat('yyyyMM').format(DateTime.now());
      final randSuffix = (DateTime.now().millisecondsSinceEpoch % 100000)
          .toString()
          .padLeft(5, '0');
      final reportCode = 'HO-$dateStr-$randSuffix';

      final handoverModel = ApartmentHandoverModel(
        id:
            widget.existingHandoverId ??
            'ho_${DateTime.now().millisecondsSinceEpoch}',
        apartmentId: widget.apartmentId,
        buildingId: widget.buildingId,
        handoverType: _handoverType,
        reportCode: reportCode,
        handoverDate: DateTime.now(),
        conductedBy: conductedBy,
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

      // P0-#5: Atomic RPC/Upsert qua repo
      await repo.createHandoverWithStaffSignature(
        handover: handoverModel,
        items: _items,
        signatureBytes: _staffSignatureBytes!,
        notes: _staffNotesController.text,
      );

      ref.invalidate(buildingHandoversProvider(widget.buildingId));

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Đã lưu và gửi biên bản bàn giao cho cư dân xác nhận!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Lỗi lưu biên bản: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final paidColor = AppStatusColors.getPaid(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return RoleGuard(
      permission: AppPermissions.handoverManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Trạm kiểm kê & bàn giao'),
          ),
          elevation: 0.5,
          actions: [
            // P0-#3: Khóa văn bản nếu biên bản đã xác nhận/hoàn tất
            if (_effectiveReadOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: paidColor.withValues(alpha: 0.12),
                      borderRadius: AppRadius.r6,
                      border: Border.all(
                        color: paidColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: paidColor),
                        AppSpacing.w4,
                        Text(
                          'Đã duyệt (Bất biến)',
                          style: context.labelSmall?.copyWith(
                            color: paidColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveAndSendToResident,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Gửi cư dân'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: AppSpacing.p24,
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
                  AppSpacing.h16,
                  _buildMetersCard(),
                  if (_handoverType == 'move_out') ...[
                    AppSpacing.h16,
                    _buildDepositCard(),
                  ],
                  AppSpacing.h16,
                  _buildStaffSignatureCard(),
                ],
              ),
            ),
          ),
          AppSpacing.w24,
          // Cột phải: Danh mục kiểm kê tài sản
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildItemsHeader(),
                  AppSpacing.h12,
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
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildApartmentOverviewCard(),
          AppSpacing.h16,
          _buildMetersCard(),
          if (_handoverType == 'move_out') ...[
            AppSpacing.h16,
            _buildDepositCard(),
          ],
          AppSpacing.h16,
          _buildItemsHeader(),
          AppSpacing.h12,
          _buildItemsList(),
          AppSpacing.h20,
          _buildStaffSignatureCard(),
          AppSpacing.h32,
        ],
      ),
    );
  }

  Widget _buildApartmentOverviewCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: AppSpacing.p8,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r8,
                ),
                child: Icon(
                  Icons.apartment,
                  size: 28,
                  color: colorScheme.primary,
                ),
              ),
              AppSpacing.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Căn hộ ${widget.apartmentCode}',
                      style: context.titleLarge?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _handoverType == 'move_in'
                          ? 'Nhận nhà'
                          : 'Trả nhà',
                      style: context.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          DropdownButtonFormField<String>(
            initialValue: _handoverType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Loại bàn giao',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(
                value: 'move_in',
                child: Text('Nhận nhà'),
              ),
              DropdownMenuItem(
                value: 'move_out',
                child: Text('Trả nhà'),
              ),
            ],
            onChanged: _effectiveReadOnly
                ? null
                : (val) {
                    if (val != null) setState(() => _handoverType = val);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildMetersCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chốt chỉ số đồng hồ bàn giao',
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h12,
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              if (isNarrow) {
                return Column(
                  children: [
                    TextField(
                      controller: _electricityController,
                      readOnly: _effectiveReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Chỉ số điện (kWh) *',
                        hintText: 'Nhập số công tơ điện...',
                        prefixIcon: Icon(Icons.bolt, color: warningColor),
                      ),
                    ),
                    AppSpacing.h12,
                    TextField(
                      controller: _waterController,
                      readOnly: _effectiveReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Chỉ số nước (m³) *',
                        hintText: 'Nhập số đồng hồ nước...',
                        prefixIcon: Icon(
                          Icons.water_drop,
                          color: colorScheme.primary,
                        ),
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
                      readOnly: _effectiveReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Chỉ số điện (kWh) *',
                        hintText: 'Nhập số điện...',
                        prefixIcon: Icon(Icons.bolt, color: warningColor),
                      ),
                    ),
                  ),
                  AppSpacing.w12,
                  Expanded(
                    child: TextField(
                      controller: _waterController,
                      readOnly: _effectiveReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Chỉ số nước (m³) *',
                        hintText: 'Nhập số nước...',
                        prefixIcon: Icon(
                          Icons.water_drop,
                          color: colorScheme.primary,
                        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    final paidColor = AppStatusColors.getPaid(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chiết tính hoàn tiền đặt cọc',
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h12,
          TextField(
            controller: _depositController,
            readOnly: _effectiveReadOnly,
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Tiền đặt cọc đang giữ (VNĐ) *',
              hintText: 'Nhập số tiền cọc...',
              prefixIcon: Icon(Icons.account_balance_wallet),
            ),
          ),
          AppSpacing.h12,
          Container(
            padding: AppSpacing.p12,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: AppRadius.r8,
              border: Border.all(color: colorScheme.outlineVariant),
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
                      style: context.bodyMedium?.tabularFigures().copyWith(
                        color: errorColor,
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
                    Text(
                      'Số tiền cọc hoàn trả cư dân:',
                      style: context.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatCurrency(_depositRefund),
                      style: context.titleMedium?.tabularFigures().copyWith(
                        color: paidColor,
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
        Expanded(
          child: Text(
            'Danh mục kiểm kê hiện trường',
            style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!_effectiveReadOnly)
          TextButton.icon(
            onPressed: _addNewItem,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Thêm món đồ'),
          ),
      ],
    );
  }

  Widget _buildItemsList() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_items.isEmpty) {
      return Container(
        padding: AppSpacing.p24,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: AppRadius.r12,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            'Chưa có hạng mục kiểm kê nào. Bấm "Thêm món đồ" để tạo mới.',
            style: context.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, _) => AppSpacing.h8,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildItemCard(item, index);
      },
    );
  }

  Widget _buildItemCard(HandoverItemModel item, int index) {
    final costCtrl = _itemCostControllers.putIfAbsent(
      item.id,
      () => TextEditingController(
        text: item.repairCost > 0
            ? formatMoney(item.repairCost.toInt(), includeSymbol: false)
            : '',
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.w8,
              Chip(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                label: Text(
                  item.roomAreaDisplayName,
                  style: context.labelSmall,
                ),
              ),
            ],
          ),
          AppSpacing.h8,
          DropdownButtonFormField<String>(
            initialValue: item.condition,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tình trạng tài sản',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(
                value: 'good',
                child: Text('Tốt / Hoạt động bình thường'),
              ),
              DropdownMenuItem(
                value: 'minor_scratch',
                child: Text('Trầy xước nhẹ'),
              ),
              DropdownMenuItem(value: 'damaged', child: Text('Hư hỏng')),
              DropdownMenuItem(value: 'missing', child: Text('Thất lạc')),
            ],
            // P0-#4: Khi đổi sang 'good', tự động xóa chi phí sửa chữa để tránh trừ cọc sai
            onChanged: _effectiveReadOnly
                ? null
                : (val) {
                    if (val != null) {
                      setState(() {
                        final isNowGood = val == 'good';
                        if (isNowGood) {
                          costCtrl.text = '';
                        }
                        _items[index] = item.copyWith(
                          condition: val,
                          repairCost: isNowGood ? 0.0 : item.repairCost,
                        );
                      });
                    }
                  },
          ),
          if (item.hasDamage) ...[
            AppSpacing.h8,
            TextField(
              controller: costCtrl,
              readOnly: _effectiveReadOnly,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Chi phí bồi thường / sửa chữa (VNĐ) *',
                hintText: 'Nhập chi phí...',
                isDense: true,
              ),
              onChanged: (val) {
                final cost = parseMoney(val).toDouble();
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
    final paidColor = AppStatusColors.getPaid(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xác nhận đại diện Ban Quản Lý',
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h12,
          TextField(
            controller: _staffNotesController,
            readOnly: _effectiveReadOnly,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Ghi chú thêm của BQL',
              hintText: 'Nhập ghi chú tổng thể khi bàn giao...',
            ),
          ),
          AppSpacing.h16,
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!_effectiveReadOnly)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _openSignaturePad,
                  icon: const Icon(Icons.draw),
                  label: Text(
                    _staffSignatureBytes != null ? 'Ký lại BQL' : 'Ký tên BQL',
                  ),
                ),
              if (_staffSignatureBytes != null ||
                  (_existingStaffSigUrl != null &&
                      _existingStaffSigUrl!.isNotEmpty))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: paidColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.r6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: paidColor, size: 16),
                      AppSpacing.w4,
                      Flexible(
                        child: Text(
                          'Đã có chữ ký BQL',
                          style: context.labelSmall?.copyWith(
                            color: paidColor,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_existingResidentSigUrl != null &&
                  _existingResidentSigUrl!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: paidColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.r6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: paidColor, size: 16),
                      AppSpacing.w4,
                      Flexible(
                        child: Text(
                          'Cư dân đã ký nhận',
                          style: context.labelSmall?.copyWith(
                            color: paidColor,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên món đồ (VD: Tủ lạnh)',
                  ),
                ),
                AppSpacing.h12,
                DropdownButtonFormField<String>(
                  initialValue: area,
                  isExpanded: true,
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
                    DropdownMenuItem(value: 'kitchen', child: Text('Nhà bếp')),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
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
