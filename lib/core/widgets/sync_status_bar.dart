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

    if (syncState.isSyncing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppTheme.primary.withValues(alpha: 0.12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Đang đồng bộ ${syncState.pendingCount > 0 ? "${syncState.pendingCount} " : ""}tác vụ lên máy chủ...',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Ngoại tuyến (offline) hoặc có tác vụ chờ
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang làm việc ngoại tuyến (Offline)${syncState.pendingCount > 0 ? " • ${syncState.pendingCount} tác vụ chờ gửi" : ""}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              ref.read(offlineSyncManagerProvider).syncNow();
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  const Text(
                    'Đồng bộ ngay',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
