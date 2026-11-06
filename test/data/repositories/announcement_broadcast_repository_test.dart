import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/announcement_repository.dart';

void main() {
  group('AnnouncementRepository Broadcast Engine Tests', () {
    late AnnouncementRepository repository;

    setUp(() {
      repository = AnnouncementRepository();
    });

    test('createAnnouncement with autoBroadcast succeeds in fallback mock environment', () async {
      final res = await repository.createAnnouncement(
        title: 'Bảo trì thang máy',
        content: 'Thang máy tạm dừng hoạt động từ 13:00 - 15:00',
        isUrgent: true,
        category: 'elevator_maintenance',
        eventStartAt: DateTime.now(),
        eventEndAt: DateTime.now().add(const Duration(hours: 2)),
        isPinned: true,
        hotlineContact: '0901234567',
        autoBroadcast: true,
      );

      expect(res['success'], isTrue);
      expect(res['id'], isNotEmpty);
    });

    test('broadcastAnnouncement calls RPC and returns recipient count in fallback mock', () async {
      final res = await repository.broadcastAnnouncement('test-announcement-id');
      expect(res['success'], isTrue);
      expect(res['broadcast_count'], isPositive);
    });

    test('markAnnouncementAsRead returns updated status in fallback mock', () async {
      final res = await repository.markAnnouncementAsRead('test-announcement-id', 'user-1');
      expect(res['success'], isTrue);
      expect(res['updated_count'], isPositive);
    });
  });
}

