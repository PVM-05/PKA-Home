import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement_model.dart';
import '../repositories/announcement_repository.dart';
import 'resident_apartment_provider.dart';

final announcementsStreamProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  final repo = ref.watch(announcementRepositoryProvider);
  return repo.streamAnnouncements().map((list) {
    final sortedList = List<Map<String, dynamic>>.from(list);
    sortedList.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    return sortedList.map((e) => AnnouncementModel.fromJson(e)).toList();
  });
});

/// Provider danh sách thông báo đã được lọc phù hợp với quyền hạn và căn hộ của cư dân
final residentAnnouncementsProvider = Provider<AsyncValue<List<AnnouncementModel>>>((ref) {
  final announcementsAsync = ref.watch(announcementsStreamProvider);
  final aptsAsync = ref.watch(residentApartmentsProvider);
  final selectedApt = ref.watch(currentSelectedApartmentProvider);

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

    return allAnnouncements.where((announcement) {
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

