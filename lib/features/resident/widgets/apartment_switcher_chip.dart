import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_glass.dart';
import '../../../data/providers/resident_apartment_provider.dart';

/// Widget chọn căn hộ (Apartment Switcher) hiển thị trên header trang chủ cư dân.
class ApartmentSwitcherChip extends ConsumerWidget {
  const ApartmentSwitcherChip({super.key});

  void _showApartmentSelectionSheet(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> apartments,
    String? currentSelectedId,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chọn căn hộ quản lý',
                        style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push(AppRoutes.residentLinkRequest);
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Thêm căn hộ', style: context.labelMedium),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: apartments.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final aptData = apartments[index];
                      final apt = aptData['apartments'] as Map<String, dynamic>?;
                      final aptId = aptData['apartment_id'] as String? ?? apt?['id'] as String? ?? '';
                      final code = apt?['code'] as String? ?? 'N/A';
                      final area = apt?['area'];
                      final role = aptData['relation_role'] == 'owner' ? 'Chủ hộ' : 'Người thuê';
                      final isSelected = (aptId == currentSelectedId) ||
                          (currentSelectedId == null && index == 0);

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.apartment,
                            color: isSelected ? AppTheme.primary : Colors.grey.shade600,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          'Căn hộ $code',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppTheme.primary : null,
                          ),
                        ),
                        subtitle: Text(
                          '$role ${area != null ? "• ${area}m²" : ""}',
                          style: context.labelSmall,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppTheme.primary)
                            : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        onTap: () {
                          ref
                              .read(selectedApartmentIdProvider.notifier)
                              .selectApartment(aptId);
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartmentsAsync = ref.watch(residentApartmentsProvider);
    final selectedApt = ref.watch(currentSelectedApartmentProvider);
    final selectedId = ref.watch(selectedApartmentIdProvider);

    return apartmentsAsync.when(
      data: (apartments) {
        if (apartments.isEmpty) {
          // Chưa liên kết căn hộ
          return GestureDetector(
            onTap: () => context.push(AppRoutes.residentLinkRequest),
            child: AppGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              borderRadius: AppRadius.rFull,
              opacity: 0.2,
              blur: 8.0,
              borderColor: Colors.white.withValues(alpha: 0.3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_link, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Liên kết căn hộ',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: context.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final aptInfo = selectedApt?['apartments'] as Map<String, dynamic>?;
        final code = aptInfo?['code'] ?? 'Căn hộ';
        final hasMultiple = apartments.length > 1;

        return GestureDetector(
          onTap: () => _showApartmentSelectionSheet(
            context,
            ref,
            apartments,
            selectedId,
          ),
          child: AppGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            borderRadius: AppRadius.rFull,
            opacity: 0.2,
            blur: 8.0,
            borderColor: Colors.white.withValues(alpha: 0.35),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$code',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: context.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasMultiple) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => AppGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        borderRadius: AppRadius.rFull,
        opacity: 0.15,
        blur: 8.0,
        borderColor: Colors.white.withValues(alpha: 0.2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Đang tải...',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: context.labelMedium?.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
