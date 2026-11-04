import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/sync/offline_sync_manager.dart';
import 'package:pka_home/core/sync/sync_providers.dart';
import 'package:pka_home/core/widgets/sync_status_bar.dart';

void main() {
  group('SyncStatusBar Widget Tests', () {
    testWidgets('Ẩn thanh trạng thái khi online và không có tác vụ nào chờ', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSyncStateProvider.overrideWith((ref) => const SyncState(
                  isOnline: true,
                  isSyncing: false,
                  pendingCount: 0,
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SyncStatusBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
      expect(find.textContaining('Đang làm việc ngoại tuyến'), findsNothing);
      expect(find.textContaining('Đang đồng bộ'), findsNothing);
    });

    testWidgets('Hiển thị cảnh báo ngoại tuyến kèm số tác vụ chờ và nút Đồng bộ ngay', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSyncStateProvider.overrideWith((ref) => const SyncState(
                  isOnline: false,
                  isSyncing: false,
                  pendingCount: 3,
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SyncStatusBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('Đang làm việc ngoại tuyến (Offline) • 3 tác vụ chờ gửi'), findsOneWidget);
      expect(find.text('Đồng bộ ngay'), findsOneWidget);
    });

    testWidgets('Hiển thị trạng thái đang đồng bộ kèm spinner khi isSyncing = true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSyncStateProvider.overrideWith((ref) => const SyncState(
                  isOnline: true,
                  isSyncing: true,
                  pendingCount: 2,
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SyncStatusBar(),
            ),
          ),
        ),
      );

      // Dùng pump thay vì pumpAndSettle vì có CircularProgressIndicator hoạt ảnh liên tục
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Đang đồng bộ 2 tác vụ lên máy chủ...'), findsOneWidget);
    });
  });
}
