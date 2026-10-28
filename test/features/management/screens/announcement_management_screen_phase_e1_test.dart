import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/announcement_model.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/providers/announcement_provider.dart';
import 'package:pka_home/data/providers/building_provider.dart';
import 'package:pka_home/features/management/screens/announcement_management_screen.dart';

void main() {
  group('AnnouncementManagementScreen Phase E1 Tests', () {
    final sampleAnnouncements = [
      AnnouncementModel(
        id: 'ann-1',
        title: 'Thông báo sửa chữa',
        content: 'Bảo trì thang máy',
        isUrgent: true,
        targetType: 'block',
        targetValue: 'A',
        createdAt: DateTime.now(),
      ),
    ];

    final sampleBuilding = BuildingModel(
      id: 'bld-test-1',
      organizationId: 'org-1',
      name: 'PKA Tower 1',
      code: 'PKAT1',
    );

    testWidgets('Hiển thị nút Quét nhắc nợ hóa đơn trên AppBar và danh sách thông báo', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            announcementsStreamProvider.overrideWith((ref) => Stream.value(sampleAnnouncements)),
            activeBuildingProvider.overrideWith((ref) => Future.value(sampleBuilding)),
          ],
          child: const MaterialApp(
            home: AnnouncementManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề và nút Quét nhắc nợ
      expect(find.text('Quản lý Thông báo'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_send_outlined), findsOneWidget);
      expect(find.text('Thông báo sửa chữa'), findsOneWidget);
      expect(find.text('Block A'), findsOneWidget);
    });
  });
}
