import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/announcement_model.dart';

void main() {
  group('AnnouncementModel Unit Tests', () {
    test('fromJson and toJson with targetType and targetApartment', () {
      final json = {
        'id': 'ann-123',
        'title': 'Thông báo cắt điện',
        'content': 'Cắt điện sửa chữa ngày 26/10',
        'is_urgent': true,
        'target_type': 'apartment',
        'target_apartment': 'A0110',
        'created_at': '2026-10-25T12:00:00.000Z',
      };

      final model = AnnouncementModel.fromJson(json);

      expect(model.id, 'ann-123');
      expect(model.title, 'Thông báo cắt điện');
      expect(model.content, 'Cắt điện sửa chữa ngày 26/10');
      expect(model.isUrgent, isTrue);
      expect(model.targetType, 'apartment');
      expect(model.targetApartment, 'A0110');
      expect(model.targetDisplayName, 'Căn hộ A0110');

      final serialized = model.toJson();
      expect(serialized['id'], 'ann-123');
      expect(serialized['title'], 'Thông báo cắt điện');
      expect(serialized['content'], 'Cắt điện sửa chữa ngày 26/10');
      expect(serialized['is_urgent'], isTrue);
      expect(serialized['target_type'], 'apartment');
      expect(serialized['target_apartment'], 'A0110');
    });

    test('targetDisplayName for different target types', () {
      final allModel = AnnouncementModel(
        id: '1',
        title: 'Chung',
        content: 'Chung',
        isUrgent: false,
        targetType: 'all',
        createdAt: DateTime.now(),
      );
      expect(allModel.targetDisplayName, 'Tất cả cư dân');

      final blockAModel = AnnouncementModel(
        id: '2',
        title: 'Tòa A',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'block_a',
        createdAt: DateTime.now(),
      );
      expect(blockAModel.targetDisplayName, 'Tòa A');

      final blockBModel = AnnouncementModel(
        id: '3',
        title: 'Tòa B',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'block_b',
        createdAt: DateTime.now(),
      );
      expect(blockBModel.targetDisplayName, 'Tòa B');

      final aptModel = AnnouncementModel(
        id: '4',
        title: 'Căn hộ',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'apartment',
        targetApartment: 'B0205',
        createdAt: DateTime.now(),
      );
      expect(aptModel.targetDisplayName, 'Căn hộ B0205');
    });

    test('fromJson fallback to default "all" and null targetApartment', () {
      final json = {
        'id': 'ann-456',
        'title': 'Thông báo chung',
        'content': 'Nội dung chung',
        'is_urgent': false,
        'created_at': '2026-10-25T12:00:00.000Z',
      };

      final model = AnnouncementModel.fromJson(json);
      expect(model.targetType, 'all');
      expect(model.targetApartment, isNull);
      expect(model.targetDisplayName, 'Tất cả cư dân');

      final serialized = model.toJson();
      expect(serialized.containsKey('target_apartment'), isFalse);
    });
  });
}
