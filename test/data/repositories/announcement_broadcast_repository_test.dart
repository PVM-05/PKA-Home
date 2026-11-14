import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/guard_helper.dart';
import 'package:pka_home/data/repositories/announcement_repository.dart';

void main() {
  group('AnnouncementRepository Broadcast Engine Tests (Fail-Closed)', () {
    late AnnouncementRepository repository;

    setUp(() {
      repository = AnnouncementRepository();
    });

    test('createAnnouncement ném AppException khi không có client Supabase', () async {
      expect(
        () => repository.createAnnouncement(
          title: 'Bảo trì thang máy',
          content: 'Thang máy tạm dừng hoạt động từ 13:00 - 15:00',
          isUrgent: true,
          category: 'elevator_maintenance',
          eventStartAt: DateTime.now(),
          eventEndAt: DateTime.now().add(const Duration(hours: 2)),
          isPinned: true,
          hotlineContact: '0901234567',
          autoBroadcast: true,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('broadcastAnnouncement ném AppException khi không có client Supabase', () async {
      expect(
        () => repository.broadcastAnnouncement('test-announcement-id'),
        throwsA(isA<AppException>()),
      );
    });

    test('markAnnouncementAsRead ném AppException khi không có client Supabase', () async {
      expect(
        () => repository.markAnnouncementAsRead('test-announcement-id', 'user-1'),
        throwsA(isA<AppException>()),
      );
    });
  });
}

