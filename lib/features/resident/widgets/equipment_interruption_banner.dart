import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/equipment_maintenance_task_model.dart';
import '../../../data/providers/equipment_provider.dart';
import '../../../data/providers/resident_apartment_provider.dart';

/// Banner cảnh báo cư dân khi có thiết bị tại tòa nhà đang được bảo trì
/// và gây gián đoạn dịch vụ (ví dụ: bảo dưỡng thang máy, bảo trì máy bơm nước).
class EquipmentInterruptionBanner extends ConsumerWidget {
  /// Cho phép chỉ định tòa nhà cụ thể (ưu tiên dùng khi test hoặc hiển thị ngữ cảnh riêng)
  final String? building;

  const EquipmentInterruptionBanner({super.key, this.building});

  String _resolveBuilding(Map<String, dynamic>? currentApt) {
    if (building != null && building!.trim().isNotEmpty) {
      return building!.trim();
    }
    if (currentApt == null) return 'Toàn khu';
    final aptsData = currentApt['apartments'] as Map<String, dynamic>?;
    final rawBuilding = aptsData?['building_code'] as String?;
    if (rawBuilding != null && rawBuilding.trim().isNotEmpty) {
      final trimmed = rawBuilding.trim();
      return trimmed.startsWith('Tòa ') ? trimmed : 'Tòa $trimmed';
    }
    final code = aptsData?['code'] as String? ?? '';
    if (code.isNotEmpty) {
      return 'Tòa ${code.substring(0, 1).toUpperCase()}';
    }
    return 'Toàn khu';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentApt = ref.watch(currentSelectedApartmentProvider);
    final targetBuilding = _resolveBuilding(currentApt);

    final interruptionsAsync = ref.watch(activeServiceInterruptionsProvider(targetBuilding));

    return interruptionsAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildAlertCard(context, tasks, targetBuilding);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    List<EquipmentMaintenanceTaskModel> tasks,
    String buildingName,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Amber 50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1.2), // Amber 300
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header cảnh báo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE082),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD84315),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bảo trì thiết bị - Tạm gián đoạn dịch vụ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB71C1C),
                      ),
                    ),
                    Text(
                      'Khu vực: $buildingName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
              ),
              if (tasks.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCC80),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length} thiết bị',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFFFCC80)),
          const SizedBox(height: 10),

          // Danh sách các thiết bị đang bảo trì
          ...tasks.map((task) {
            final eqTitle = task.equipmentName ?? task.equipmentCode ?? 'Thiết bị';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.build_circle_outlined,
                      size: 16,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$eqTitle: ${task.title}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF263238),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: Color(0xFF78909C),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Thời gian: ${dateFormat.format(task.scheduledStart)} - ${dateFormat.format(task.scheduledEnd)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF546E7A),
                              ),
                            ),
                          ],
                        ),
                        if ((task.serviceInterruptionNote != null &&
                                task.serviceInterruptionNote!.trim().isNotEmpty) ||
                            (task.notes != null && task.notes!.trim().isNotEmpty)) ...[
                          const SizedBox(height: 2),
                          Text(
                            (task.serviceInterruptionNote?.trim().isNotEmpty == true
                                    ? task.serviceInterruptionNote
                                    : task.notes)!
                                .trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF455A64),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
