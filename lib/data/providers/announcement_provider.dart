import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement_model.dart';
import '../repositories/announcement_repository.dart';
import 'building_provider.dart';
import 'resident_apartment_provider.dart';

final announcementsStreamProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  final repo = ref.watch(announcementRepositoryProvider);
  final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
  return repo.streamAnnouncements().map((list) {
    final sortedList = List<Map<String, dynamic>>.from(list);
    sortedList.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    final models = sortedList.map((e) => AnnouncementModel.fromJson(e)).toList();
    if (effectiveBuildingId == null || effectiveBuildingId.isEmpty) {
      return models;
    }
    final hasAnyBuilding = models.any((a) => a.buildingId != null && a.buildingId!.isNotEmpty);
    if (!hasAnyBuilding) return models;
    return models
        .where((a) => a.buildingId == null || a.buildingId == effectiveBuildingId)
        .toList();
  });
});

/// Provider danh sách thông báo đã được lọc phù hợp với quyền hạn và căn hộ của cư dân
final residentAnnouncementsProvider = Provider<AsyncValue<List<AnnouncementModel>>>((ref) {
  final announcementsAsync = ref.watch(announcementsStreamProvider);
  final aptsAsync = ref.watch(residentApartmentsProvider);
  final selectedApt = ref.watch(currentSelectedApartmentProvider);
  final residentBldId = ref.watch(residentBuildingIdProvider);

  return announcementsAsync.whenData((allAnnouncements) {
    final residentApts = aptsAsync.valueOrNull ?? [];
    
    // Thu thập danh sách mã căn hộ và tòa nhà của cư dân
    final userAptCodes = <String>{};
    final userBlocks = <String>{};

    for (final ra in residentApts) {
      final apt = ra['apartments'] as Map<String, dynamic>?;
      if (apt != null) {
        final code = (apt['code'] as String?)?.toUpperCase() ?? '';
        if (code.isNotEmpty) {
          userAptCodes.add(code);
          if (code.startsWith('A')) userBlocks.add('block_a');
          if (code.startsWith('B')) userBlocks.add('block_b');
        }
        final bCode = (apt['building_code'] as String?)?.toLowerCase() ?? '';
        if (bCode.isNotEmpty) {
          userBlocks.add('block_$bCode');
        }
      }
    }

    if (selectedApt != null) {
      final apt = selectedApt['apartments'] as Map<String, dynamic>?;
      if (apt != null) {
        final code = (apt['code'] as String?)?.toUpperCase() ?? '';
        if (code.isNotEmpty) {
          userAptCodes.add(code);
          if (code.startsWith('A')) userBlocks.add('block_a');
          if (code.startsWith('B')) userBlocks.add('block_b');
        }
      }
    }

    final hasBuildingScoped = allAnnouncements.any(
      (a) => a.buildingId != null && a.buildingId!.isNotEmpty,
    );

    return allAnnouncements.where((announcement) {
      if (hasBuildingScoped &&
          residentBldId != null &&
          residentBldId.isNotEmpty &&
          announcement.buildingId != null &&
          announcement.buildingId!.isNotEmpty &&
          announcement.buildingId != residentBldId) {
        return false;
      }

      // 1. Dành cho toàn bộ cư dân
      if (announcement.targetType == 'all') return true;

      // 2. Dành cho Block cụ thể
      if (userBlocks.contains(announcement.targetType)) return true;

      // 3. Dành riêng cho căn hộ cụ thể
      if (announcement.targetType == 'apartment') {
        final target = announcement.targetApartment?.toUpperCase().trim();
        if (target != null && userAptCodes.contains(target)) return true;
      }

      return false;
    }).toList();
  });
});

/// Provider lấy các thông báo khẩn cấp hoặc sự cố/bảo trì đang diễn ra dành cho cư dân
final activeEmergencyAnnouncementsProvider = Provider<List<AnnouncementModel>>((ref) {
  final announcementsAsync = ref.watch(residentAnnouncementsProvider);
  final announcements = announcementsAsync.valueOrNull ?? [];

  return announcements.where((a) {
    // 1. Được đánh dấu khẩn cấp
    if (a.isUrgent) return true;
    // 2. Thuộc danh mục khẩn cấp
    if (a.category == 'emergency') return true;
    // 3. Sự cố/bảo trì đang trong thời gian diễn ra
    if (a.isOngoing &&
        (a.category == 'elevator_maintenance' || a.category == 'utility_outage')) {
      return true;
    }
    return false;
  }).toList();
});


