import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../data/models/parking_slot_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/providers/parking_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../widgets/vehicle/resident_vehicle_card.dart';
import '../widgets/vehicle/vehicle_form_sheets.dart';
import '../widgets/vehicle/vehicle_quota_and_guideline_cards.dart';

class VehicleManagementScreen extends ConsumerStatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  ConsumerState<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState
    extends ConsumerState<VehicleManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final aptIdAsync = ref.watch(residentApartmentIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Phương Tiện Căn Hộ')),
      body: aptIdAsync.when(
        data: (apartmentId) {
          if (apartmentId == null) {
            return const Center(
              child: Padding(
                padding: AppSpacing.p24,
                child: AppEmptyState(
                  icon: Icons.home_work_outlined,
                  title: 'Chưa Liên Kết Căn Hộ',
                  description:
                      'Bạn cần được Ban Quản Lý phê duyệt liên kết căn hộ trước khi thực hiện đăng ký phương tiện.',
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
                          padding: AppSpacing.p24,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      VehicleQuotaCard(
                                        motorbikeCount: motorbikeCount,
                                        carCount: carCount,
                                      ),
                                      AppSpacing.h16,
                                      const VehicleGuidelineCard(),
                                    ],
                                  ),
                                ),
                              ),
                              AppSpacing.w24,
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
                                    AppSpacing.h12,
                                    Expanded(
                                      child: vehicles.isEmpty
                                          ? const VehicleEmptyCard()
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
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.p16,
                          children: [
                            VehicleQuotaCard(
                              motorbikeCount: motorbikeCount,
                              carCount: carCount,
                            ),
                            AppSpacing.h20,
                            _buildHeaderRow(
                              context,
                              vehicles.length,
                              apartmentId,
                              motorbikeCount,
                            ),
                            AppSpacing.h8,
                            if (vehicles.isEmpty)
                              const VehicleEmptyCard()
                            else
                              ...vehicles.map(
                                (vehicle) => _buildVehicleItem(
                                  context,
                                  vehicle,
                                  allSlots,
                                  motorbikeCount,
                                  apartmentId,
                                ),
                              ),
                            AppSpacing.h16,
                            const VehicleGuidelineCard(),
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
            loading: () => ListView(
              padding: AppSpacing.p16,
              children: [
                AppSkeletonShimmer.cardList(count: 3, itemHeight: 120),
              ],
            ),
            error: (e, _) => Center(
              child: AppErrorCard(
                error: e,
                onRetry: () =>
                    ref.invalidate(apartmentVehiclesProvider(apartmentId)),
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 120),
          ],
        ),
        error: (e, _) => Center(
          child: AppErrorCard(
            error: e,
            onRetry: () => ref.invalidate(residentApartmentIdProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    int totalCount,
    String apartmentId,
    int motorbikeCount,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Danh Sách Xe Đã Đăng Ký ($totalCount)',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
          ),
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text('Đăng ký mới'),
          onPressed: () => showAddVehicleSheet(
            context: context,
            ref: ref,
            apartmentId: apartmentId,
            currentMotorbikes: motorbikeCount,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleItem(
    BuildContext context,
    VehicleModel vehicle,
    List<ParkingSlotModel> allSlots,
    int motorbikeCount,
    String apartmentId,
  ) {
    return ResidentVehicleCard(
      vehicle: vehicle,
      allSlots: allSlots,
      motorbikeCount: motorbikeCount,
      apartmentId: apartmentId,
      onEdit: () => showEditVehicleSheet(
        context: context,
        ref: ref,
        vehicle: vehicle,
        currentMotorbikes: motorbikeCount,
      ),
      onDelete: () => showConfirmDeleteVehicleDialog(
        context: context,
        ref: ref,
        vehicle: vehicle,
      ),
      onPhotoView: vehicle.hasRegistrationImage
          ? () {
              final rawUrl = vehicle.registrationImageUrl?.trim() ?? '';
              if (rawUrl.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoViewerScreen(
                      imageUrls: [rawUrl],
                      defaultBucket: 'vehicle-docs',
                    ),
                  ),
                );
              }
            }
          : null,
    );
  }
}
