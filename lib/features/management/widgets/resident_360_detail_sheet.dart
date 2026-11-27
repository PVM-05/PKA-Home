import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../core/utils/error_formatter.dart';
import 'apartment_contract_sheet.dart';

class Resident360DetailSheet extends ConsumerStatefulWidget {
  final ResidentModel resident;

  const Resident360DetailSheet({
    super.key,
    required this.resident,
  });

  @override
  ConsumerState<Resident360DetailSheet> createState() => _Resident360DetailSheetState();
}

class _Resident360DetailSheetState extends ConsumerState<Resident360DetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ResidentModel _resident;
  bool _isActionLoading = false;
  String? _selectedApartmentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _resident = widget.resident;
    if (_resident.apartments.isNotEmpty) {
      _selectedApartmentId = _resident.apartments.first.apartmentId;
    } else {
      _selectedApartmentId = _resident.apartment?.id;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  ResidentApartmentLink? get _selectedApartmentLink {
    if (_resident.apartments.isEmpty) return null;
    return _resident.apartments.firstWhere(
      (a) => a.apartmentId == _selectedApartmentId,
      orElse: () => _resident.apartments.first,
    );
  }

  Future<void> _toggleLock() async {
    setState(() => _isActionLoading = true);
    final newLockedState = !_resident.isLocked;
    try {
      await ref.read(managementRepositoryProvider).toggleUserStatus(
        userId: _resident.id,
        action: newLockedState ? 'lock' : 'unlock',
      );
      ref.invalidate(residentsProvider);
      setState(() {
        _resident = _resident.copyWith(isLocked: newLockedState);
        _isActionLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newLockedState ? 'Đã khóa tài khoản thành công.' : 'Đã mở khóa tài khoản.'),
            backgroundColor: newLockedState ? AppTheme.error : AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleActiveStatus() async {
    final willDeactivate = _resident.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              willDeactivate ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined,
              color: willDeactivate ? AppTheme.error : AppTheme.success,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(willDeactivate ? 'Vô hiệu hóa tài khoản' : 'Kích hoạt lại tài khoản')),
          ],
        ),
        content: Text(
          willDeactivate
              ? 'Tài khoản của "${_resident.fullName}" sẽ bị vô hiệu hóa quyền đăng nhập, nhưng toàn bộ lịch sử hóa đơn và giao dịch vẫn được bảo toàn nguyên vẹn trong hệ thống. Bạn có chắc chắn?'
              : 'Kích hoạt lại tài khoản sẽ cho phép "${_resident.fullName}" đăng nhập và sử dụng ứng dụng trở lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate ? AppTheme.error : AppTheme.success,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willDeactivate ? 'Vô hiệu hóa' : 'Kích hoạt', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await ref.read(managementRepositoryProvider).toggleUserStatus(
        userId: _resident.id,
        action: willDeactivate ? 'deactivate' : 'activate',
      );
      ref.invalidate(residentsProvider);
      setState(() {
        _resident = _resident.copyWith(
          isActive: !willDeactivate,
          isLocked: willDeactivate ? true : _resident.isLocked,
        );
        _isActionLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(willDeactivate ? 'Đã vô hiệu hóa tài khoản.' : 'Đã kích hoạt lại tài khoản thành công.'),
            backgroundColor: willDeactivate ? AppTheme.error : AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _resident.email;
    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản này chưa có email để gửi liên kết đặt lại mật khẩu.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppTheme.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Gửi email đặt lại mật khẩu')),
          ],
        ),
        content: Text('Hệ thống sẽ gửi email chứa liên kết thiết lập mật khẩu mới đến địa chỉ: $email. Tiếp tục?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi email', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await ref.read(managementRepositoryProvider).sendAdminPasswordReset(email);
      setState(() => _isActionLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi email đặt lại mật khẩu đến $email thành công!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _resident.fullName);
    final phoneCtrl = TextEditingController(text: _resident.phone ?? '');
    String selectedRole = _resident.role;

    final roles = [
      {'value': 'admin', 'label': 'Quản trị viên'},
      {'value': 'management', 'label': 'Ban quản lý'},
      {'value': 'accountant', 'label': 'Kế toán'},
      {'value': 'technician', 'label': 'Kỹ thuật viên'},
      {'value': 'staff', 'label': 'Nhân viên vận hành'},
      {'value': 'resident', 'label': 'Cư dân'},
    ];
    if (!roles.any((r) => r['value'] == selectedRole)) {
      selectedRole = 'resident';
    }

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dialogContext, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Chỉnh sửa hồ sơ người dùng', style: dialogContext.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vai trò hệ thống',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  items: roles
                      .map((r) => DropdownMenuItem(
                            value: r['value'],
                            child: Text(r['label']!, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlg(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Họ và tên không được để trống')),
                  );
                  return;
                }
                Navigator.pop(dlgCtx);
                setState(() => _isActionLoading = true);
                try {
                  await ref.read(managementRepositoryProvider).updateUserProfile(
                    userId: _resident.id,
                    fullName: newName,
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    role: selectedRole,
                  );
                  ref.invalidate(residentsProvider);
                  if (!mounted) return;
                  setState(() {
                    _resident = _resident.copyWith(
                      fullName: newName,
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      role: selectedRole,
                    );
                    _isActionLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cập nhật hồ sơ thành công!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isActionLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
                  );
                }
              },
              child: const Text('Lưu thay đổi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlinkApartment(String aptId, String aptCode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận gỡ căn hộ'),
        content: Text('Bạn có chắc muốn gỡ liên kết căn hộ $aptCode khỏi hồ sơ của ${_resident.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ liên kết', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      await ref.read(managementRepositoryProvider).unlinkApartment(
        userId: _resident.id,
        apartmentId: aptId,
      );
      ref.invalidate(residentsProvider);
      ref.invalidate(apartmentsProvider);
      final updatedApts = _resident.apartments.where((a) => a.apartmentId != aptId).toList();
      setState(() {
        _resident = _resident.copyWith(apartments: updatedApts);
        _selectedApartmentId = updatedApts.isNotEmpty ? updatedApts.first.apartmentId : null;
        _isActionLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gỡ liên kết căn hộ $aptCode thành công!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeAptLink = _selectedApartmentLink;
    final aptId = activeAptLink?.apartmentId ?? _resident.apartment?.id;
    final aptCode = activeAptLink?.apartmentCode ?? _resident.apartment?.code;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Profile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        _resident.fullName.isNotEmpty ? _resident.fullName[0].toUpperCase() : '?',
                        style: context.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _resident.fullName,
                                  style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                icon: Icon(Icons.edit_outlined, size: 20, color: colorScheme.primary),
                                tooltip: 'Chỉnh sửa hồ sơ',
                                onPressed: _isActionLoading ? null : _showEditProfileDialog,
                              ),
                            ],
                          ),
                          Text(
                            'Căn hộ: ${aptCode ?? "Chưa gán"} • ${_resident.roleDisplayName}',
                            style: context.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Email: ${_resident.email ?? "Chưa có"} • SĐT: ${_resident.phone ?? "Chưa có"}',
                            style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _resident.roleDisplayName,
                                  style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.primary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (_resident.isActive && !_resident.isLocked)
                                      ? AppTheme.getSemanticSuccess(context).withValues(alpha: 0.12)
                                      : colorScheme.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _resident.statusDisplayName,
                                  style: context.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: (_resident.isActive && !_resident.isLocked)
                                        ? AppTheme.getSemanticSuccess(context)
                                        : colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons Row (Khóa / Mở, Vô hiệu hóa, Reset Pass)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isActionLoading ? null : _toggleLock,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _resident.isLocked
                            ? AppTheme.getSemanticSuccess(context)
                            : AppTheme.getSemanticWarning(context),
                        side: BorderSide(
                          color: _resident.isLocked
                              ? AppTheme.getSemanticSuccess(context)
                              : AppTheme.getSemanticWarning(context),
                        ),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: Icon(_resident.isLocked ? Icons.lock_open : Icons.lock_outline, size: 16),
                      label: Text(_resident.isLocked ? 'Mở khóa' : 'Khóa tài khoản', style: context.bodySmall),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isActionLoading ? null : _toggleActiveStatus,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _resident.isActive
                            ? colorScheme.error
                            : AppTheme.getSemanticSuccess(context),
                        side: BorderSide(
                          color: _resident.isActive
                              ? colorScheme.error
                              : AppTheme.getSemanticSuccess(context),
                        ),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: Icon(_resident.isActive ? Icons.person_off_outlined : Icons.person_outline, size: 16),
                      label: Text(_resident.isActive ? 'Vô hiệu hóa' : 'Kích hoạt', style: context.bodySmall),
                    ),
                    if (_resident.email != null)
                      OutlinedButton.icon(
                        onPressed: _isActionLoading ? null : _sendPasswordReset,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.primary),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.lock_reset, size: 16),
                        label: Text('Gửi liên kết đổi mật khẩu', style: context.bodySmall),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Danh sách các căn hộ liên kết (Hỗ trợ Đa căn hộ)
          if (_resident.apartments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.apartment, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('Căn hộ liên kết:', style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _resident.apartments.map((a) {
                          final isSelected = a.apartmentId == _selectedApartmentId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text('${a.apartmentCode} (${a.relationRoleDisplayName})'),
                              labelStyle: context.labelSmall?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : colorScheme.onSurface,
                              ),
                              backgroundColor: colorScheme.surfaceContainerLow,
                              selectedColor: AppTheme.primary,
                              onSelected: (_) {
                                setState(() => _selectedApartmentId = a.apartmentId);
                              },
                              avatar: isSelected
                                  ? null
                                  : InkWell(
                                      onTap: () => _unlinkApartment(a.apartmentId, a.apartmentCode),
                                      child: Icon(Icons.close, size: 14, color: colorScheme.onSurfaceVariant),
                                    ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (aptId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => ApartmentContractSheet(
                            apartmentId: aptId,
                            apartmentCode: aptCode ?? 'Căn hộ',
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment_outlined, size: 16),
                      label: Text('Xem hợp đồng & lưu trú', style: context.bodySmall),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
          ],

          // Tabs: Phương tiện | Hóa đơn | Dịch vụ
          TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.two_wheeler_outlined), text: 'Phương tiện'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Hóa đơn'),
              Tab(icon: Icon(Icons.pool_outlined), text: 'Dịch vụ'),
            ],
          ),

          SizedBox(
            height: 250,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVehiclesTab(aptId, aptCode),
                _buildInvoicesTab(aptId, aptCode),
                _buildServicesTab(_resident.id, aptCode),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab(String? apartmentId, String? aptCode) {
    final vehiclesAsync = ref.watch(managementApartmentVehiclesProvider(apartmentId));
    return vehiclesAsync.when(
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return Center(
            child: Text(
              'Căn hộ ${aptCode ?? ""} chưa có phương tiện đăng ký.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final v = vehicles[index];
            final type = v['vehicle_type'] ?? 'Xe';
            final plate = v['license_plate'] ?? '';
            final status = v['status'] ?? 'pending';

            Color statusColor;
            String statusLabel;
            if (status == 'approved') {
              statusColor = AppTheme.success;
              statusLabel = 'Đã duyệt';
            } else if (status == 'rejected') {
              statusColor = AppTheme.error;
              statusLabel = 'Từ chối';
            } else {
              statusColor = AppTheme.warning;
              statusLabel = 'Chờ duyệt';
            }

            return AppCard(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(type == 'car' ? Icons.directions_car : Icons.two_wheeler, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$plate', style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Loại: $type • Căn hộ: ${aptCode ?? "Chưa gán"}', style: context.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: context.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Lỗi tải danh sách xe', style: TextStyle(color: AppTheme.error))),
    );
  }

  Widget _buildInvoicesTab(String? apartmentId, String? aptCode) {
    final invoicesAsync = ref.watch(residentInvoicesProvider(apartmentId));
    return invoicesAsync.when(
      data: (invoices) {
        if (invoices.isEmpty) {
          return Center(
            child: Text(
              'Căn hộ ${aptCode ?? ""} chưa có hóa đơn.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final inv = invoices[index];
            final period = inv.period;
            final amount = inv.totalAmount;
            final status = inv.status;

            Color statusColor;
            String statusLabel;
            if (status == 'paid') {
              statusColor = AppTheme.success;
              statusLabel = 'Đã thanh toán';
            } else if (status == 'pending_confirmation') {
              statusColor = AppStatusColors.pendingConfirmation;
              statusLabel = 'Chờ xác nhận';
            } else {
              statusColor = AppTheme.error;
              statusLabel = 'Chưa thanh toán';
            }

            return AppCard(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kỳ: $period', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${amount.toStringAsFixed(0)} đ',
                          style: context.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: context.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Lỗi tải hóa đơn', style: TextStyle(color: AppTheme.error))),
    );
  }

  Widget _buildServicesTab(String residentId, String? aptCode) {
    final bookingsAsync = ref.watch(residentBookingsProvider(residentId));
    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return Center(
            child: Text(
              'Chưa có lịch đặt tiện ích.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final b = bookings[index];
            final amenityName = (b['building_amenities'] as Map?)?['name'] ??
                (b['amenities'] as Map?)?['name'] ??
                'Tiện ích';
            final date = b['booking_date'] ?? '';
            final slot = b['time_slot'] ?? '';
            final status = b['status'] as String? ?? 'confirmed';
            final isConfirmed = status == 'confirmed';
            final isWaitlist = status == 'waitlist';
            final isPending = status == 'pending_payment';
            final isCompleted = status == 'completed';

            Color statusColor;
            String statusLabel;
            if (isConfirmed) {
              statusColor = AppTheme.primary;
              statusLabel = 'Đã đặt';
            } else if (isPending) {
              statusColor = AppStatusColors.pendingConfirmation;
              statusLabel = 'Chờ nộp phí';
            } else if (isWaitlist) {
              statusColor = AppTheme.warning;
              statusLabel = 'Chờ slot';
            } else if (isCompleted) {
              statusColor = AppTheme.success;
              statusLabel = 'Đã sử dụng';
            } else {
              statusColor = AppTheme.error;
              statusLabel = 'Đã hủy';
            }

            return AppCard(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$amenityName', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Lịch: $slot ngày $date • Căn hộ ${aptCode ?? "Chưa gán"}', style: context.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: context.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Lỗi tải lịch tiện ích', style: TextStyle(color: AppTheme.error))),
    );
  }
}
