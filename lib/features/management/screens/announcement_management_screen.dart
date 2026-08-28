import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/announcement_provider.dart';
import '../../../data/repositories/announcement_repository.dart';

class AnnouncementManagementScreen extends ConsumerWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Thông báo'),
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return const Center(child: Text('Chưa có thông báo nào.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    announcement.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: announcement.isUrgent ? AppTheme.error : null,
                    ),
                  ),
                  subtitle: Text(
                    announcement.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(FluentIcons.delete_24_regular, color: AppTheme.error),
                    onPressed: () async {
                      final repo = ref.read(announcementRepositoryProvider);
                      await repo.deleteAnnouncement(announcement.id);
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Lỗi: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(FluentIcons.add_24_regular),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    bool isUrgent = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Tạo thông báo mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(labelText: 'Nội dung'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Đánh dấu Khẩn cấp'),
                      value: isUrgent,
                      onChanged: (val) {
                        setState(() {
                          isUrgent = val ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty || contentController.text.isEmpty) return;
                    
                    final repo = ref.read(announcementRepositoryProvider);
                    await repo.createAnnouncement(
                      title: titleController.text,
                      content: contentController.text,
                      isUrgent: isUrgent,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Đăng'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
