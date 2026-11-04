import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/sync/offline_sync_manager.dart';
import 'package:pka_home/core/sync/offline_sync_queue_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OfflineSyncManager Tests', () {
    late OfflineSyncQueueStorage storage;
    late OfflineSyncManager manager;
    late List<String> executedActionIds;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = OfflineSyncQueueStorage();
      manager = OfflineSyncManager(storage: storage);
      executedActionIds = [];

      manager.registerExecutor('test_action', (action) async {
        executedActionIds.add(action.id);
      });
    });

    tearDown(() {
      manager.dispose();
    });

    test('Khi ngoại tuyến (offline), enqueueAction lưu vào storage và chưa xử lý', () async {
      manager.setOnlineStatus(false);

      final action = await manager.enqueueAction(
        actionType: 'test_action',
        endpoint: 'test_endpoint',
        payload: {'data': 'offline_payload'},
      );

      expect(manager.currentState.pendingCount, 1);
      expect(executedActionIds.isEmpty, isTrue, reason: 'Chưa được gọi khi offline');

      final pending = await storage.getPendingActions();
      expect(pending.length, 1);
      expect(pending.first.id, action.id);
    });

    test('Khi chuyển từ offline sang online, tự động kích hoạt processQueue theo thứ tự FIFO', () async {
      manager.setOnlineStatus(false);

      final a1 = await manager.enqueueAction(
        actionType: 'test_action',
        endpoint: 'e1',
        payload: {'order': 1},
        customIdempotencyKey: 'k1',
      );
      final a2 = await manager.enqueueAction(
        actionType: 'test_action',
        endpoint: 'e2',
        payload: {'order': 2},
        customIdempotencyKey: 'k2',
      );

      expect(manager.currentState.pendingCount, 2);
      expect(executedActionIds.isEmpty, isTrue);

      // Kích hoạt online
      manager.setOnlineStatus(true);

      // Chờ tiến trình bất đồng bộ hoàn thành
      await Future.delayed(const Duration(milliseconds: 100));

      expect(executedActionIds.length, 2);
      expect(executedActionIds[0], a1.id, reason: 'Tác vụ 1 phải chạy trước (FIFO)');
      expect(executedActionIds[1], a2.id, reason: 'Tác vụ 2 chạy sau');

      final pendingAfter = await storage.getPendingActions();
      expect(pendingAfter.isEmpty, isTrue, reason: 'Đã hoàn thành và dọn dẹp hàng đợi');
    });

    test('Khi executor ném lỗi mạng, retryCount tăng lên và tạm hoãn queue', () async {
      manager.setOnlineStatus(true);

      manager.registerExecutor('failing_action', (action) async {
        throw Exception('SocketException: Failed host lookup');
      });

      await manager.enqueueAction(
        actionType: 'failing_action',
        endpoint: 'fail_endpoint',
        payload: {},
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final pending = await storage.getPendingActions();
      expect(pending.length, 1);
      expect(pending.first.retryCount, 1);
      expect(pending.first.lastError?.contains('SocketException'), isTrue);
      expect(manager.isOnline, isFalse, reason: 'Tự động phát hiện lỗi mạng và chuyển sang offline');
    });
  });
}
