import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../core/supabase_config.dart';
import '../../auth/screens/change_password_screen.dart';

import 'link_request_screen.dart';

final residentApartmentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return [];

  final response = await SupabaseConfig.client
      .from('residents_apartments')
      .select('relation_role, apartments(code, area)')
      .eq('user_id', user.id);
  
  return List<Map<String, dynamic>>.from(response);
});

class ResidentProfileScreen extends ConsumerWidget {
  const ResidentProfileScreen({super.key});

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
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(FluentIcons.person_48_regular, size: 50, color: AppTheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cư dân',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 32),
                
                // Apartments Section
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
                      icon: const Icon(FluentIcons.add_16_regular),
                      label: const Text('Xin liên kết'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                apartmentsAsync.when(
                  data: (apartments) {
                    if (apartments.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(FluentIcons.building_home_24_regular, size: 48, color: AppTheme.textSecondary),
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
                        final apartment = apt['apartments'];
                        final role = apt['relation_role'] == 'owner' ? 'Chủ hộ' : 'Người thuê';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(FluentIcons.building_home_24_regular, color: AppTheme.primary),
                            title: Text('Căn hộ ${apartment['code']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Diện tích: ${apartment['area']} m²\nVai trò: $role'),
                            isThreeLine: true,
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Lỗi tải thông tin căn hộ: $e'),
                ),
                
                const SizedBox(height: 32),
                
                // Settings Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cài đặt',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(FluentIcons.key_24_regular),
                        title: const Text('Đổi mật khẩu'),
                        trailing: const Icon(FluentIcons.chevron_right_24_regular),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(FluentIcons.sign_out_24_regular, color: AppTheme.error),
                        title: const Text('Đăng xuất', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                        onTap: () {
                          ref.read(authProvider.notifier).logout();
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
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }
}
