import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/parking_slot_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../../../data/providers/parking_provider.dart';

class VehicleManagementScreen extends ConsumerStatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  ConsumerState<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState
    extends ConsumerState<VehicleManagementScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );

  void _showImageSourcePicker(
    BuildContext context,
    void Function(ImageSource source) onSourceSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Chọn nguồn ảnh minh chứng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Chụp ảnh từ máy ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSourceSelected(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Chọn ảnh từ Thư viện'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSourceSelected(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddVehicleDialog(
    BuildContext context, {
    required String apartmentId,
    required int currentMotorbikes,
  }) {
    final formKey = GlobalKey<FormState>();
    final plateController = TextEditingController();
    final brandModelController = TextEditingController();
    String selectedType = currentMotorbikes >= 2 ? 'car' : 'motorbike';
    File? selectedRegistrationImage;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final isMotorbikeDisabled = currentMotorbikes >= 2;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(modalContext).colorScheme.surface,
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
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Đăng Ký Phương Tiện Mới',
                        style: Theme.of(modalContext).textTheme.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đăng ký thông tin xe để Ban Quản Lý phê duyệt cấp thẻ ra vào và tính phí gửi xe định kỳ hàng tháng.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Loại phương tiện',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isMotorbikeDisabled
                                  ? null
                                  : () {
                                      setModalState(() {
                                        selectedType = 'motorbike';
                                      });
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedType == 'motorbike'
                                      ? AppTheme.primary.withValues(alpha: 0.1)
                                      : (isMotorbikeDisabled
                                            ? Theme.of(modalContext)
                                                  .disabledColor
                                                  .withValues(alpha: 0.1)
                                            : Theme.of(modalContext).cardColor),
                                  border: Border.all(
                                    color: selectedType == 'motorbike'
                                        ? AppTheme.primary
                                        : Theme.of(modalContext).dividerColor,
                                    width: selectedType == 'motorbike' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.two_wheeler_outlined,
                                      color: isMotorbikeDisabled
                                          ? Colors.grey.shade400
                                          : (selectedType == 'motorbike'
                                                ? AppTheme.primary
                                                : Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Xe máy',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isMotorbikeDisabled
                                            ? Colors.grey.shade400
                                            : (selectedType == 'motorbike'
                                                  ? AppTheme.primary
                                                  : Colors.grey.shade800),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isMotorbikeDisabled
                                          ? 'Đã đủ 2 xe'
                                          : AppConstants.kMotorbikeFeeShort,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMotorbikeDisabled
                                            ? AppTheme.error
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedType = 'car';
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedType == 'car'
                                      ? AppTheme.primary.withValues(alpha: 0.1)
                                      : Theme.of(modalContext).cardColor,
                                  border: Border.all(
                                    color: selectedType == 'car'
                                        ? AppTheme.primary
                                        : Theme.of(modalContext).dividerColor,
                                    width: selectedType == 'car' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.directions_car_outlined,
                                      color: selectedType == 'car'
                                          ? AppTheme.primary
                                          : Colors.grey.shade700,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ô tô',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: selectedType == 'car'
                                            ? AppTheme.primary
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppConstants.kCarFeeShort,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isMotorbikeDisabled) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppTheme.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Căn hộ đã đạt hạn mức 2 xe máy theo quy chế vận hành.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Biển số xe *',
                          hintText: 'Ví dụ: 29A-123.45 hoặc 59-X1 12345',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: brandModelController,
                        decoration: InputDecoration(
                          labelText: 'Hãng và mẫu xe (tùy chọn)',
                          hintText: 'Ví dụ: Honda AirBlade, Toyota Vios...',
                          prefixIcon: const Icon(
                            Icons.branding_watermark_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Minh chứng giấy đăng ký xe (Cà vẹt)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đính kèm ảnh cà vẹt rõ nét để BQL đối soát chính chủ và vị trí đỗ xe.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedRegistrationImage != null) ...[
                        Stack(
                          children: [
                            Container(
                              height: 130,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                                image: DecorationImage(
                                  image: FileImage(selectedRegistrationImage!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    selectedRegistrationImage = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        InkWell(
                          onTap: () {
                            _showImageSourcePicker(modalContext, (source) async {
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
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 28,
                                  color: AppTheme.primary.withValues(alpha: 0.8),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tải lên ảnh Cà vẹt / Giấy đăng ký xe',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Định dạng JPG, PNG (tối đa 5MB)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                          registrationImageUrl: uploadedImageUrl,
                                        );

                                    ref.invalidate(
                                      apartmentVehiclesProvider(apartmentId),
                                    );
                                    ref.invalidate(
                                      apartmentVehicleCountsProvider(
                                        apartmentId,
                                      ),
                                    );
                                    ref.invalidate(
                                      apartmentActiveMotorbikeCountProvider(
                                        apartmentId,
                                      ),
                                    );
                                    ref.invalidate(residentVehiclesProvider);

                                    if (modalContext.mounted) {
                                      Navigator.pop(modalContext);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Đăng ký phương tiện thành công! Đang chờ BQL phê duyệt.',
                                          ),
                                          backgroundColor: AppStatusColors.paid,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (modalContext.mounted) {
                                      ScaffoldMessenger.of(
                                        modalContext,
                                      ).showSnackBar(
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
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Xác Nhận Đăng Ký',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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
  }

  void _showEditVehicleDialog(
    BuildContext context,
    VehicleModel vehicle,
    int currentMotorbikes,
  ) {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final isMotorbikeDisabled =
              otherMotorbikes >= 2 && selectedType != 'motorbike';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(modalContext).colorScheme.surface,
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
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Chỉnh Sửa Thông Tin Phương Tiện',
                        style: Theme.of(modalContext).textTheme.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chỉ có thể chỉnh sửa khi hồ sơ đang chờ Ban Quản Lý phê duyệt.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Loại phương tiện *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: isMotorbikeDisabled
                                  ? null
                                  : () => setModalState(
                                      () => selectedType = 'motorbike',
                                    ),
                              child: Opacity(
                                opacity: isMotorbikeDisabled ? 0.5 : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: selectedType == 'motorbike'
                                          ? AppTheme.primary
                                          : Colors.grey.shade300,
                                      width: selectedType == 'motorbike'
                                          ? 2
                                          : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: selectedType == 'motorbike'
                                        ? AppTheme.primary.withValues(
                                            alpha: 0.05,
                                          )
                                        : Colors.transparent,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.two_wheeler_outlined,
                                        color: selectedType == 'motorbike'
                                            ? AppTheme.primary
                                            : Colors.grey,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Xe máy',
                                        style: TextStyle(
                                          fontWeight:
                                              selectedType == 'motorbike'
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: selectedType == 'motorbike'
                                              ? AppTheme.primary
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  setModalState(() => selectedType = 'car'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedType == 'car'
                                        ? AppTheme.primary
                                        : Colors.grey.shade300,
                                    width: selectedType == 'car' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: selectedType == 'car'
                                      ? AppTheme.primary.withValues(alpha: 0.05)
                                      : Colors.transparent,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.directions_car_outlined,
                                      color: selectedType == 'car'
                                          ? AppTheme.primary
                                          : Colors.grey,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ô tô',
                                      style: TextStyle(
                                        fontWeight: selectedType == 'car'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: selectedType == 'car'
                                            ? AppTheme.primary
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Biển số xe *',
                          hintText: 'VD: 29A-123.45',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: brandModelController,
                        decoration: InputDecoration(
                          labelText: 'Nhãn hiệu / Dòng xe (Tùy chọn)',
                          hintText: 'VD: Honda Vision, Mazda CX-5',
                          prefixIcon: const Icon(
                            Icons.branding_watermark_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                    ref.invalidate(
                                      apartmentVehiclesProvider(
                                        vehicle.apartmentId,
                                      ),
                                    );
                                    ref.invalidate(
                                      apartmentVehicleCountsProvider(
                                        vehicle.apartmentId,
                                      ),
                                    );
                                    ref.invalidate(
                                      apartmentActiveMotorbikeCountProvider(
                                        vehicle.apartmentId,
                                      ),
                                    );
                                    ref.invalidate(residentVehiclesProvider);

                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Đã cập nhật thông tin phương tiện thành công!',
                                          ),
                                          backgroundColor: AppTheme.success,
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
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Lưu Thay Đổi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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
  }

  void _confirmDeleteVehicle(BuildContext context, VehicleModel vehicle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
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
                ref.invalidate(apartmentVehiclesProvider(vehicle.apartmentId));
                ref.invalidate(
                  apartmentVehicleCountsProvider(vehicle.apartmentId),
                );
                ref.invalidate(
                  apartmentActiveMotorbikeCountProvider(vehicle.apartmentId),
                );
                ref.invalidate(residentVehiclesProvider);
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
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: Text(vehicle.isRejected ? 'Xác nhận xóa' : 'Xác nhận hủy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aptIdAsync = ref.watch(residentApartmentIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Phương Tiện Căn Hộ')),
      body: aptIdAsync.when(
        data: (apartmentId) {
          if (apartmentId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.home_work_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa Liên Kết Căn Hộ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bạn cần được Ban Quản Lý phê duyệt liên kết căn hộ trước khi thực hiện đăng ký phương tiện.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final vehiclesAsync = ref.watch(
            apartmentVehiclesProvider(apartmentId),
          );

          return vehiclesAsync.when(
            data: (vehicles) {
              final motorbikeCount = vehicles
                  .where((v) => v.isActive && v.isMotorbike)
                  .length;
              final carCount = vehicles
                  .where((v) => v.isActive && v.isCar)
                  .length;
              final allSlots =
                  ref.watch(parkingSlotsProvider).valueOrNull ?? [];

              final isDesktop = MediaQuery.sizeOf(context).width >= 900;

              final content = isDesktop
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cột trái: Hạn mức & Hướng dẫn
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      _buildQuotaCard(
                                        context,
                                        motorbikeCount,
                                        carCount,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildGuidelineCard(context),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Cột phải: Danh sách xe
                              Expanded(
                                flex: 7,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeaderRow(
                                      context,
                                      vehicles.length,
                                      apartmentId,
                                      motorbikeCount,
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: vehicles.isEmpty
                                          ? _buildEmptyVehiclesCard(
                                              context,
                                              apartmentId,
                                              motorbikeCount,
                                            )
                                          : ListView.builder(
                                              itemCount: vehicles.length,
                                              itemBuilder: (ctx, index) =>
                                                  _buildVehicleItem(
                                                    context,
                                                    vehicles[index],
                                                    allSlots,
                                                    motorbikeCount,
                                                    apartmentId,
                                                  ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildQuotaCard(
                              context,
                              motorbikeCount,
                              carCount,
                            ),
                            const SizedBox(height: 20),
                            _buildHeaderRow(
                              context,
                              vehicles.length,
                              apartmentId,
                              motorbikeCount,
                            ),
                            const SizedBox(height: 8),
                            if (vehicles.isEmpty) ...[
                              _buildEmptyVehiclesCard(
                                context,
                                apartmentId,
                                motorbikeCount,
                              ),
                            ] else ...[
                              ...vehicles.map(
                                (vehicle) => _buildVehicleItem(
                                  context,
                                  vehicle,
                                  allSlots,
                                  motorbikeCount,
                                  apartmentId,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(apartmentVehiclesProvider(apartmentId));
                  ref.invalidate(apartmentVehicleCountsProvider(apartmentId));
                  ref.invalidate(
                    apartmentActiveMotorbikeCountProvider(apartmentId),
                  );
                  ref.invalidate(residentVehiclesProvider);
                },
                child: content,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: AppErrorCard(
                error: e,
                onRetry: () =>
                    ref.invalidate(apartmentVehiclesProvider(apartmentId)),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: AppErrorCard(
            error: e,
            onRetry: () => ref.invalidate(residentApartmentIdProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaCard(
    BuildContext context,
    int motorbikeCount,
    int carCount,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_parking,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Hạn Mức Đăng Ký Căn Hộ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final motorbikeItem = Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Xe máy',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: motorbikeCount >= 2
                                    ? AppTheme.warning.withValues(alpha: 0.15)
                                    : AppStatusColors.paid.withValues(
                                        alpha: 0.15,
                                      ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$motorbikeCount/2 xe',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: motorbikeCount >= 2
                                      ? Colors.orange.shade900
                                      : AppStatusColors.paid,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppConstants.kMotorbikeFeeFormatted,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                final carItem = Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Ô tô',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$carCount xe',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppConstants.kCarFeeFormatted,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      motorbikeItem,
                      const SizedBox(height: 8),
                      carItem,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: motorbikeItem),
                    const SizedBox(width: 12),
                    Expanded(child: carItem),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Chỉ các phương tiện đã được Ban Quản Lý phê duyệt mới được tính phí gửi xe vào hóa đơn hàng tháng.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Quy Chế & Thủ Tục Bãi Xe',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGuidelineItem(
              Icons.schedule,
              'Thời gian duyệt đơn',
              'Ban Quản Lý xử lý duyệt đơn trong vòng 24 giờ làm việc.',
            ),
            const SizedBox(height: 8),
            _buildGuidelineItem(
              Icons.contactless,
              'Nhận thẻ xe NFC',
              'Sau khi được duyệt, cư dân đến quầy Lễ tân để nhận thẻ gửi xe thông minh.',
            ),
            const SizedBox(height: 8),
            _buildGuidelineItem(
              Icons.local_parking,
              'Vị trí đỗ xe',
              'Đỗ đúng ô quy định (Ô tô theo mã ô, xe máy tại khu vực vạch kẻ).',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    int totalCount,
    String apartmentId,
    int motorbikeCount,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Danh Sách Xe Đã Đăng Ký ($totalCount)',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Đăng ký mới'),
          ),
          onPressed: () => _showAddVehicleDialog(
            context,
            apartmentId: apartmentId,
            currentMotorbikes: motorbikeCount,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyVehiclesCard(
    BuildContext context,
    String apartmentId,
    int motorbikeCount,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 36,
          horizontal: 20,
        ),
        child: Column(
          children: [
            Icon(
              Icons.no_crash_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'Căn hộ chưa đăng ký phương tiện nào',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bấm "Đăng ký mới" để thêm xe máy hoặc ô tô vào danh sách căn hộ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleItem(
    BuildContext context,
    VehicleModel vehicle,
    List<ParkingSlotModel> allSlots,
    int motorbikeCount,
    String apartmentId,
  ) {
    final slotNum = vehicle.parkingSlotNumber;
    final assignedSlot = allSlots
        .where(
          (s) =>
              (vehicle.parkingSlotId != null &&
                  s.id == vehicle.parkingSlotId) ||
              (s.assignedVehicleId != null &&
                  s.assignedVehicleId == vehicle.id) ||
              (slotNum != null &&
                  slotNum.isNotEmpty &&
                  s.slotNumber == slotNum) ||
              (s.licensePlate != null &&
                  s.licensePlate!.trim().toUpperCase() ==
                      vehicle.plateNumber.trim().toUpperCase()),
        )
        .firstOrNull;

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: vehicle.isRejected
              ? AppTheme.error.withValues(alpha: 0.3)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Icon xe + Biển số + Badge trạng thái + Nút thao tác
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: vehicle.isMotorbike
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    vehicle.isMotorbike
                        ? Icons.two_wheeler_outlined
                        : Icons.directions_car_outlined,
                    color: vehicle.isMotorbike
                        ? Colors.orange.shade700
                        : AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: Colors.grey.shade400,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle.plateNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: vehicle.isApproved
                              ? AppStatusColors.paid.withValues(alpha: 0.12)
                              : vehicle.isRejected
                              ? AppTheme.error.withValues(alpha: 0.12)
                              : AppStatusColors.pending.withValues(
                                  alpha: 0.12,
                                ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle.statusDisplayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: vehicle.isApproved
                                ? AppStatusColors.paid
                                : vehicle.isRejected
                                ? AppTheme.error
                                : AppStatusColors.pending,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vehicle.isPending) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        tooltip: 'Sửa thông tin xe',
                        onPressed: () => _showEditVehicleDialog(
                          context,
                          vehicle,
                          motorbikeCount,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        vehicle.isRejected
                            ? Icons.delete_forever_outlined
                            : Icons.delete_outline,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      tooltip: vehicle.isRejected
                          ? 'Xóa bản ghi xe bị từ chối'
                          : 'Hủy đăng ký xe',
                      onPressed: () => _confirmDeleteVehicle(
                        context,
                        vehicle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Hàng 2: Tên xe & Model
            Row(
              children: [
                Text(
                  vehicle.vehicleTypeName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (vehicle.brandModel != null &&
                    vehicle.brandModel!.trim().isNotEmpty) ...[
                  Expanded(
                    child: Text(
                      ' • ${vehicle.brandModel!.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            // Hàng 3: Biểu phí & Ngày đăng ký
            Text(
              'Biểu phí: ${_currencyFormat.format(vehicle.monthlyFee)}/tháng • Ngày đăng ký: ${_dateFormat.format(vehicle.createdAt)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Hàng 4: Slot ô đỗ & Ảnh cà vẹt xe (Wrap)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if ((slotNum != null && slotNum.isNotEmpty) ||
                    assignedSlot != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_parking,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Vị trí ô đỗ: ${(slotNum != null && slotNum.isNotEmpty) ? slotNum : assignedSlot!.slotNumber}${assignedSlot != null ? ' (Tầng ${assignedSlot.zone})' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (vehicle.hasRegistrationImage) ...[
                  InkWell(
                    onTap: () {
                      final repo = ref.read(vehicleRepositoryProvider);
                      final fullUrl = repo.getRegistrationImageUrl(
                        vehicle.registrationImageUrl,
                      );
                      if (fullUrl.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoViewerScreen(
                              imageUrls: [fullUrl],
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.shade200,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 13,
                            color: AppTheme.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Xem ảnh cà vẹt xe',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 11,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Lý do từ chối nếu bị từ chối
            if (vehicle.isRejected) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lý do từ chối: ${vehicle.hasRejectionReason ? vehicle.rejectionReason! : 'Không đủ điều kiện cấp thẻ xe theo quy chế tòa nhà.'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
