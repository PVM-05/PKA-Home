import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/co_residents_provider.dart';
import '../../../core/supabase_config.dart';
import '../../auth/screens/change_password_screen.dart';
import 'link_request_screen.dart';

final residentApartmentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return [];

  final response = await SupabaseConfig.client
      .from('residents_apartments')
      .select('relation_role, apartment_id, apartments(id, code, area)')
      .eq('user_id', user.id);

  return List<Map<String, dynamic>>.from(response);
});

class ResidentProfileScreen extends ConsumerWidget {
  const ResidentProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, UserModel user) {
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chỉnh sửa thông tin cá nhân'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone_outlined),
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
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                try {
                  final updatedUser = await ref.read(userRepositoryProvider).updateProfile(
                        userId: user.id,
                        fullName: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                      );
                  ref.read(authProvider.notifier).updateUser(updatedUser);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cập nhật thông tin thành công!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi cập nhật: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);
    final apartmentsAsync = ref.watch(residentApartmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản của tôi'),
        automaticallyImplyLeading: false,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Chưa đăng nhập'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_outline, size: 48, color: AppTheme.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      user.phone != null && user.phone!.isNotEmpty
                          ? user.phone!
                          : 'Chưa cập nhật SĐT',
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showEditProfileDialog(context, ref, user),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Chỉnh sửa thông tin'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(height: 28),

                // Căn hộ của bạn
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Căn hộ của bạn',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LinkRequestScreen()),
                        );
                        if (result == true) {
                          ref.invalidate(residentApartmentsProvider);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Xin liên kết'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                apartmentsAsync.when(
                  data: (apartments) {
                    if (apartments.isEmpty) {
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(Icons.apartment_outlined, size: 48, color: AppTheme.textSecondary),
                              const SizedBox(height: 16),
                              const Text(
                                'Bạn chưa được liên kết với căn hộ nào.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  final result = await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const LinkRequestScreen()),
                                  );
                                  if (result == true) {
                                    ref.invalidate(residentApartmentsProvider);
                                  }
                                },
                                child: const Text('Xin liên kết ngay'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: apartments.map((apt) {
                        return _ApartmentCardWithCoResidents(aptData: apt);
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Lỗi tải thông tin căn hộ: $e'),
                ),

                const SizedBox(height: 28),

                // Settings Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cài đặt & Bảo mật',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: AppTheme.primary),
                        title: const Text('Đổi mật khẩu'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout_outlined, color: AppTheme.error),
                        title: const Text(
                          'Đăng xuất',
                          style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Xác nhận đăng xuất'),
                              content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Hủy'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ref.read(authProvider.notifier).logout();
                                  },
                                  child: const Text('Đăng xuất'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(formatErrorMessage(e), style: const TextStyle(color: AppTheme.error))),
      ),
    );
  }
}

class _ApartmentCardWithCoResidents extends ConsumerWidget {
  final Map<String, dynamic> aptData;

  const _ApartmentCardWithCoResidents({required this.aptData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartment = aptData['apartments'];
    final apartmentId = aptData['apartment_id'] as String? ?? apartment?['id'] as String? ?? '';
    final role = aptData['relation_role'] == 'owner' ? 'Chủ hộ' : 'Người thuê';
    final coResidentsAsync = ref.watch(coResidentsProvider(apartmentId));

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.apartment_outlined, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Căn hộ ${apartment?['code'] ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Diện tích: ${apartment?['area'] ?? 'N/A'} m²',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: const [
                Icon(Icons.people_outline, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 6),
                Text(
                  'Thành viên cùng căn hộ:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            coResidentsAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Chưa có thành viên khác.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  );
                }

                return Column(
                  children: members.map((m) {
                    final userData = m['users'] as Map<String, dynamic>?;
                    final memberName = userData?['full_name'] ?? 'Cư dân';
                    final memberPhone = userData?['phone'] ?? '';
                    final memberRole = m['relation_role'] == 'owner' ? 'Chủ hộ' : 'Người thuê';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              memberName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (memberPhone.isNotEmpty) ...[
                            Text(
                              memberPhone,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              memberRole,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => const Text(
                'Không thể tải danh sách thành viên',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
