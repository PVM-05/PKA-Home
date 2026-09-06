import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/handbook_provider.dart';
import '../../../data/models/emergency_contact_model.dart';
import '../../../data/models/building_rule_model.dart';
import '../../../data/models/building_amenity_model.dart';

class HandbookManagementScreen extends ConsumerStatefulWidget {
  const HandbookManagementScreen({super.key});

  @override
  ConsumerState<HandbookManagementScreen> createState() => _HandbookManagementScreenState();
}

class _HandbookManagementScreenState extends ConsumerState<HandbookManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Cẩm Nang Tòa Nhà'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.emergency_outlined), text: 'Đường dây nóng'),
            Tab(icon: Icon(Icons.gavel_outlined), text: 'Nội quy'),
            Tab(icon: Icon(Icons.pool_outlined), text: 'Tiện ích'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmergencyContactsTab(),
          _buildBuildingRulesTab(),
          _buildBuildingAmenitiesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          final currentTab = _tabController.index;
          if (currentTab == 0) {
            _showContactDialog();
          } else if (currentTab == 1) {
            _showRuleDialog();
          } else {
            _showAmenityDialog();
          }
        },
        tooltip: 'Thêm mới',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Đường Dây Nóng
  // ===========================================================================
  Widget _buildEmergencyContactsTab() {
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(emergencyContactsProvider),
      child: contactsAsync.when(
        data: (contacts) {
          if (contacts.isEmpty) {
            return const Center(child: Text('Chưa có thông tin đường dây nóng. Bấm + để thêm mới.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone_in_talk, color: AppTheme.primary),
                  ),
                  title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('SĐT: ${contact.phone} • Loại: ${contact.contactType} • Thứ tự: ${contact.displayOrder}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                        onPressed: () => _showContactDialog(contact: contact),
                        tooltip: 'Chỉnh sửa',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                        onPressed: () => _confirmDelete(
                          title: 'Xóa đường dây nóng',
                          message: 'Bạn có chắc chắn muốn xóa "${contact.name}" không?',
                          onConfirm: () async {
                            await ref.read(handbookRepositoryProvider).deleteEmergencyContact(contact.id);
                            ref.invalidate(emergencyContactsProvider);
                          },
                        ),
                        tooltip: 'Xóa',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
      ),
    );
  }

  void _showContactDialog({EmergencyContactModel? contact}) {
    final isEditing = contact != null;
    final nameController = TextEditingController(text: contact?.name ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final orderController = TextEditingController(text: (contact?.displayOrder ?? 0).toString());
    String contactType = contact?.contactType ?? 'security';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'Chỉnh sửa đường dây nóng' : 'Thêm đường dây nóng'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tên đầu mối liên hệ *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Số điện thoại *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập số điện thoại' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: contactType,
                    decoration: const InputDecoration(labelText: 'Phân loại'),
                    items: const [
                      DropdownMenuItem(value: 'security', child: Text('An ninh / Bảo vệ')),
                      DropdownMenuItem(value: 'fire', child: Text('PCCC / Cứu hộ')),
                      DropdownMenuItem(value: 'management', child: Text('Ban Quản Lý')),
                      DropdownMenuItem(value: 'technical', child: Text('Đội Kỹ Thuật')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => contactType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Thứ tự hiển thị (tùy chọn)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx);
                  final order = int.tryParse(orderController.text.trim()) ?? 0;
                  final repo = ref.read(handbookRepositoryProvider);

                  if (isEditing) {
                    await repo.updateEmergencyContact(
                      id: contact.id,
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      contactType: contactType,
                      displayOrder: order,
                    );
                  } else {
                    await repo.createEmergencyContact(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      contactType: contactType,
                      displayOrder: order,
                    );
                  }
                  ref.invalidate(emergencyContactsProvider);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Tab 2: Nội Quy Tòa Nhà
  // ===========================================================================
  Widget _buildBuildingRulesTab() {
    final rulesAsync = ref.watch(buildingRulesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildingRulesProvider),
      child: rulesAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('Chưa có nội quy. Bấm + để thêm mới.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
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
                          Expanded(
                            child: Text(
                              '${index + 1}. ${rule.title}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                            onPressed: () => _showRuleDialog(rule: rule),
                            tooltip: 'Chỉnh sửa',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                            onPressed: () => _confirmDelete(
                              title: 'Xóa nội quy',
                              message: 'Bạn có chắc chắn muốn xóa nội quy "${rule.title}" không?',
                              onConfirm: () async {
                                await ref.read(handbookRepositoryProvider).deleteBuildingRule(rule.id);
                                ref.invalidate(buildingRulesProvider);
                              },
                            ),
                            tooltip: 'Xóa',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rule.content,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải nội quy: $e')),
      ),
    );
  }

  void _showRuleDialog({BuildingRuleModel? rule}) {
    final isEditing = rule != null;
    final titleController = TextEditingController(text: rule?.title ?? '');
    final contentController = TextEditingController(text: rule?.content ?? '');
    final orderController = TextEditingController(text: (rule?.displayOrder ?? 0).toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEditing ? 'Chỉnh sửa nội quy' : 'Thêm nội quy mới'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Tiêu đề nội quy *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Nội dung chi tiết *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập nội dung' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Thứ tự hiển thị (tùy chọn)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                final order = int.tryParse(orderController.text.trim()) ?? 0;
                final repo = ref.read(handbookRepositoryProvider);

                if (isEditing) {
                  await repo.updateBuildingRule(
                    id: rule.id,
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    displayOrder: order,
                  );
                } else {
                  await repo.createBuildingRule(
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    displayOrder: order,
                  );
                }
                ref.invalidate(buildingRulesProvider);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 3: Tiện Ích Tòa Nhà
  // ===========================================================================
  Widget _buildBuildingAmenitiesTab() {
    final amenitiesAsync = ref.watch(buildingAmenitiesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildingAmenitiesProvider),
      child: amenitiesAsync.when(
        data: (amenities) {
          if (amenities.isEmpty) {
            return const Center(child: Text('Chưa có tiện ích nào. Bấm + để thêm mới.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: amenities.length,
            itemBuilder: (context, index) {
              final amenity = amenities[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
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
                          Expanded(
                            child: Text(
                              amenity.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                            onPressed: () => _showAmenityDialog(amenity: amenity),
                            tooltip: 'Chỉnh sửa',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                            onPressed: () => _confirmDelete(
                              title: 'Xóa tiện ích',
                              message: 'Bạn có chắc chắn muốn xóa tiện ích "${amenity.name}" không?',
                              onConfirm: () async {
                                await ref.read(handbookRepositoryProvider).deleteBuildingAmenity(amenity.id);
                                ref.invalidate(buildingAmenitiesProvider);
                              },
                            ),
                            tooltip: 'Xóa',
                          ),
                        ],
                      ),
                      if (amenity.openHours != null && amenity.openHours!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: AppStatusColors.paid),
                            const SizedBox(width: 4),
                            Text(
                              'Giờ mở cửa: ${amenity.openHours!}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppStatusColors.paid,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (amenity.description != null && amenity.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          amenity.description!,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải tiện ích: $e')),
      ),
    );
  }

  void _showAmenityDialog({BuildingAmenityModel? amenity}) {
    final isEditing = amenity != null;
    final nameController = TextEditingController(text: amenity?.name ?? '');
    final hoursController = TextEditingController(text: amenity?.openHours ?? '');
    final descController = TextEditingController(text: amenity?.description ?? '');
    final orderController = TextEditingController(text: (amenity?.displayOrder ?? 0).toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEditing ? 'Chỉnh sửa tiện ích' : 'Thêm tiện ích mới'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên tiện ích *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên tiện ích' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: hoursController,
                  decoration: const InputDecoration(labelText: 'Giờ mở cửa (VD: 06:00 - 21:00)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mô tả & quy định sử dụng'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Thứ tự hiển thị (tùy chọn)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                final order = int.tryParse(orderController.text.trim()) ?? 0;
                final repo = ref.read(handbookRepositoryProvider);

                if (isEditing) {
                  await repo.updateBuildingAmenity(
                    id: amenity.id,
                    name: nameController.text.trim(),
                    openHours: hoursController.text.trim(),
                    description: descController.text.trim(),
                    displayOrder: order,
                  );
                } else {
                  await repo.createBuildingAmenity(
                    name: nameController.text.trim(),
                    openHours: hoursController.text.trim(),
                    description: descController.text.trim(),
                    displayOrder: order,
                  );
                }
                ref.invalidate(buildingAmenitiesProvider);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await onConfirm();
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
