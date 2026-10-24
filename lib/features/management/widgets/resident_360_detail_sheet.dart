import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../core/utils/error_formatter.dart';

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
            Text(willDeactivate ? 'Vô hiệu hóa tài khoản' : 'Kích hoạt lại tài khoản'),
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
            Text('Gửi email đặt lại mật khẩu'),
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
      {'value': 'accountant', 'label': 'Kế toán'},
      {'value': 'technician', 'label': 'Kỹ thuật viên'},
      {'value': 'resident', 'label': 'Cư dân'},
    ];

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dialogContext, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Chỉnh sửa hồ sơ người dùng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  decoration: const InputDecoration(
                    labelText: 'Vai trò hệ thống',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  items: roles
                      .map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!)))
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
    final activeAptLink = _selectedApartmentLink;
    final aptId = activeAptLink?.apartmentId ?? _resident.apartment?.id;
    final aptCode = activeAptLink?.apartmentCode ?? _resident.apartment?.code;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
                color: Colors.grey.shade300,
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
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        _resident.fullName.isNotEmpty ? _resident.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
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
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                                tooltip: 'Chỉnh sửa hồ sơ',
                                onPressed: _isActionLoading ? null : _showEditProfileDialog,
                              ),
                            ],
                          ),
                          Text(
                            'Căn hộ: ${aptCode ?? "Chưa gán"} • ${_resident.roleDisplayName}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Email: ${_resident.email ?? "Chưa có"} • SĐT: ${_resident.phone ?? "Chưa có"}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _resident.roleDisplayName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (_resident.isActive && !_resident.isLocked)
                                      ? AppTheme.success.withValues(alpha: 0.1)
                                      : AppTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _resident.statusDisplayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (_resident.isActive && !_resident.isLocked) ? AppTheme.success : AppTheme.error,
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
                        foregroundColor: _resident.isLocked ? AppTheme.success : Colors.orange.shade800,
                        side: BorderSide(color: _resident.isLocked ? AppTheme.success : Colors.orange.shade800),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: Icon(_resident.isLocked ? Icons.lock_open : Icons.lock_outline, size: 16),
                      label: Text(_resident.isLocked ? 'Mở khóa' : 'Khóa tài khoản', style: const TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isActionLoading ? null : _toggleActiveStatus,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _resident.isActive ? AppTheme.error : AppTheme.success,
                        side: BorderSide(color: _resident.isActive ? AppTheme.error : AppTheme.success),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: Icon(_resident.isActive ? Icons.person_off_outlined : Icons.person_outline, size: 16),
                      label: Text(_resident.isActive ? 'Vô hiệu hóa' : 'Kích hoạt', style: const TextStyle(fontSize: 12)),
                    ),
                    if (_resident.email != null)
                      OutlinedButton.icon(
                        onPressed: _isActionLoading ? null : _sendPasswordReset,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.lock_reset, size: 16),
                        label: const Text('Gửi link đổi mật khẩu', style: TextStyle(fontSize: 12)),
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
                  const Icon(Icons.apartment, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  const Text('Căn hộ liên kết:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                              backgroundColor: Colors.grey.shade100,
                              selectedColor: AppTheme.primary,
                              onSelected: (_) {
                                setState(() => _selectedApartmentId = a.apartmentId);
                              },
                              avatar: isSelected
                                  ? null
                                  : InkWell(
                                      onTap: () => _unlinkApartment(a.apartmentId, a.apartmentCode),
                                      child: const Icon(Icons.close, size: 14, color: Colors.grey),
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
            const Divider(height: 1),
          ],

          // Tabs: Phương tiện | Hóa đơn | Dịch vụ
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
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
            child: Text('Căn hộ ${aptCode ?? ""} chưa có phương tiện đăng ký.', style: const TextStyle(color: AppTheme.textSecondary)),
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
                        Text('$plate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Loại: $type • Căn hộ: ${aptCode ?? "N/A"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
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
            child: Text('Căn hộ ${aptCode ?? ""} chưa có hóa đơn.', style: const TextStyle(color: AppTheme.textSecondary)),
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
                        Text('${amount.toStringAsFixed(0)} đ', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
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
          return const Center(
            child: Text('Chưa có lịch đặt tiện ích.', style: TextStyle(color: AppTheme.textSecondary)),
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
                        Text('Lịch: $slot ngày $date • Căn hộ ${aptCode ?? "N/A"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
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
