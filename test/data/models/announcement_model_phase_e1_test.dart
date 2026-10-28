import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/announcement_model.dart';

void main() {
  group('AnnouncementModel Phase E1 Tests', () {
    test('targetDisplayName hiển thị đúng theo targetType và targetValue linh hoạt', () {
      final annBlock = AnnouncementModel(
        id: '1',
        title: 'Mất nước',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'block',
        targetValue: 'B',
        createdAt: DateTime.now(),
      );
      expect(annBlock.targetDisplayName, equals('Block B'));

      final annFloor = AnnouncementModel(
        id: '2',
        title: 'Sơn hành lang',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'floor',
        targetValue: '08',
        createdAt: DateTime.now(),
      );
      expect(annFloor.targetDisplayName, equals('Tầng 08'));

      final annApt = AnnouncementModel(
        id: '3',
        title: 'Kiểm tra gas',
        content: 'Nội dung',
        isUrgent: true,
        targetType: 'apartment',
        targetValue: 'A0110',
        createdAt: DateTime.now(),
      );
      expect(annApt.targetDisplayName, equals('Căn hộ A0110'));

      final annAll = AnnouncementModel(
        id: '4',
        title: 'Họp cư dân',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'all',
        createdAt: DateTime.now(),
      );
      expect(annAll.targetDisplayName, equals('Tất cả cư dân'));
    });

    test('Tương thích ngược với targetApartment và block_a, block_b cũ', () {
      final legacy = AnnouncementModel.fromJson({
        'id': 'legacy-1',
        'title': 'Test cũ',
        'content': 'Test',
        'is_urgent': false,
        'target_type': 'block_a',
        'created_at': '2026-10-28T00:00:00.000Z',
      });
      expect(legacy.targetDisplayName, equals('Tòa A'));
    });
  });
}
