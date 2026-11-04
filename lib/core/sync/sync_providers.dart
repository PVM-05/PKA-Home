import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_sync_manager.dart';
import 'offline_sync_queue_storage.dart';

final offlineSyncQueueStorageProvider = Provider<OfflineSyncQueueStorage>((ref) {
  return OfflineSyncQueueStorage();
});

final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  final storage = ref.watch(offlineSyncQueueStorageProvider);
  final manager = OfflineSyncManager(storage: storage);
  ref.onDispose(() => manager.dispose());
  return manager;
});

final syncStateProvider = StreamProvider<SyncState>((ref) {
  final manager = ref.watch(offlineSyncManagerProvider);
  return manager.stateStream;
});

final currentSyncStateProvider = StateProvider<SyncState>((ref) {
  final manager = ref.watch(offlineSyncManagerProvider);
  return manager.currentState;
});
