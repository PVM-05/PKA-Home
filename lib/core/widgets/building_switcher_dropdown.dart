import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/building_provider.dart';
import '../../data/providers/management_provider.dart';
import '../theme/app_theme.dart';

class BuildingSwitcherDropdown extends ConsumerWidget {
  const BuildingSwitcherDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingsAsync = ref.watch(userBuildingsProvider);
    final activeBuildingId = ref.watch(activeBuildingIdProvider);

    return buildingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (buildings) {
        if (buildings.isEmpty) return const SizedBox.shrink();

        final activeBuilding = buildings.firstWhere(
          (b) => b.id == activeBuildingId,
          orElse: () => buildings.first,
        );

        // Nếu chỉ có 1 tòa nhà, hiển thị huy hiệu tĩnh
        if (buildings.length == 1) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  activeBuilding.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          );
        }

        // Nếu có nhiều tòa nhà, hiển thị Dropdown chuyển đổi
        return PopupMenuButton<String>(
          tooltip: 'Chuyển đổi tòa nhà',
          initialValue: activeBuilding.id,
          onSelected: (newBuildingId) {
            if (newBuildingId != activeBuildingId) {
              ref.read(activeBuildingIdProvider.notifier).setBuildingId(newBuildingId);
              // Làm mới danh sách dữ liệu theo tòa nhà mới
              ref.invalidate(apartmentsProvider);
              ref.invalidate(invoicesProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã chuyển sang quản lý: ${buildings.firstWhere((b) => b.id == newBuildingId).name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    activeBuilding.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.primary),
              ],
            ),
          ),
          itemBuilder: (context) {
            return buildings.map((b) {
              final isSelected = b.id == activeBuildingId;
              return PopupMenuItem<String>(
                value: b.id,
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isSelected ? AppTheme.primary : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primary : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}
