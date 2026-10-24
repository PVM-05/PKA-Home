import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/dashboard_providers.dart' show pendingLinkRequestsCountProvider;
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/role_guard.dart';
import 'link_request_management_screen.dart';
import '../widgets/resident_360_detail_sheet.dart';

class ResidentManagementScreen extends ConsumerStatefulWidget {
  const ResidentManagementScreen({super.key});

  @override
  ConsumerState<ResidentManagementScreen> createState() => _ResidentManagementScreenState();
}

class _ResidentManagementScreenState extends ConsumerState<ResidentManagementScreen> {
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
      case 'management':
        return AppTheme.primary;
      case 'accountant':
        return Colors.purple;
      case 'technician':
        return Colors.orange;
      case 'resident':
        return Colors.teal;
      default:
        return AppTheme.textSecondary;
    }
  }

  void _showCreateUserDialog(BuildContext context, List<ApartmentModel> apartments) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'PkaHome@2026');
    String role = 'resident';
    String? apartmentId;
    String relationRole = 'owner';
    bool isSubmitting = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Tạo tài khoản mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email đăng nhập *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                        if (!v.contains('@') || !v.contains('.')) return 'Email không hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu khởi tạo *',
                        prefixIcon: Icon(Icons.lock_outline),
                        helperText: 'Tối thiểu 6 ký tự. Người dùng có thể đổi sau.',
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu ít nhất 6 ký tự' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Vai trò tài khoản',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'resident', child: Text('Cư dân')),
                        DropdownMenuItem(value: 'admin', child: Text('Quản trị viên')),
                        DropdownMenuItem(value: 'accountant', child: Text('Kế toán')),
                        DropdownMenuItem(value: 'technician', child: Text('Kỹ thuật viên')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            role = val;
                            if (role != 'resident') {
                              apartmentId = null;
                            }
                          });
                        }
                      },
                    ),
                    if (role == 'resident') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        initialValue: apartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Căn hộ ban đầu (tùy chọn)',
                          prefixIcon: Icon(Icons.domain),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Không gán căn hộ ngay'),
                          ),
                          ...apartments.map((apt) => DropdownMenuItem<String?>(
                            value: apt.id,
                            child: Text('Căn hộ ${apt.code} (${apt.isEmpty ? 'Trống' : 'Đang ở'})'),
                          )),
                        ],
                        onChanged: (val) => setDialogState(() => apartmentId = val),
                      ),
                      if (apartmentId != null) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: relationRole,
                          decoration: const InputDecoration(
                            labelText: 'Quan hệ với căn hộ',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'owner', child: Text('Chủ hộ')),
                            DropdownMenuItem(value: 'member', child: Text('Thành viên')),
                            DropdownMenuItem(value: 'tenant', child: Text('Người thuê')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => relationRole = val);
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ref.read(managementRepositoryProvider).createUser(
                            email: emailCtrl.text.trim(),
                            password: passCtrl.text,
                            fullName: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                            role: role,
                            apartmentId: apartmentId,
                            relationRole: relationRole,
                          );
                          ref.invalidate(residentsProvider);
                          ref.invalidate(apartmentsProvider);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã tạo tài khoản cho ${nameCtrl.text.trim()} thành công!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(formatErrorMessage(e)),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Tạo tài khoản', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangeRoleDialog(BuildContext context, ResidentModel resident) {
    final currentUserId = ref.read(authProvider).value?.id;
    final isSelf = resident.id == currentUserId;

    String selectedRole = resident.role == 'management' ? 'admin' : resident.role;
    final roles = [
      {'value': 'admin', 'label': 'Quản trị viên', 'desc': 'Toàn quyền quản trị và phân quyền hệ thống'},
      {'value': 'accountant', 'label': 'Kế toán', 'desc': 'Quản lý tài chính, lập hóa đơn & cư dân'},
      {'value': 'technician', 'label': 'Kỹ thuật viên', 'desc': 'Tiếp nhận & xử lý phản ánh sự cố'},
      {'value': 'resident', 'label': 'Cư dân', 'desc': 'Cư dân sinh hoạt tại căn hộ chung cư'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Phân quyền cho ${resident.fullName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelf)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppStatusColors.priorityHigh.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppStatusColors.priorityHigh.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppStatusColors.priorityHigh, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đây là tài khoản của bạn. Không thể tự hạ quyền Quản trị viên để tránh mất quyền quản trị.',
                              style: TextStyle(fontSize: 12, color: AppStatusColors.priorityHigh, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...roles.map((r) {
                    final isSelected = selectedRole == r['value'];
                    final roleColor = _getRoleColor(r['value']!);
                    final isDisabled = isSelf && r['value'] != 'admin';

                    return Opacity(
                      opacity: isDisabled ? 0.45 : 1.0,
                      child: InkWell(
                        onTap: isDisabled
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Không thể tự hạ quyền Quản trị viên của chính mình.'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: AppTheme.error,
                                  ),
                                );
                              }
                            : () {
                                setDialogState(() => selectedRole = r['value']!);
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? roleColor.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? roleColor : Colors.grey.shade300,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: isSelected ? roleColor : AppTheme.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          r['label']!,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? roleColor : AppTheme.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (isDisabled) ...[
                                          const SizedBox(width: 6),
                                          const Text(
                                            '(Bị khóa)',
                                            style: TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      r['desc']!,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () async {
                  if (isSelf && selectedRole != 'admin') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không thể tự hạ quyền Quản trị viên của chính mình.'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                    return;
                  }

                  if (selectedRole != resident.role) {
                    final oldRoleLabel = roles.firstWhere((r) => r['value'] == resident.role, orElse: () => {'label': resident.role})['label'];
                    final newRoleLabel = roles.firstWhere((r) => r['value'] == selectedRole, orElse: () => {'label': selectedRole})['label'];
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (confirmContext) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
                            SizedBox(width: 8),
                            Text('Xác nhận đổi vai trò', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Text(
                          'Bạn có chắc chắn muốn thay đổi vai trò của "${resident.fullName}" từ "$oldRoleLabel" sang "$newRoleLabel"? Thao tác này sẽ cập nhật ngay quyền truy cập và chức năng của tài khoản.',
                          style: const TextStyle(fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmContext, false),
                            child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                            onPressed: () => Navigator.pop(confirmContext, true),
                            child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  try {
                    await ref.read(managementRepositoryProvider).updateUserRole(resident.id, selectedRole);
                    ref.invalidate(residentsProvider);
                    if (resident.id == ref.read(authProvider).value?.id) {
                      ref.invalidate(authProvider);
                    }
                    if (context.mounted) {
                      final selectedLabel = roles.firstWhere((r) => r['value'] == selectedRole)['label'];
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã cập nhật vai trò của ${resident.fullName} thành $selectedLabel!'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(formatErrorMessage(e)),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Lưu thay đổi', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignApartmentDialog(BuildContext context, ResidentModel resident, List<ApartmentModel> apartments) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Gán căn hộ cho ${resident.fullName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: apartments.length,
              itemBuilder: (context, index) {
                final apt = apartments[index];
                return Card(
                  elevation: 0,
                  color: AppTheme.background,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      Icons.domain,
                      color: apt.isEmpty ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    title: Text(
                      'Căn hộ ${apt.code}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      apt.isEmpty ? 'Đang trống' : 'Đã có người ở',
                      style: TextStyle(
                        color: apt.isEmpty ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      try {
                        await ref.read(managementRepositoryProvider).assignResidentToApartment(resident.id, apt.id);
                        ref.invalidate(residentsProvider);
                        ref.invalidate(apartmentsProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gán căn hộ thành công!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(formatErrorMessage(e)),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleFilterChip(String role, String label) {
    final isSelected = _selectedRoleFilter == role;
    final color = _getRoleColor(role == 'all' ? 'admin' : role);
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      selectedColor: color,
      backgroundColor: AppTheme.background,
      onSelected: (selected) {
        setState(() {
          _selectedRoleFilter = selected ? role : 'all';
        });
      },
    );
  }

  Widget _buildStatusFilterChip(String status, String label, Color color) {
    final isSelected = _selectedStatusFilter == status;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      selectedColor: color,
      backgroundColor: AppTheme.background,
      onSelected: (selected) {
        setState(() {
          _selectedStatusFilter = selected ? status : 'all';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final residentsAsync = ref.watch(residentsProvider);
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final isCurrentUserAdmin = ref.watch(authProvider).value?.isAdmin ?? false;
    final pendingLinkReqAsync = ref.watch(pendingLinkRequestsCountProvider);
    final linkCount = pendingLinkReqAsync.value ?? 0;

    return RoleGuard(
      permission: AppPermissions.residentManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Cư dân'),
          actions: [
            if (isCurrentUserAdmin)
              IconButton(
                icon: linkCount > 0
                    ? Badge(
                        label: Text('$linkCount'),
                        child: const Icon(Icons.person_add_outlined),
                      )
                    : const Icon(Icons.person_add_outlined),
                tooltip: 'Duyệt yêu cầu liên kết',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LinkRequestManagementScreen()),
                  );
                  ref.invalidate(residentsProvider);
                  ref.invalidate(pendingLinkRequestsCountProvider);
                },
              ),
          ],
        ),
        floatingActionButton: isCurrentUserAdmin
            ? FloatingActionButton.extended(
                backgroundColor: AppTheme.primary,
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                label: const Text('Thêm người dùng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final apartments = apartmentsAsync.value ?? [];
                  _showCreateUserDialog(context, apartments);
                },
              )
            : null,
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên, email, SĐT hoặc mã căn hộ...',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase().trim();
                  });
                },
              ),
            ),

            // Role Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  _buildRoleFilterChip('all', 'Tất cả vai trò'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('resident', 'Cư dân'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('admin', 'Quản trị viên'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('accountant', 'Kế toán'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('technician', 'Kỹ thuật viên'),
                ],
              ),
            ),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  _buildStatusFilterChip('all', 'Tất cả trạng thái', AppTheme.primary),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('active', 'Đang hoạt động', AppTheme.success),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('locked', 'Đã khóa', AppTheme.error),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('deactivated', 'Đã vô hiệu hóa', Colors.grey.shade700),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Expanded(
              child: AppStateView<List<ResidentModel>>(
                asyncValue: residentsAsync,
                skeletonBuilder: (_) => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: const [
                    ListItemSkeleton(),
                    ListItemSkeleton(),
                    ListItemSkeleton(),
                    ListItemSkeleton(),
                    ListItemSkeleton(),
                  ],
                ),
                emptyMessage: 'Không có người dùng nào',
                emptyIcon: Icons.group_outlined,
                onRetry: () {
                  ref.invalidate(residentsProvider);
                  ref.invalidate(apartmentsProvider);
                },
                dataBuilder: (residents) {
                  final filteredResidents = residents.where((r) {
                    if (_selectedRoleFilter != 'all') {
                      if (_selectedRoleFilter == 'admin') {
                        if (!r.isAdmin) return false;
                      } else if (r.role != _selectedRoleFilter) {
                        return false;
                      }
                    }

                    if (_selectedStatusFilter != 'all') {
                      if (_selectedStatusFilter == 'active') {
                        if (!r.isActive || r.isLocked) return false;
                      } else if (_selectedStatusFilter == 'locked') {
                        if (!r.isLocked) return false;
                      } else if (_selectedStatusFilter == 'deactivated') {
                        if (r.isActive) return false;
                      }
                    }

                    if (_searchQuery.isEmpty) return true;
                    final nameMatch = r.fullName.toLowerCase().contains(_searchQuery);
                    final emailMatch = (r.email ?? '').toLowerCase().contains(_searchQuery);
                    final phoneMatch = (r.phone ?? '').toLowerCase().contains(_searchQuery);
                    final aptCodesMatch = r.apartments.any((a) => a.apartmentCode.toLowerCase().contains(_searchQuery));
                    final legacyAptMatch = r.apartment?.code.toLowerCase().contains(_searchQuery) ?? false;
                    return nameMatch || emailMatch || phoneMatch || aptCodesMatch || legacyAptMatch;
                  }).toList();

                  if (filteredResidents.isEmpty) {
                    return RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: () async {
                        HapticFeedback.lightImpact();
                        ref.invalidate(residentsProvider);
                        ref.invalidate(apartmentsProvider);
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.border.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_search,
                                    size: 48,
                                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Không tìm thấy người dùng nào',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      ref.invalidate(residentsProvider);
                      ref.invalidate(apartmentsProvider);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filteredResidents.length,
                      itemBuilder: (context, index) {
                        final resident = filteredResidents[index];
                        final hasApartments = resident.apartments.isNotEmpty || resident.apartment != null;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => Resident360DetailSheet(resident: resident),
                              );
                              ref.invalidate(residentsProvider);
                              ref.invalidate(apartmentsProvider);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: _getRoleColor(resident.role).withValues(alpha: 0.15),
                                    child: Text(
                                      resident.fullName.isNotEmpty ? resident.fullName[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: _getRoleColor(resident.role),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          resident.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        if (resident.email != null && resident.email!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.email_outlined, size: 13, color: AppTheme.textSecondary),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    resident.email!,
                                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (resident.phone != null && resident.phone!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.phone_outlined, size: 13, color: AppTheme.textSecondary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  resident.phone!,
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              hasApartments ? Icons.domain : Icons.domain_disabled_outlined,
                                              size: 14,
                                              color: hasApartments ? AppTheme.success : AppTheme.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                resident.apartmentSummary,
                                                style: TextStyle(
                                                  color: hasApartments ? AppTheme.success : AppTheme.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            // Role chip
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getRoleColor(resident.role).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: _getRoleColor(resident.role).withValues(alpha: 0.4)),
                                              ),
                                              child: Text(
                                                resident.roleDisplayName,
                                                style: TextStyle(
                                                  color: _getRoleColor(resident.role),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            // Status chip
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: !resident.isActive
                                                    ? Colors.grey.withValues(alpha: 0.15)
                                                    : resident.isLocked
                                                        ? AppTheme.error.withValues(alpha: 0.12)
                                                        : AppTheme.success.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: !resident.isActive
                                                      ? Colors.grey
                                                      : resident.isLocked
                                                          ? AppTheme.error.withValues(alpha: 0.4)
                                                          : AppTheme.success.withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                !resident.isActive
                                                    ? 'Đã vô hiệu hóa'
                                                    : resident.isLocked
                                                        ? 'Đã khóa'
                                                        : 'Hoạt động',
                                                style: TextStyle(
                                                  color: !resident.isActive
                                                      ? Colors.grey.shade700
                                                      : resident.isLocked
                                                          ? AppTheme.error
                                                          : AppTheme.success,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action Buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCurrentUserAdmin)
                                        IconButton(
                                          tooltip: 'Phân quyền vai trò',
                                          icon: const Icon(Icons.manage_accounts_outlined, color: AppTheme.secondary),
                                          onPressed: () => _showChangeRoleDialog(context, resident),
                                        ),
                                      IconButton(
                                        tooltip: 'Gán căn hộ',
                                        icon: const Icon(Icons.add_home_work_outlined, color: AppTheme.primary),
                                        onPressed: () {
                                          apartmentsAsync.whenData((apartments) {
                                            _showAssignApartmentDialog(context, resident, apartments);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}
