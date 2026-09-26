import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/vehicle_provider.dart';

class VehicleManagementScreen extends ConsumerStatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  ConsumerState<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends ConsumerState<VehicleManagementScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  void _showAddVehicleDialog(BuildContext context, {required String apartmentId, required int currentMotorbikes}) {
    final formKey = GlobalKey<FormState>();
    final plateController = TextEditingController();
    String selectedType = currentMotorbikes >= 2 ? 'car' : 'motorbike';
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                      style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đăng ký biển số xe để Ban Quản Lý cấp thẻ ra vào và tính phí gửi xe định kỳ hàng tháng.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Loại phương tiện',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: selectedType == 'motorbike'
                                    ? AppTheme.primary.withValues(alpha: 0.1)
                                    : (isMotorbikeDisabled ? Colors.grey.shade100 : Colors.white),
                                border: Border.all(
                                  color: selectedType == 'motorbike'
                                      ? AppTheme.primary
                                      : (isMotorbikeDisabled ? Colors.grey.shade300 : Colors.grey.shade300),
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
                                        : (selectedType == 'motorbike' ? AppTheme.primary : Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Xe máy',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isMotorbikeDisabled
                                          ? Colors.grey.shade400
                                          : (selectedType == 'motorbike' ? AppTheme.primary : Colors.grey.shade800),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isMotorbikeDisabled ? 'Đã đủ 2 xe' : '100.000đ/tháng',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMotorbikeDisabled ? AppTheme.error : Colors.grey.shade600,
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
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: selectedType == 'car'
                                    ? AppTheme.primary.withValues(alpha: 0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: selectedType == 'car' ? AppTheme.primary : Colors.grey.shade300,
                                  width: selectedType == 'car' ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.directions_car_outlined,
                                    color: selectedType == 'car' ? AppTheme.primary : Colors.grey.shade700,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Ô tô',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: selectedType == 'car' ? AppTheme.primary : Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '1.200.000đ/tháng',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                          const Icon(Icons.info_outline, size: 14, color: AppTheme.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Căn hộ đã đạt hạn mức 2 xe máy theo quy chế vận hành.',
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
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
                        labelText: 'Biển số xe',
                        hintText: 'Ví dụ: 29A-123.45 hoặc 59-X1 12345',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập biển số xe';
                        }
                        if (value.trim().length < 4 || value.trim().length > 15) {
                          return 'Biển số xe không hợp lệ (từ 4 đến 15 ký tự)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSubmitting = true);

                                try {
                                  final user = ref.read(authProvider).valueOrNull;
                                  if (user == null) {
                                    throw Exception('Phiên đăng nhập hết hạn.');
                                  }

                                  await ref.read(vehicleRepositoryProvider).registerVehicle(
                                        apartmentId: apartmentId,
                                        plateNumber: plateController.text.trim(),
                                        vehicleType: selectedType,
                                        userId: user.id,
                                      );

                                  if (modalContext.mounted) {
                                    Navigator.pop(modalContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Đăng ký phương tiện thành công!'),
                                        backgroundColor: AppStatusColors.paid,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (modalContext.mounted) {
                                    ScaffoldMessenger.of(modalContext).showSnackBar(
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
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Xác Nhận Đăng Ký',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
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
        title: const Text('Hủy Đăng Ký Phương Tiện'),
        content: Text(
          'Bạn có chắc chắn muốn hủy đăng ký ${vehicle.vehicleTypeName.toLowerCase()} có biển số ${vehicle.plateNumber} không?\n\nSau khi hủy, thẻ xe tương ứng sẽ bị khóa hiệu lực.',
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
                await ref.read(vehicleRepositoryProvider).deleteVehicle(vehicle.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã hủy đăng ký phương tiện thành công.'),
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
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aptIdAsync = ref.watch(residentApartmentIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phương Tiện Căn Hộ'),
      ),
      body: aptIdAsync.when(
        data: (apartmentId) {
          if (apartmentId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_work_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa Liên Kết Căn Hộ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bạn cần được Ban Quản Lý phê duyệt liên kết căn hộ trước khi thực hiện đăng ký phương tiện.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          final vehiclesAsync = ref.watch(apartmentVehiclesProvider(apartmentId));

          return vehiclesAsync.when(
            data: (vehicles) {
              final motorbikeCount = vehicles.where((v) => v.isMotorbike).length;
              final carCount = vehicles.where((v) => v.isCar).length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Thẻ thông tin hạn mức & quy chế
                  Card(
                    elevation: 0,
                    color: Colors.white,
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.local_parking, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Hạn Mức Đăng Ký Căn Hộ',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
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
                                          const Text(
                                            'Xe máy',
                                            style: TextStyle(fontSize: 13, color: Colors.grey),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: motorbikeCount >= 2
                                                  ? AppTheme.warning.withValues(alpha: 0.15)
                                                  : AppStatusColors.paid.withValues(alpha: 0.15),
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
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        '100.000 đ/tháng/xe',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
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
                                          const Text(
                                            'Ô tô',
                                            style: TextStyle(fontSize: 13, color: Colors.grey),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        '1.200.000 đ/tháng/xe',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Phí gửi xe sẽ được tự động kết xuất vào hóa đơn dịch vụ hàng tháng của căn hộ.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Danh Sách Xe Đã Đăng Ký (${vehicles.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Đăng ký mới'),
                        onPressed: () => _showAddVehicleDialog(
                          context,
                          apartmentId: apartmentId,
                          currentMotorbikes: motorbikeCount,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (vehicles.isEmpty) ...[
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        child: Column(
                          children: [
                            Icon(Icons.no_crash_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'Căn hộ chưa đăng ký phương tiện nào',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Bấm "Đăng ký mới" để thêm xe máy hoặc ô tô vào danh sách căn hộ.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ...vehicles.map((vehicle) {
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: vehicle.isMotorbike
                                      ? Colors.orange.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  vehicle.isMotorbike
                                      ? Icons.two_wheeler_outlined
                                      : Icons.directions_car_outlined,
                                  color: vehicle.isMotorbike
                                      ? Colors.orange.shade700
                                      : AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            border: Border.all(color: Colors.grey.shade400),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            vehicle.plateNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          vehicle.vehicleTypeName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ngày tạo: ${_dateFormat.format(vehicle.createdAt)}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                tooltip: 'Hủy đăng ký xe',
                                onPressed: () => _confirmDeleteVehicle(context, vehicle),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải danh sách xe: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải thông tin căn hộ: $e')),
      ),
    );
  }
}
