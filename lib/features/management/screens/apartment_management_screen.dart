import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/apartment_model.dart';


class ApartmentManagementScreen extends ConsumerWidget {
  const ApartmentManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartmentsAsync = ref.watch(apartmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Căn hộ'),
      ),
      body: apartmentsAsync.when(
        data: (apartments) {
          if (apartments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apartment_outlined,
                    size: 64,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có dữ liệu căn hộ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(apartmentsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: apartments.length,
              itemBuilder: (context, index) {
                final apt = apartments[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: apt.isEmpty ? AppTheme.success.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.2),
                      child: Icon(
                        apt.isEmpty ? Icons.apartment_outlined : Icons.home,
                        color: apt.isEmpty ? AppTheme.success : AppTheme.primary,
                      ),
                    ),
                    title: Text(
                      'Căn hộ ${apt.code}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Diện tích: ${apt.area ?? 0} m²\nTrạng thái: ${apt.isEmpty ? 'Trống' : 'Đã có chủ'}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                          onPressed: () => _showApartmentDialog(context, ref, apartment: apt),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                          onPressed: () => _deleteApartment(context, ref, apt),
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
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showApartmentDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showApartmentDialog(BuildContext context, WidgetRef ref, {ApartmentModel? apartment}) {
    final isEditing = apartment != null;
    final codeController = TextEditingController(text: apartment?.code ?? '');
    final areaController = TextEditingController(text: apartment?.area?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Cập nhật Căn hộ' : 'Thêm Căn hộ mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Mã căn hộ (VD: A101)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Diện tích (m²)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                final area = double.tryParse(areaController.text.trim());
                
                if (code.isEmpty || area == null) {
                  return;
                }

                final repo = ref.read(managementRepositoryProvider);
                try {
                  if (isEditing) {
                    await repo.updateApartment(apartment.id, code, area);
                  } else {
                    await repo.createApartment(code, area);
                  }
                  ref.invalidate(apartmentsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _deleteApartment(BuildContext context, WidgetRef ref, ApartmentModel apt) {
    if (!apt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa căn hộ đã có chủ!'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa Căn hộ'),
        content: Text('Bạn có chắc chắn muốn xóa căn hộ ${apt.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              try {
                await ref.read(managementRepositoryProvider).deleteApartment(apt.id);
                ref.invalidate(apartmentsProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
