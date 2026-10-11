import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/announcement_model.dart';
import 'package:pka_home/data/providers/announcement_provider.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';

void main() {
  group('Resident Announcements Filtering Tests', () {
    final sampleAnnouncements = [
      AnnouncementModel(
        id: 'ann-1',
        title: 'Thông báo chung toàn khu',
        content: 'Bảo trì hệ thống PCCC chung',
        isUrgent: false,
        targetType: 'all',
        createdAt: DateTime(2026, 10, 10),
      ),
      AnnouncementModel(
        id: 'ann-2',
        title: 'Thông báo riêng Tòa A',
        content: 'Bảo trì thang máy Tòa A',
        isUrgent: true,
        targetType: 'block_a',
        createdAt: DateTime(2026, 10, 11),
      ),
      AnnouncementModel(
        id: 'ann-3',
        title: 'Thông báo riêng Tòa B',
        content: 'Vệ sinh hành lang Tòa B',
        isUrgent: false,
        targetType: 'block_b',
        createdAt: DateTime(2026, 10, 11),
      ),
      AnnouncementModel(
        id: 'ann-4',
        title: 'Thông báo riêng Căn hộ A0110',
        content: 'Kiểm tra đường ống nước căn hộ A0110',
        isUrgent: true,
        targetType: 'apartment',
        targetApartment: 'A0110',
        createdAt: DateTime(2026, 10, 11),
      ),
      AnnouncementModel(
        id: 'ann-5',
        title: 'Thông báo riêng Căn hộ B0205',
        content: 'Kiểm tra kỹ thuật căn hộ B0205',
        isUrgent: false,
        targetType: 'apartment',
        targetApartment: 'B0205',
        createdAt: DateTime(2026, 10, 11),
      ),
    ];

    test('Cư dân Tòa A (Căn A0110) chỉ nhận được thông báo chung, thông báo Tòa A, và thông báo căn A0110', () async {
      final container = ProviderContainer(
        overrides: [
          announcementsStreamProvider.overrideWith((ref) => Stream.value(sampleAnnouncements)),
          residentApartmentsProvider.overrideWith((ref) async => [
                {
                  'apartment_id': 'apt-a0110',
                  'apartments': {
                    'id': 'apt-a0110',
                    'code': 'A0110',
                    'building_code': 'A',
                  }
                }
              ]),
        ],
      );
      addTearDown(container.dispose);

      // Đọc provider và chờ hoàn thành
      await container.read(residentApartmentsProvider.future);
      await container.read(announcementsStreamProvider.future);

      final filtered = container.read(residentAnnouncementsProvider).value ?? [];
      final titles = filtered.map((e) => e.title).toList();

      expect(titles, contains('Thông báo chung toàn khu'));
      expect(titles, contains('Thông báo riêng Tòa A'));
      expect(titles, contains('Thông báo riêng Căn hộ A0110'));

      // Tuyệt đối không nhận thông báo của Tòa B hoặc Căn B0205
      expect(titles, isNot(contains('Thông báo riêng Tòa B')));
      expect(titles, isNot(contains('Thông báo riêng Căn hộ B0205')));
    });

    test('Cư dân Tòa B (Căn B0205) chỉ nhận được thông báo chung, thông báo Tòa B, và thông báo căn B0205', () async {
      final container = ProviderContainer(
        overrides: [
          announcementsStreamProvider.overrideWith((ref) => Stream.value(sampleAnnouncements)),
          residentApartmentsProvider.overrideWith((ref) async => [
                {
                  'apartment_id': 'apt-b0205',
                  'apartments': {
                    'id': 'apt-b0205',
                    'code': 'B0205',
                    'building_code': 'B',
                  }
                }
              ]),
        ],
      );
      addTearDown(container.dispose);

      await container.read(residentApartmentsProvider.future);
      await container.read(announcementsStreamProvider.future);

      final filtered = container.read(residentAnnouncementsProvider).value ?? [];
      final titles = filtered.map((e) => e.title).toList();

      expect(titles, contains('Thông báo chung toàn khu'));
      expect(titles, contains('Thông báo riêng Tòa B'));
      expect(titles, contains('Thông báo riêng Căn hộ B0205'));

      expect(titles, isNot(contains('Thông báo riêng Tòa A')));
      expect(titles, isNot(contains('Thông báo riêng Căn hộ A0110')));
    });
  });
}
