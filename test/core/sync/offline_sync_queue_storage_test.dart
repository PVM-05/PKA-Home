import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/sync/offline_sync_queue_storage.dart';
import 'package:pka_home/core/sync/sync_action_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SyncActionModel Tests', () {
    test('Khởi tạo và mapping toJson/fromJson đầy đủ', () {
      final now = DateTime.now();
      final action = SyncActionModel(
        id: 'act-01',
        actionType: 'create_issue',
        endpoint: 'issue_reports',
        payload: {'title': 'Hỏng đèn hành lang', 'apartment_id': 'apt-1'},
        createdAt: now,
        idempotencyKey: 'key-123',
      );

      final json = action.toJson();
      expect(json['id'], 'act-01');
      expect(json['action_type'], 'create_issue');
      expect(json['status'], 'pending');

      final restored = SyncActionModel.fromJson(json);
      expect(restored.id, 'act-01');
      expect(restored.payload['title'], 'Hỏng đèn hành lang');
      expect(restored.status, SyncStatus.pending);
    });

    test('copyWith cho phép cập nhật trạng thái và retryCount', () {
      final action = SyncActionModel(
        id: 'act-02',
        actionType: 'execute_dunning',
        endpoint: 'execute_dunning_action',
        payload: {'tier': 'tier_1'},
        createdAt: DateTime.now(),
        idempotencyKey: 'key-456',
      );

      final updated = action.copyWith(
        status: SyncStatus.failed,
        retryCount: 1,
        lastError: 'Không có kết nối mạng',
      );

      expect(updated.status, SyncStatus.failed);
      expect(updated.retryCount, 1);
      expect(updated.lastError, 'Không có kết nối mạng');
    });
  });

  group('OfflineSyncQueueStorage Tests', () {
    late OfflineSyncQueueStorage storage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = OfflineSyncQueueStorage();
    });

    test('enqueue và getPendingActions trả về theo thứ tự FIFO', () async {
      final a1 = SyncActionModel(
        id: '1',
        actionType: 't1',
        endpoint: 'e1',
        payload: {},
        createdAt: DateTime(2026, 11, 4, 10, 0, 0),
        idempotencyKey: 'k1',
      );
      final a2 = SyncActionModel(
        id: '2',
        actionType: 't2',
        endpoint: 'e2',
        payload: {},
        createdAt: DateTime(2026, 11, 4, 9, 30, 0), // Tạo trước
        idempotencyKey: 'k2',
      );

      await storage.enqueue(a1);
      await storage.enqueue(a2);

      final pending = await storage.getPendingActions();
      expect(pending.length, 2);
      expect(pending.first.id, '2', reason: 'Tác vụ tạo sớm hơn phải đứng trước (FIFO)');
      expect(pending.last.id, '1');
    });

    test('enqueue từ chối tác vụ trùng lặp idempotencyKey', () async {
      final a1 = SyncActionModel(
        id: '1',
        actionType: 't1',
        endpoint: 'e1',
        payload: {},
        createdAt: DateTime.now(),
        idempotencyKey: 'dup-key',
      );
      final a2 = SyncActionModel(
        id: '2',
        actionType: 't1',
        endpoint: 'e1',
        payload: {},
        createdAt: DateTime.now(),
        idempotencyKey: 'dup-key',
      );

      await storage.enqueue(a1);
      await storage.enqueue(a2);

      final all = await storage.getAllActions();
      expect(all.length, 1, reason: 'Chống trùng lặp theo idempotencyKey');
    });

    test('updateAction và removeAction hoạt động chính xác', () async {
      final a = SyncActionModel(
        id: '1',
        actionType: 't1',
        endpoint: 'e1',
        payload: {},
        createdAt: DateTime.now(),
        idempotencyKey: 'k1',
      );

      await storage.enqueue(a);
      final updated = a.copyWith(status: SyncStatus.completed);
      await storage.updateAction(updated);

      var pending = await storage.getPendingActions();
      expect(pending.isEmpty, isTrue, reason: 'completed không còn nằm trong pending');

      await storage.clearCompleted();
      final all = await storage.getAllActions();
      expect(all.isEmpty, isTrue);
    });
  });
}
