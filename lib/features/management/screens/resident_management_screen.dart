import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/apartment_model.dart';

class ResidentManagementScreen extends ConsumerStatefulWidget {
  const ResidentManagementScreen({super.key});

  @override
  ConsumerState<ResidentManagementScreen> createState() => _ResidentManagementScreenState();
}

class _ResidentManagementScreenState extends ConsumerState<ResidentManagementScreen> {
  String _searchQuery = '';

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
                      FluentIcons.building_24_regular,
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
                            content: Text('Lỗi: $e'),
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

  @override
  Widget build(BuildContext context) {
    final residentsAsync = ref.watch(residentsProvider);
    final apartmentsAsync = ref.watch(apartmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Cư dân'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên...',
                prefixIcon: const Icon(FluentIcons.search_24_regular, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
          
          Expanded(
            child: residentsAsync.when(
              data: (residents) {
                final filteredResidents = residents.where((r) {
                  return r.fullName.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredResidents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(FluentIcons.people_search_24_regular, size: 64, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'Không tìm thấy cư dân nào',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(residentsProvider);
                    ref.invalidate(apartmentsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredResidents.length,
                    itemBuilder: (context, index) {
                      final resident = filteredResidents[index];
                      final hasApartment = resident.apartment != null;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                child: Text(
                                  resident.fullName.isNotEmpty ? resident.fullName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              
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
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          hasApartment ? FluentIcons.building_24_regular : FluentIcons.building_24_regular,
                                          size: 16,
                                          color: hasApartment ? AppTheme.success : AppTheme.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasApartment ? 'Căn hộ: ${resident.apartment!.code}' : 'Chưa gán căn hộ',
                                          style: TextStyle(
                                            color: hasApartment ? AppTheme.success : AppTheme.error,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Action Button
                              Row(
                                children: [
                                  if (hasApartment)
                                    IconButton(
                                      tooltip: 'Gỡ khỏi căn hộ',
                                      icon: const Icon(FluentIcons.dismiss_circle_24_regular, color: AppTheme.error),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Gỡ căn hộ'),
                                            content: Text('Bạn có chắc chắn muốn gỡ cư dân ${resident.fullName} khỏi căn hộ ${resident.apartment!.code}?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Hủy'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                                                onPressed: () async {
                                                  try {
                                                    await ref.read(managementRepositoryProvider).unlinkResidentFromApartment(resident.id, resident.apartment!.id);
                                                    ref.invalidate(residentsProvider);
                                                    ref.invalidate(apartmentsProvider);
                                                    if (context.mounted) {
                                                      Navigator.pop(context);
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gỡ cư dân khỏi căn hộ'), backgroundColor: AppTheme.success));
                                                    }
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error));
                                                    }
                                                  }
                                                },
                                                child: const Text('Xác nhận'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  IconButton(
                                    tooltip: hasApartment ? 'Đổi căn hộ' : 'Gán căn hộ',
                                    icon: Icon(
                                      hasApartment ? FluentIcons.edit_24_regular : FluentIcons.add_circle_24_regular,
                                      color: AppTheme.primary,
                                    ),
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
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Lỗi: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
