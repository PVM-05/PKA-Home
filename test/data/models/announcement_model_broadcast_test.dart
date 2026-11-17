import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/announcement_model.dart';

void main() {
  group('AnnouncementModel Broadcast Enhancements Tests', () {
    test('serialization and deserialization with broadcast fields works correctly', () {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 1));
      final end = now.add(const Duration(hours: 2));

      final model = AnnouncementModel(
        id: 'ann-1',
        title: 'Bảo trì thang máy Tháp A',
        content: 'Thang máy số 2 tạm ngưng bảo trì định kỳ từ 09:00 đến 12:00.',
        isUrgent: true,
        targetType: 'block',
        targetValue: 'A',
        category: 'elevator_maintenance',
        eventStartAt: start,
        eventEndAt: end,
        isPinned: true,
        broadcastCount: 150,
        readCount: 120,
        hotlineContact: '0909123456',
        createdAt: now,
      );

      final json = model.toJson();
      expect(json['category'], 'elevator_maintenance');
      expect(json['is_pinned'], isTrue);
      expect(json['broadcast_count'], 150);
      expect(json['read_count'], 120);
      expect(json['hotline_contact'], '0909123456');

      final fromJson = AnnouncementModel.fromJson(json);
      expect(fromJson.id, 'ann-1');
      expect(fromJson.category, 'elevator_maintenance');
      expect(fromJson.categoryDisplayName, 'Bảo trì thang máy');
      expect(fromJson.isPinned, isTrue);
      expect(fromJson.broadcastCount, 150);
      expect(fromJson.readCount, 120);
      expect(fromJson.readRatio, closeTo(0.8, 0.001));
      expect(fromJson.readRatioPercentageText, '80.0%');
      expect(fromJson.hotlineContact, '0909123456');
    });

    test('categoryDisplayName returns accurate Vietnamese strings for all categories', () {
      expect(AnnouncementModel(id: '1', title: '', content: '', isUrgent: false, category: 'emergency', createdAt: DateTime.now()).categoryDisplayName, 'Khẩn cấp');
      expect(AnnouncementModel(id: '2', title: '', content: '', isUrgent: false, category: 'elevator_maintenance', createdAt: DateTime.now()).categoryDisplayName, 'Bảo trì thang máy');
      expect(AnnouncementModel(id: '3', title: '', content: '', isUrgent: false, category: 'utility_outage', createdAt: DateTime.now()).categoryDisplayName, 'Cúp điện / nước');
      expect(AnnouncementModel(id: '4', title: '', content: '', isUrgent: false, category: 'resident_meeting', createdAt: DateTime.now()).categoryDisplayName, 'Họp cư dân');
      expect(AnnouncementModel(id: '5', title: '', content: '', isUrgent: false, category: 'general', createdAt: DateTime.now()).categoryDisplayName, 'Thông báo chung');
    });

    test('isOngoing identifies active time windows accurately', () {
      final now = DateTime.now();

      // Sự kiện đang diễn ra
      final ongoingModel = AnnouncementModel(
        id: '1',
        title: '',
        content: '',
        isUrgent: false,
        eventStartAt: now.subtract(const Duration(minutes: 30)),
        eventEndAt: now.add(const Duration(minutes: 30)),
        createdAt: now,
      );
      expect(ongoingModel.isOngoing, isTrue);

      // Sự kiện trong tương lai
      final futureModel = AnnouncementModel(
        id: '2',
        title: '',
        content: '',
        isUrgent: false,
        eventStartAt: now.add(const Duration(hours: 1)),
        eventEndAt: now.add(const Duration(hours: 2)),
        createdAt: now,
      );
      expect(futureModel.isOngoing, isFalse);

      // Sự kiện trong quá khứ
      final pastModel = AnnouncementModel(
        id: '3',
        title: '',
        content: '',
        isUrgent: false,
        eventStartAt: now.subtract(const Duration(hours: 2)),
        eventEndAt: now.subtract(const Duration(hours: 1)),
        createdAt: now,
      );
      expect(pastModel.isOngoing, isFalse);
    });
  });
}

