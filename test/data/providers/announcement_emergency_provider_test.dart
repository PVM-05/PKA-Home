import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/announcement_model.dart';
import 'package:pka_home/data/providers/announcement_provider.dart';

void main() {
  group('activeEmergencyAnnouncementsProvider Tests', () {
    test('filters announcements that are urgent or ongoing maintenance', () {
      final now = DateTime.now();

      final list = [
        // 1. Khẩn cấp (urgent = true) -> Phải lọt vào
        AnnouncementModel(
          id: '1',
          title: 'Khẩn cấp báo động diễn tập PCCC',
          content: 'Toàn bộ cư dân chú ý lắng nghe loa thông báo.',
          isUrgent: true,
          category: 'general',
          createdAt: now,
        ),
        // 2. Bảo trì thang máy ĐANG DIỄN RA -> Phải lọt vào
        AnnouncementModel(
          id: '2',
          title: 'Bảo trì thang máy Tháp A',
          content: 'Đang tạm dừng',
          isUrgent: false,
          category: 'elevator_maintenance',
          eventStartAt: now.subtract(const Duration(minutes: 15)),
          eventEndAt: now.add(const Duration(minutes: 45)),
          createdAt: now,
        ),
        // 3. Thông báo chung bình thường -> KHÔNG lọt vào
        AnnouncementModel(
          id: '3',
          title: 'Lịch thu gom rác tết',
          content: 'Quy chế thu gom rác',
          isUrgent: false,
          category: 'general',
          createdAt: now,
        ),
        // 4. Bảo trì trong tương lai -> KHÔNG lọt vào
        AnnouncementModel(
          id: '4',
          title: 'Bảo trì tuần sau',
          content: 'Tuần sau mới làm',
          isUrgent: false,
          category: 'elevator_maintenance',
          eventStartAt: now.add(const Duration(days: 2)),
          eventEndAt: now.add(const Duration(days: 2, hours: 2)),
          createdAt: now,
        ),
      ];

      // Verify activeEmergencyAnnouncementsProvider
      final testContainer = ProviderContainer(
        overrides: [
          residentAnnouncementsProvider.overrideWithValue(AsyncValue.data(list)),
        ],
      );

      final emergencies = testContainer.read(activeEmergencyAnnouncementsProvider);
      expect(emergencies.length, 2);
      expect(emergencies.map((e) => e.id), containsAll(['1', '2']));
    });
  });
}
