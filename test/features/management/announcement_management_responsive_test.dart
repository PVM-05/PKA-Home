import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/announcement_model.dart';
import 'package:pka_home/data/providers/announcement_provider.dart';
import 'package:pka_home/data/repositories/announcement_repository.dart';
import 'package:pka_home/features/management/screens/announcement_management_screen.dart';

class _MockAnnouncementRepository implements AnnouncementRepository {
  @override
  Stream<List<Map<String, dynamic>>> streamAnnouncements() => const Stream.empty();

  @override
  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetValue,
    String? targetApartment,
    String category = 'general',
    DateTime? eventStartAt,
    DateTime? eventEndAt,
    bool isPinned = false,
    String? hotlineContact,
    bool autoBroadcast = true,
  }) async => {'id': 'mock-id'};

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetValue,
    String? targetApartment,
    String category = 'general',
    DateTime? eventStartAt,
    DateTime? eventEndAt,
    bool isPinned = false,
    String? hotlineContact,
  }) async {}

  @override
  Future<void> deleteAnnouncement(String id) async {}

  @override
  Future<Map<String, dynamic>> broadcastAnnouncement(String announcementId) async =>
      {'broadcast_count': 10};

  @override
  Future<Map<String, dynamic>> markAnnouncementAsRead(String id, String userId) async =>
      {'success': true};
}

void main() {
  final now = DateTime.now();

  final mockAnnouncements = <AnnouncementModel>[
    AnnouncementModel(
      id: 'ann-01',
      title: 'Bảo trì hệ thống phòng cháy chữa cháy toàn bộ tòa nhà',
      content: 'Kính gửi cư dân, ban quản lý tiến hành kiểm tra chuông báo cháy định kỳ.',
      isUrgent: true,
      isPinned: true,
      category: 'emergency',
      targetType: 'all',
      readCount: 45,
      broadcastCount: 50,
      createdAt: now.subtract(const Duration(hours: 2)),
      eventStartAt: now.add(const Duration(days: 1)),
      eventEndAt: now.add(const Duration(days: 1, hours: 4)),
      hotlineContact: '0912345678',
    ),
    AnnouncementModel(
      id: 'ann-02',
      title: 'Vệ sinh định kỳ hồ bơi và khu vực tiện ích tầng 3',
      content: 'Tạm ngưng phục vụ hồ bơi từ 8h00 đến 12h00 sáng mai.',
      isUrgent: false,
      isPinned: false,
      category: 'general',
      targetType: 'all',
      readCount: 20,
      broadcastCount: 50,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];

  Widget createWidget() {
    return ProviderScope(
      overrides: [
        announcementRepositoryProvider.overrideWithValue(_MockAnnouncementRepository()),
        announcementsStreamProvider.overrideWith(
          (ref) => Stream.value(mockAnnouncements),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AnnouncementManagementScreen(),
      ),
    );
  }

  group('AnnouncementManagementScreen Responsive & Impeccable Tests', () {
    testWidgets('renders desktop workstation grid at 1200dp width cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Quản lý Thông báo'), findsOneWidget);
      expect(find.text('Bảo trì hệ thống phòng cháy chữa cháy toàn bộ tòa nhà'), findsOneWidget);
      expect(find.text('Vệ sinh định kỳ hồ bơi và khu vực tiện ích tầng 3'), findsOneWidget);
      expect(find.text('Phát thông báo'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Quản lý Thông báo'), findsOneWidget);
      expect(find.textContaining('Bảo trì hệ thống phòng cháy'), findsOneWidget);
    });
  });
}
