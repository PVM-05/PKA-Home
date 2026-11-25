import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sync/sync_providers.dart';
import '../theme/app_theme.dart';

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(syncStateProvider);
    final fallbackState = ref.watch(currentSyncStateProvider);
    final syncState = asyncState.value ?? fallbackState;

    // Khi online và không có tác vụ nào đang chờ / đang đồng bộ
    if (syncState.isOnline && syncState.pendingCount == 0 && !syncState.isSyncing) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);

    if (syncState.isSyncing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: colorScheme.primary.withValues(alpha: 0.14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Đang đồng bộ ${syncState.pendingCount > 0 ? "${syncState.pendingCount} " : ""}tác vụ lên máy chủ...',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Ngoại tuyến hoặc có tác vụ chờ
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: warningColor.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: warningColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang làm việc ngoại tuyến${syncState.pendingCount > 0 ? " • ${syncState.pendingCount} tác vụ chờ gửi" : ""}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () {
              ref.read(offlineSyncManagerProvider).syncNow();
            },
            icon: Icon(Icons.sync_rounded, size: 16, color: colorScheme.primary),
            label: Text(
              'Đồng bộ ngay',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
