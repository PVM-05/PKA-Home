import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/models/building_rule_model.dart';
import '../../../data/models/emergency_contact_model.dart';
import '../../../data/providers/handbook_provider.dart';

class HandbookManagementScreen extends ConsumerStatefulWidget {
  const HandbookManagementScreen({super.key});

  @override
  ConsumerState<HandbookManagementScreen> createState() =>
      _HandbookManagementScreenState();
}

class _HandbookManagementScreenState
    extends ConsumerState<HandbookManagementScreen>
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
    final colorScheme = Theme.of(context).colorScheme;

    return RoleGuard(
      permission: AppPermissions.handbookManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản Lý Cẩm Nang Tòa Nhà'),
          bottom: TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
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
          heroTag: 'handbook_management_fab',
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
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
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Đường Dây Nóng
  // ===========================================================================
  Widget _buildEmergencyContactsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(emergencyContactsProvider),
      child: contactsAsync.when(
        data: (contacts) {
          if (contacts.isEmpty) {
            return ListView(
              padding: AppSpacing.p16,
              children: const [
                AppEmptyState(
                  icon: Icons.emergency_outlined,
                  title: 'Chưa có đường dây nóng',
                  description:
                      'Chưa có thông tin đường dây nóng. Bấm + để thêm mới.',
                ),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.r12,
                          ),
                          child: Icon(
                            Icons.phone_in_talk,
                            color: colorScheme.primary,
                          ),
                        ),
                        AppSpacing.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                style: context.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              AppSpacing.h4,
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'SĐT: ${contact.phone}',
                                    style: context.bodySmall
                                        ?.tabularFigures()
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: AppRadius.r4,
                                    ),
                                    child: Text(
                                      contact.contactTypeDisplayName,
                                      style: context.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Thứ tự: ${contact.displayOrder}',
                                    style: context.labelSmall
                                        ?.tabularFigures()
                                        .copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.w4,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: () =>
                                  _showContactDialog(contact: contact),
                              tooltip: 'Chỉnh sửa',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: errorColor,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: () => _confirmDelete(
                                title: 'Xóa đường dây nóng',
                                message:
                                    'Bạn có chắc chắn muốn xóa "${contact.name}" không?',
                                onConfirm: () async {
                                  await ref
                                      .read(handbookRepositoryProvider)
                                      .deleteEmergencyContact(contact.id);
                                  ref.invalidate(emergencyContactsProvider);
                                },
                              ),
                              tooltip: 'Xóa',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 80),
          ],
        ),
        error: (e, _) => ListView(
          padding: AppSpacing.p16,
          children: [
            AppErrorCard(
              error: e,
              onRetry: () => ref.invalidate(emergencyContactsProvider),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog({EmergencyContactModel? contact}) {
    final isEditing = contact != null;
    final nameController = TextEditingController(text: contact?.name ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final orderController = TextEditingController(
      text: (contact?.displayOrder ?? 0).toString(),
    );
    String contactType = contact?.contactType ?? 'security';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Text(
            isEditing ? 'Chỉnh sửa đường dây nóng' : 'Thêm đường dây nóng',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên đầu mối liên hệ *',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên'
                        : null,
                  ),
                  AppSpacing.h12,
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại *',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập số điện thoại'
                        : null,
                  ),
                  AppSpacing.h12,
                  DropdownButtonFormField<String>(
                    initialValue: contactType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Phân loại'),
                    items: const [
                      DropdownMenuItem(
                        value: 'security',
                        child: Text('An ninh / Bảo vệ'),
                      ),
                      DropdownMenuItem(
                        value: 'fire',
                        child: Text('PCCC / Cứu hộ'),
                      ),
                      DropdownMenuItem(
                        value: 'management',
                        child: Text('Ban Quản Lý'),
                      ),
                      DropdownMenuItem(
                        value: 'technical',
                        child: Text('Đội Kỹ Thuật'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => contactType = val);
                    },
                  ),
                  AppSpacing.h12,
                  TextFormField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thứ tự hiển thị (tùy chọn)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx);
                  final order = int.tryParse(orderController.text.trim()) ?? 0;
                  final repo = ref.read(handbookRepositoryProvider);

                  try {
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
                    if (mounted) {
                      AppSnackBar.showSuccess(
                        context,
                        isEditing
                            ? 'Đã cập nhật đường dây nóng!'
                            : 'Đã thêm đường dây nóng thành công!',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.showError(context, formatErrorMessage(e));
                    }
                  }
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
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    final rulesAsync = ref.watch(buildingRulesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildingRulesProvider),
      child: rulesAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return ListView(
              padding: AppSpacing.p16,
              children: const [
                AppEmptyState(
                  icon: Icons.gavel_outlined,
                  title: 'Chưa có nội quy tòa nhà',
                  description: 'Chưa có nội quy. Bấm + để thêm mới.',
                ),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: rules.length,
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: AppSpacing.p16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${index + 1}. ${rule.title}',
                                style: context.titleSmall
                                    ?.tabularFigures()
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            AppSpacing.w4,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () => _showRuleDialog(rule: rule),
                                  tooltip: 'Chỉnh sửa',
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: errorColor,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () => _confirmDelete(
                                    title: 'Xóa nội quy',
                                    message:
                                        'Bạn có chắc chắn muốn xóa nội quy "${rule.title}" không?',
                                    onConfirm: () async {
                                      await ref
                                          .read(handbookRepositoryProvider)
                                          .deleteBuildingRule(rule.id);
                                      ref.invalidate(buildingRulesProvider);
                                    },
                                  ),
                                  tooltip: 'Xóa',
                                ),
                              ],
                            ),
                          ],
                        ),
                        AppSpacing.h8,
                        Text(
                          rule.content,
                          style: context.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 96),
          ],
        ),
        error: (e, _) => ListView(
          padding: AppSpacing.p16,
          children: [
            AppErrorCard(
              error: e,
              onRetry: () => ref.invalidate(buildingRulesProvider),
            ),
          ],
        ),
      ),
    );
  }

  void _showRuleDialog({BuildingRuleModel? rule}) {
    final isEditing = rule != null;
    final titleController = TextEditingController(text: rule?.title ?? '');
    final contentController = TextEditingController(text: rule?.content ?? '');
    final orderController = TextEditingController(
      text: (rule?.displayOrder ?? 0).toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        title: Text(isEditing ? 'Chỉnh sửa nội quy' : 'Thêm nội quy mới'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề nội quy *',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tiêu đề'
                      : null,
                ),
                AppSpacing.h12,
                TextFormField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung chi tiết *',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập nội dung'
                      : null,
                ),
                AppSpacing.h12,
                TextFormField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thứ tự hiển thị (tùy chọn)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                final order = int.tryParse(orderController.text.trim()) ?? 0;
                final repo = ref.read(handbookRepositoryProvider);

                try {
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
                  if (mounted) {
                    AppSnackBar.showSuccess(
                      context,
                      isEditing
                          ? 'Đã cập nhật nội quy!'
                          : 'Đã thêm nội quy thành công!',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackBar.showError(context, formatErrorMessage(e));
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

  // ===========================================================================
  // Tab 3: Tiện Ích Tòa Nhà
  // ===========================================================================
  Widget _buildBuildingAmenitiesTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final paidColor = AppStatusColors.getPaid(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final errorColor = AppTheme.getSemanticError(context);
    final amenitiesAsync = ref.watch(buildingAmenitiesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildingAmenitiesProvider),
      child: amenitiesAsync.when(
        data: (amenities) {
          if (amenities.isEmpty) {
            return ListView(
              padding: AppSpacing.p16,
              children: const [
                AppEmptyState(
                  icon: Icons.pool_outlined,
                  title: 'Chưa có tiện ích nào',
                  description: 'Chưa có tiện ích nào. Bấm + để thêm mới.',
                ),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: amenities.length,
                itemBuilder: (context, index) {
                  final amenity = amenities[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: AppSpacing.p16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                amenity.name,
                                style: context.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            AppSpacing.w4,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () =>
                                      _showAmenityDialog(amenity: amenity),
                                  tooltip: 'Chỉnh sửa',
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: errorColor,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () => _confirmDelete(
                                    title: 'Xóa tiện ích',
                                    message:
                                        'Bạn có chắc chắn muốn xóa tiện ích "${amenity.name}" không?',
                                    onConfirm: () async {
                                      await ref
                                          .read(handbookRepositoryProvider)
                                          .deleteBuildingAmenity(amenity.id);
                                      ref.invalidate(buildingAmenitiesProvider);
                                    },
                                  ),
                                  tooltip: 'Xóa',
                                ),
                              ],
                            ),
                          ],
                        ),
                        AppSpacing.h8,
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (amenity.openHours != null &&
                                amenity.openHours!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: paidColor.withValues(alpha: 0.1),
                                  borderRadius: AppRadius.r8,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: paidColor,
                                      ),
                                      AppSpacing.w4,
                                      Text(
                                        amenity.openHours!,
                                        style: context.labelSmall
                                            ?.tabularFigures()
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: paidColor,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: AppRadius.r8,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      amenity.isShared
                                          ? Icons.groups_outlined
                                          : Icons.lock_clock_outlined,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                    AppSpacing.w4,
                                    Text(
                                      amenity.isShared
                                          ? 'Dùng chung (${amenity.maxCapacity} người)'
                                          : 'Bao trọn khung giờ',
                                      style: context.labelSmall
                                          ?.tabularFigures()
                                          .copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (amenity.feeAmount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: secondaryColor.withValues(alpha: 0.1),
                                  borderRadius: AppRadius.r8,
                                ),
                                child: Text(
                                  'Phí: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(amenity.feeAmount)}',
                                  style: context.labelSmall
                                      ?.tabularFigures()
                                      .copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: secondaryColor,
                                      ),
                                ),
                              ),
                            if (amenity.requiresDeposit &&
                                amenity.depositAmount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: warningColor.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.r8,
                                ),
                                child: Text(
                                  'Cọc: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(amenity.depositAmount)}',
                                  style: context.labelSmall
                                      ?.tabularFigures()
                                      .copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: warningColor,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        if (amenity.description != null &&
                            amenity.description!.isNotEmpty) ...[
                          AppSpacing.h8,
                          Text(
                            amenity.description!,
                            style: context.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 112),
          ],
        ),
        error: (e, _) => ListView(
          padding: AppSpacing.p16,
          children: [
            AppErrorCard(
              error: e,
              onRetry: () => ref.invalidate(buildingAmenitiesProvider),
            ),
          ],
        ),
      ),
    );
  }

  void _showAmenityDialog({BuildingAmenityModel? amenity}) {
    final isEditing = amenity != null;
    final nameController = TextEditingController(text: amenity?.name ?? '');
    final hoursController = TextEditingController(
      text: amenity?.openHours ?? '',
    );
    final descController = TextEditingController(
      text: amenity?.description ?? '',
    );
    final orderController = TextEditingController(
      text: (amenity?.displayOrder ?? 0).toString(),
    );
    final capacityController = TextEditingController(
      text: (amenity?.maxCapacity ?? 1).toString(),
    );
    final durationController = TextEditingController(
      text: (amenity?.slotDurationMinutes ?? 60).toString(),
    );
    final feeController = TextEditingController(
      text: (amenity?.feeAmount ?? 0).toInt().toString(),
    );
    final depositController = TextEditingController(
      text: (amenity?.depositAmount ?? 0).toInt().toString(),
    );
    String bookingType = amenity?.bookingType ?? 'shared';
    bool requiresDeposit = amenity?.requiresDeposit ?? false;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Text(isEditing ? 'Chỉnh sửa tiện ích' : 'Thêm tiện ích mới'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên tiện ích *',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên tiện ích'
                        : null,
                  ),
                  AppSpacing.h12,
                  DropdownButtonFormField<String>(
                    initialValue: bookingType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hình thức đặt chỗ',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'shared',
                        child: Text('Dùng chung (nhiều người cùng đặt)'),
                      ),
                      DropdownMenuItem(
                        value: 'exclusive',
                        child: Text('Bao trọn khung giờ (1 lượt/khung)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => bookingType = val);
                      }
                    },
                  ),
                  AppSpacing.h12,
                  TextFormField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sức chứa tối đa (người) *',
                      helperText:
                          'Số người tối đa cùng lúc trong một khung giờ',
                    ),
                    validator: (v) {
                      final parsed = int.tryParse(v?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Vui lòng nhập số người hợp lệ (> 0)';
                      }
                      return null;
                    },
                  ),
                  AppSpacing.h12,
                  TextFormField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thời lượng khung giờ (phút) *',
                    ),
                    validator: (v) {
                      final parsed = int.tryParse(v?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Vui lòng nhập thời lượng (> 0)';
                      }
                      return null;
                    },
                  ),
                  AppSpacing.h12,
                  TextFormField(
                    controller: hoursController,
                    decoration: const InputDecoration(
                      labelText: 'Giờ mở cửa (VD: 06:00 - 21:00)',
                    ),
                  ),
                  AppSpacing.h12,
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: feeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Phí sử dụng (đ)',
                          ),
                        ),
                      ),
                      AppSpacing.w8,
                      Expanded(
                        child: TextFormField(
                          controller: orderController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Thứ tự hiển thị',
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h8,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Yêu cầu đặt cọc trước'),
                    value: requiresDeposit,
                    onChanged: (val) =>
                        setDialogState(() => requiresDeposit = val),
                  ),
                  if (requiresDeposit) ...[
                    TextFormField(
                      controller: depositController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số tiền đặt cọc (đ) *',
                      ),
                      validator: (v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Số tiền cọc không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    AppSpacing.h12,
                  ],
                  TextFormField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả & quy định sử dụng',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx);
                  final order = int.tryParse(orderController.text.trim()) ?? 0;
                  final capacity =
                      int.tryParse(capacityController.text.trim()) ?? 1;
                  final duration =
                      int.tryParse(durationController.text.trim()) ?? 60;
                  final fee = double.tryParse(feeController.text.trim()) ?? 0.0;
                  final deposit = requiresDeposit
                      ? (double.tryParse(depositController.text.trim()) ?? 0.0)
                      : 0.0;
                  final repo = ref.read(handbookRepositoryProvider);

                  try {
                    if (isEditing) {
                      await repo.updateBuildingAmenity(
                        id: amenity.id,
                        name: nameController.text.trim(),
                        openHours: hoursController.text.trim(),
                        description: descController.text.trim(),
                        displayOrder: order,
                        bookingType: bookingType,
                        maxCapacity: capacity,
                        slotDurationMinutes: duration,
                        feeAmount: fee,
                        depositAmount: deposit,
                        requiresDeposit: requiresDeposit,
                      );
                    } else {
                      await repo.createBuildingAmenity(
                        name: nameController.text.trim(),
                        openHours: hoursController.text.trim(),
                        description: descController.text.trim(),
                        displayOrder: order,
                        bookingType: bookingType,
                        maxCapacity: capacity,
                        slotDurationMinutes: duration,
                        feeAmount: fee,
                        depositAmount: deposit,
                        requiresDeposit: requiresDeposit,
                      );
                    }
                    ref.invalidate(buildingAmenitiesProvider);
                    if (mounted) {
                      AppSnackBar.showSuccess(
                        context,
                        isEditing
                            ? 'Đã cập nhật tiện ích!'
                            : 'Đã thêm tiện ích thành công!',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.showError(context, formatErrorMessage(e));
                    }
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
    String successMessage = 'Đã xóa thành công!',
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final errorColor = AppTheme.getSemanticError(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await onConfirm();
                  if (mounted) {
                    AppSnackBar.showSuccess(context, successMessage);
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackBar.showError(context, formatErrorMessage(e));
                  }
                }
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }
}
