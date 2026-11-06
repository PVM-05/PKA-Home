import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/announcement_model.dart';
import 'package:pka_home/data/providers/announcement_provider.dart';
import 'package:pka_home/features/resident/widgets/sticky_emergency_bar.dart';

void main() {
  group('StickyEmergencyBar Widget Tests', () {
    testWidgets('renders nothing when activeEmergencyAnnouncementsProvider is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEmergencyAnnouncementsProvider.overrideWithValue([]),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StickyEmergencyBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders emergency banner with title, category and detail button when emergency exists', (tester) async {
      final now = DateTime.now();
      final emergency = AnnouncementModel(
        id: 'em-1',
        title: 'Bảo trì thang máy Tháp B khẩn cấp',
        content: 'Vui lòng sử dụng thang bộ hoặc thang máy Tháp A.',
        isUrgent: true,
        category: 'elevator_maintenance',
        eventStartAt: now.subtract(const Duration(minutes: 5)),
        eventEndAt: now.add(const Duration(hours: 1)),
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEmergencyAnnouncementsProvider.overrideWithValue([emergency]),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StickyEmergencyBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BẢO TRÌ THANG MÁY'), findsOneWidget);
      expect(find.textContaining('Bảo trì thang máy Tháp B khẩn cấp'), findsOneWidget);
      expect(find.text('Đang diễn ra'), findsOneWidget);
      expect(find.text('Chi tiết'), findsOneWidget);
    });
  });
}

