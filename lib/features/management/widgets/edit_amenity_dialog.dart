import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/utils/error_formatter.dart';
import 'package:vivona/data/models/building_amenity_model.dart';
import 'package:vivona/data/providers/handbook_provider.dart';

void showEditAmenityDialog({
  required BuildContext context,
  required WidgetRef ref,
  BuildingAmenityModel? amenity,
}) {
  final isEditing = amenity != null;
  final nameController = TextEditingController(text: amenity?.name ?? '');
  final hoursController = TextEditingController(
    text: amenity?.openHours ?? '06:00 - 22:00',
  );
  final descController = TextEditingController(
    text: amenity?.description ?? '',
  );
  final capacityController = TextEditingController(
    text: (amenity?.maxCapacity ?? 1).toString(),
  );
  final durationController = TextEditingController(
    text: (amenity?.slotDurationMinutes ?? 90).toString(),
  );
  final feeController = TextEditingController(
    text: (amenity?.feeAmount ?? 0.0).toStringAsFixed(0),
  );
  final depositController = TextEditingController(
    text: (amenity?.depositAmount ?? 0.0).toStringAsFixed(0),
  );
  final orderController = TextEditingController(
    text: (amenity?.displayOrder ?? 0).toString(),
  );

  String bookingType = amenity?.bookingType ?? 'shared';
  bool requiresDeposit = amenity?.requiresDeposit ?? false;
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          isEditing ? 'Chỉnh Sửa Tiện Ích & Sức Chứa' : 'Thêm Tiện Ích Mới',
        ),
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
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tên tiện ích'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: bookingType,
                  decoration: const InputDecoration(
                    labelText: 'Hình thức đặt chỗ *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'shared',
                      child: Text('Dùng chung (Nhiều người/slot)'),
                    ),
                    DropdownMenuItem(
                      value: 'exclusive',
                      child: Text('Trọn gói (1 căn hộ/slot)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => bookingType = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sức chứa tối đa (người) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'Nhập số > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thời lượng (phút) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'Nhập số > 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: feeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Đơn giá lượt đặt (đ)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: depositController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tiền đặt cọc (đ)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yêu cầu đặt cọc trước'),
                  value: requiresDeposit,
                  onChanged: (val) =>
                      setDialogState(() => requiresDeposit = val),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: hoursController,
                  decoration: const InputDecoration(
                    labelText: 'Giờ mở cửa (VD: 06:00 - 22:00)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả & quy định sử dụng',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thứ tự hiển thị',
                    border: OutlineInputBorder(),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx);

              final cap = int.tryParse(capacityController.text.trim()) ?? 1;
              final duration =
                  int.tryParse(durationController.text.trim()) ?? 90;
              final fee = double.tryParse(feeController.text.trim()) ?? 0.0;
              final deposit =
                  double.tryParse(depositController.text.trim()) ?? 0.0;
              final order = int.tryParse(orderController.text.trim()) ?? 0;
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
                    maxCapacity: cap,
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
                    maxCapacity: cap,
                    slotDurationMinutes: duration,
                    feeAmount: fee,
                    depositAmount: deposit,
                    requiresDeposit: requiresDeposit,
                  );
                }

                ref.invalidate(buildingAmenitiesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Đã cập nhật cấu hình tiện ích!'
                            : 'Đã thêm tiện ích mới!',
                      ),
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
            child: const Text('Lưu cấu hình'),
          ),
        ],
      ),
    ),
  );
}

