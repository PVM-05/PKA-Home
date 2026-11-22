import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vivona/core/constants/app_constants.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/utils/error_formatter.dart';
import 'package:vivona/data/models/vehicle_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/vehicle_provider.dart';

void _invalidateVehicleProviders(WidgetRef ref, String apartmentId) {
  ref.invalidate(apartmentVehiclesProvider(apartmentId));
  ref.invalidate(apartmentVehicleCountsProvider(apartmentId));
  ref.invalidate(apartmentActiveMotorbikeCountProvider(apartmentId));
  ref.invalidate(residentVehiclesProvider);
}

void _showImageSourcePicker(
  BuildContext context,
  void Function(ImageSource source) onSourceSelected,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      final textTheme = Theme.of(ctx).textTheme;

      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Chọn nguồn ảnh minh chứng',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.h12,
              ListTile(
                minVerticalPadding: 14,
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('Chụp ảnh từ máy ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSourceSelected(ImageSource.camera);
                },
              ),
              ListTile(
                minVerticalPadding: 14,
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('Chọn ảnh từ Thư viện'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSourceSelected(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showAddVehicleSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String apartmentId,
  required int currentMotorbikes,
}) async {
  final formKey = GlobalKey<FormState>();
  final plateController = TextEditingController();
  final brandModelController = TextEditingController();
  String selectedType = currentMotorbikes >= 2 ? 'car' : 'motorbike';
  File? selectedRegistrationImage;
  bool isSubmitting = false;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final theme = Theme.of(modalContext);
          final colorScheme = theme.colorScheme;
          final textTheme = theme.textTheme;
          final isMotorbikeDisabled = currentMotorbikes >= 2;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Đăng Ký Phương Tiện Mới',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      AppSpacing.h8,
                      Text(
                        'Đăng ký thông tin xe để Ban Quản Lý phê duyệt cấp thẻ ra vào và tính phí gửi xe định kỳ hàng tháng.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      AppSpacing.h20,
                      Text(
                        'Loại phương tiện',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.h8,
                      Row(
                        children: [
                          Expanded(
                            child: _VehicleTypeOptionTile(
                              icon: Icons.two_wheeler_outlined,
                              label: 'Xe máy',
                              subtitle: isMotorbikeDisabled
                                  ? 'Đã đủ 2 xe'
                                  : AppConstants.kMotorbikeFeeShort,
                              isSelected: selectedType == 'motorbike',
                              isDisabled: isMotorbikeDisabled,
                              onTap: isMotorbikeDisabled
                                  ? null
                                  : () => setModalState(
                                      () => selectedType = 'motorbike',
                                    ),
                            ),
                          ),
                          AppSpacing.w12,
                          Expanded(
                            child: _VehicleTypeOptionTile(
                              icon: Icons.directions_car_outlined,
                              label: 'Ô tô',
                              subtitle: AppConstants.kCarFeeShort,
                              isSelected: selectedType == 'car',
                              isDisabled: false,
                              onTap: () => setModalState(
                                () => selectedType = 'car',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isMotorbikeDisabled) ...[
                        AppSpacing.h8,
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppTheme.getSemanticWarning(modalContext),
                            ),
                            AppSpacing.w6,
                            Expanded(
                              child: Text(
                                'Căn hộ đã đạt hạn mức 2 xe máy theo quy chế vận hành.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppTheme.getSemanticWarning(
                                    modalContext,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      AppSpacing.h16,
                      TextFormField(
                        controller: plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Biển số xe *',
                          hintText: 'Ví dụ: 29A-123.45 hoặc 59-X1 12345',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.r12,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerLow,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập biển số xe';
                          }
                          if (value.trim().length < 4 ||
                              value.trim().length > 15) {
                            return 'Biển số xe không hợp lệ (từ 4 đến 15 ký tự)';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.h12,
                      TextFormField(
                        controller: brandModelController,
                        decoration: InputDecoration(
                          labelText: 'Hãng và mẫu xe (tùy chọn)',
                          hintText: 'Ví dụ: Honda AirBlade, Toyota Vios...',
                          prefixIcon: const Icon(
                            Icons.branding_watermark_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.r12,
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerLow,
                        ),
                      ),
                      AppSpacing.h16,
                      Text(
                        'Minh chứng giấy đăng ký xe (Cà vẹt)',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.h4,
                      Text(
                        'Đính kèm ảnh cà vẹt rõ nét để BQL đối soát chính chủ và vị trí đỗ xe.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.h8,
                      if (selectedRegistrationImage != null)
                        Stack(
                          children: [
                            Container(
                              height: 130,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: AppRadius.r12,
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                                image: DecorationImage(
                                  image: FileImage(selectedRegistrationImage!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                tooltip: 'Xóa ảnh đã chọn',
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.scrim.withValues(
                                    alpha: 0.65,
                                  ),
                                  foregroundColor: colorScheme.onInverseSurface,
                                ),
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setModalState(
                                  () => selectedRegistrationImage = null,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: () {
                            _showImageSourcePicker(modalContext, (
                              source,
                            ) async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: source,
                                imageQuality: 85,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  selectedRegistrationImage = File(picked.path);
                                });
                              }
                            });
                          },
                          borderRadius: AppRadius.r12,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: AppRadius.r12,
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 28,
                                  color: colorScheme.primary,
                                ),
                                AppSpacing.h6,
                                Text(
                                  'Tải lên ảnh Cà vẹt / Giấy đăng ký xe',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                AppSpacing.h4,
                                Text(
                                  'Định dạng JPG, PNG (tối đa 5MB)',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      AppSpacing.h24,
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.r12,
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);

                                  try {
                                    final user = ref
                                        .read(authProvider)
                                        .valueOrNull;
                                    if (user == null) {
                                      throw Exception(
                                        'Phiên đăng nhập hết hạn.',
                                      );
                                    }

                                    String? uploadedImageUrl;
                                    if (selectedRegistrationImage != null) {
                                      uploadedImageUrl = await ref
                                          .read(vehicleRepositoryProvider)
                                          .uploadRegistrationImage(
                                            apartmentId,
                                            user.id,
                                            selectedRegistrationImage!,
                                          );
                                    }

                                    await ref
                                        .read(vehicleRepositoryProvider)
                                        .registerVehicle(
                                          apartmentId: apartmentId,
                                          plateNumber: plateController.text
                                              .trim(),
                                          vehicleType: selectedType,
                                          brandModel:
                                              brandModelController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : brandModelController.text
                                                    .trim(),
                                          userId: user.id,
                                          registrationImageUrl:
                                              uploadedImageUrl,
                                        );

                                    _invalidateVehicleProviders(
                                      ref,
                                      apartmentId,
                                    );

                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Đăng ký phương tiện thành công! Đang chờ BQL phê duyệt.',
                                            ),
                                            backgroundColor:
                                                AppTheme.textSuccess,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (modalContext.mounted) {
                                      ScaffoldMessenger.of(
                                        modalContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(formatErrorMessage(e)),
                                          backgroundColor: AppTheme.textError,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: colorScheme.onPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Xác Nhận Đăng Ký',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  } finally {
    plateController.dispose();
    brandModelController.dispose();
  }
}

Future<void> showEditVehicleSheet({
  required BuildContext context,
  required WidgetRef ref,
  required VehicleModel vehicle,
  required int currentMotorbikes,
}) async {
  final formKey = GlobalKey<FormState>();
  final plateController = TextEditingController(text: vehicle.plateNumber);
  final brandModelController = TextEditingController(
    text: vehicle.brandModel ?? '',
  );
  String selectedType = vehicle.vehicleType;
  bool isSubmitting = false;

  final otherMotorbikes = vehicle.isMotorbike
      ? (currentMotorbikes - 1)
      : currentMotorbikes;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final theme = Theme.of(modalContext);
          final colorScheme = theme.colorScheme;
          final textTheme = theme.textTheme;
          final isMotorbikeDisabled =
              otherMotorbikes >= 2 && selectedType != 'motorbike';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Chỉnh Sửa Thông Tin Phương Tiện',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      AppSpacing.h8,
                      Text(
                        'Chỉ có thể chỉnh sửa khi hồ sơ đang chờ Ban Quản Lý phê duyệt.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.h20,
                      Text(
                        'Loại phương tiện *',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.h8,
                      Row(
                        children: [
                          Expanded(
                            child: _VehicleTypeOptionTile(
                              icon: Icons.two_wheeler_outlined,
                              label: 'Xe máy',
                              isSelected: selectedType == 'motorbike',
                              isDisabled: isMotorbikeDisabled,
                              onTap: isMotorbikeDisabled
                                  ? null
                                  : () => setModalState(
                                      () => selectedType = 'motorbike',
                                    ),
                            ),
                          ),
                          AppSpacing.w12,
                          Expanded(
                            child: _VehicleTypeOptionTile(
                              icon: Icons.directions_car_outlined,
                              label: 'Ô tô',
                              isSelected: selectedType == 'car',
                              isDisabled: false,
                              onTap: () => setModalState(
                                () => selectedType = 'car',
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h16,
                      TextFormField(
                        controller: plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Biển số xe *',
                          hintText: 'VD: 29A-123.45',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.r12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập biển số xe';
                          }
                          if (value.trim().length < 4) {
                            return 'Biển số xe không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.h16,
                      TextFormField(
                        controller: brandModelController,
                        decoration: InputDecoration(
                          labelText: 'Nhãn hiệu / Dòng xe (Tùy chọn)',
                          hintText: 'VD: Honda Vision, Mazda CX-5',
                          prefixIcon: const Icon(
                            Icons.branding_watermark_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.r12,
                          ),
                        ),
                      ),
                      AppSpacing.h24,
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.r12,
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await ref
                                        .read(vehicleRepositoryProvider)
                                        .updatePendingVehicle(
                                          vehicleId: vehicle.id,
                                          licensePlate: plateController.text
                                              .trim()
                                              .toUpperCase(),
                                          vehicleType: selectedType,
                                          brandModel:
                                              brandModelController.text
                                                  .trim()
                                                  .isNotEmpty
                                              ? brandModelController.text.trim()
                                              : null,
                                        );
                                    _invalidateVehicleProviders(
                                      ref,
                                      vehicle.apartmentId,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Đã cập nhật thông tin phương tiện thành công!',
                                          ),
                                          backgroundColor: AppTheme.textSuccess,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(formatErrorMessage(e)),
                                          backgroundColor: AppTheme.textError,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: colorScheme.onPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Lưu Thay Đổi',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  } finally {
    plateController.dispose();
    brandModelController.dispose();
  }
}

Future<void> showConfirmDeleteVehicleDialog({
  required BuildContext context,
  required WidgetRef ref,
  required VehicleModel vehicle,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        title: Text(
          vehicle.isRejected
              ? 'Xóa Bản Ghi Bị Từ Chối'
              : (vehicle.isPending
                    ? 'Hủy Đăng Ký Đang Chờ'
                    : 'Hủy Đăng Ký Phương Tiện'),
        ),
        content: Text(
          vehicle.isRejected
              ? 'Bạn có chắc chắn muốn xóa bản ghi ${vehicle.vehicleTypeName.toLowerCase()} có biển số ${vehicle.plateNumber} đã bị từ chối không?\n\nSau khi xóa, bạn có thể thực hiện đăng ký xe mới.'
              : (vehicle.isPending
                    ? 'Bạn có chắc chắn muốn hủy đăng ký ${vehicle.vehicleTypeName.toLowerCase()} có biển số ${vehicle.plateNumber} đang chờ duyệt không?'
                    : 'Bạn có chắc chắn muốn hủy đăng ký ${vehicle.vehicleTypeName.toLowerCase()} có biển số ${vehicle.plateNumber} không?\n\nSau khi hủy, thẻ xe tương ứng sẽ bị khóa hiệu lực.'),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textError,
              foregroundColor: colorScheme.onError,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (vehicle.isPending) {
                  await ref
                      .read(vehicleRepositoryProvider)
                      .cancelPendingVehicle(vehicle.id);
                } else {
                  await ref
                      .read(vehicleRepositoryProvider)
                      .deleteVehicle(vehicle.id);
                }
                _invalidateVehicleProviders(ref, vehicle.apartmentId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        vehicle.isRejected
                            ? 'Đã xóa bản ghi phương tiện thành công.'
                            : 'Đã hủy đăng ký phương tiện thành công.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(formatErrorMessage(e)),
                      backgroundColor: AppTheme.textError,
                    ),
                  );
                }
              }
            },
            child: Text(vehicle.isRejected ? 'Xác nhận xóa' : 'Xác nhận hủy'),
          ),
        ],
      );
    },
  );
}

class _VehicleTypeOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _VehicleTypeOptionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = AppTheme.getSemanticError(context);

    final Color contentColor;
    if (isDisabled) {
      contentColor = colorScheme.onSurface.withValues(alpha: 0.38);
    } else if (isSelected) {
      contentColor = colorScheme.primary;
    } else {
      contentColor = colorScheme.onSurface;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.r12,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.08)
              : (isDisabled
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : colorScheme.surfaceContainerLow),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: AppRadius.r12,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: contentColor, size: 24),
            AppSpacing.h6,
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
            ),
            if (subtitle != null) ...[
              AppSpacing.h4,
              Text(
                subtitle!,
                style: textTheme.labelSmall?.copyWith(
                  color: isDisabled
                      ? errorColor
                      : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
