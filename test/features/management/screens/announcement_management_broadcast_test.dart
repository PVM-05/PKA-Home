import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/announcement_model.dart';
import 'package:vivona/data/providers/announcement_provider.dart';
import 'package:vivona/data/providers/building_provider.dart';
import 'package:vivona/data/models/building_model.dart';
import 'package:vivona/features/management/screens/announcement_management_screen.dart';

void main() {
  final sampleAnnouncements = [
    AnnouncementModel(
      id: 'ann-1',
      title: 'Bảo trì thang máy Tháp A',
      content: 'Tạm ngưng thang máy số 1 để bảo trì cáp.',
      isUrgent: false,
      category: 'elevator_maintenance',
      eventStartAt: DateTime.now().subtract(const Duration(minutes: 10)),
      eventEndAt: DateTime.now().add(const Duration(hours: 2)),
      isPinned: true,
      broadcastCount: 100,
      readCount: 85,
      hotlineContact: '0901234567',
      createdAt: DateTime.now(),
    ),
    AnnouncementModel(
      id: 'ann-2',
      title: 'Cắt nước cục bộ để vệ sinh đường ống',
      content: 'Cắt nước từ 22:00 đến 05:00 sáng mai.',
      isUrgent: true,
      category: 'utility_outage',
      broadcastCount: 200,
      readCount: 150,
      createdAt: DateTime.now(),
    ),
  ];

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        announcementsStreamProvider.overrideWith(
          (ref) => Stream.value(sampleAnnouncements),
        ),
        activeBuildingProvider.overrideWith(
          (ref) async => BuildingModel(
            id: 'b1',
            organizationId: 'org1',
            name: 'Tòa Nhà PKA',
            code: 'PKA',
          ),
        ),
      ],
      child: const MaterialApp(
        home: AnnouncementManagementScreen(),
      ),
    );
  }

  group('AnnouncementManagementScreen Broadcast UI Tests', () {
    testWidgets('renders category badges, read ratios, and action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tiêu đề App bar
      expect(find.text('Quản lý Thông báo'), findsOneWidget);

      // Thẻ 1: Bảo trì thang máy
      expect(find.text('Bảo trì thang máy Tháp A'), findsOneWidget);
      expect(find.text('Bảo trì thang máy'), findsOneWidget);
      expect(find.text('Đã ghim'), findsOneWidget);
      expect(find.textContaining('Đang diễn ra'), findsOneWidget);
      expect(find.textContaining('Đã phát: 100 • Đã đọc: 85 (85.0%)'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);

      // Thẻ 2: Cắt nước
      expect(find.text('Cắt nước cục bộ để vệ sinh đường ống'), findsOneWidget);
      expect(find.text('Cúp điện / nước'), findsOneWidget);
      expect(find.textContaining('Đã phát: 200 • Đã đọc: 150 (75.0%)'), findsOneWidget);

      // Nút FAB mở dialog tạo thông báo
      expect(find.text('Phát thông báo'), findsOneWidget);
    });

    testWidgets('opens create dialog with category and live preview toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phát thông báo'));
      await tester.pumpAndSettle();

      expect(find.text('Tạo & Phát sóng Thông báo'), findsOneWidget);
      expect(find.text('Danh mục thông báo *'), findsOneWidget);
      expect(find.text('Xem trước'), findsOneWidget);

      // Chuyển sang chế độ xem trước (Live Preview)
      await tester.tap(find.text('Xem trước'));
      await tester.pumpAndSettle();

      expect(find.text('Mô phỏng hiển thị trên App Cư dân'), findsOneWidget);
      expect(find.text('Soạn thảo'), findsOneWidget);
    });
  });
}
