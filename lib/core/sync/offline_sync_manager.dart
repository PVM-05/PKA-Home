import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_sync_queue_storage.dart';
import 'sync_action_model.dart';

class SyncState {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final String? lastErrorMessage;

  const SyncState({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastSyncAt,
    this.lastErrorMessage,
  });

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncAt,
    String? lastErrorMessage,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastErrorMessage: lastErrorMessage,
    );
  }
}

class SyncResult {
  final int processedCount;
  final int successCount;
  final int failedCount;

  const SyncResult({
    required this.processedCount,
    required this.successCount,
    required this.failedCount,
  });
}

typedef ActionExecutor = Future<void> Function(SyncActionModel action);

class OfflineSyncManager {
  final OfflineSyncQueueStorage _storage;
  final SupabaseClient? _client;
  final Map<String, ActionExecutor> _customExecutors = {};

  bool _isOnline = true;
  bool _isSyncing = false;
  final _stateController = StreamController<SyncState>.broadcast();
  SyncState _currentState = const SyncState();

  OfflineSyncManager({
    OfflineSyncQueueStorage? storage,
    this._client,
  })  : _storage = storage ?? OfflineSyncQueueStorage();

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  SyncState get currentState => _currentState;
  Stream<SyncState> get stateStream => _stateController.stream;

  /// Đăng ký executor tùy chỉnh cho từng loại actionType (hỗ trợ test và mở rộng)
  void registerExecutor(String actionType, ActionExecutor executor) {
    _customExecutors[actionType] = executor;
  }

  /// Cập nhật trạng thái mạng (online/offline)
  void setOnlineStatus(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _notifyState();

    if (_isOnline) {
      debugPrint('[OfflineSyncManager] Mạng đã kết nối trở lại, kích hoạt tiến trình đồng bộ...');
      processQueue();
    }
  }

  /// Thêm một hành động mutation vào hàng đợi
  Future<SyncActionModel> enqueueAction({
    required String actionType,
    required String endpoint,
    required Map<String, dynamic> payload,
    String? customIdempotencyKey,
  }) async {
    final actionId = 'sync-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final idempotencyKey = customIdempotencyKey ?? '$actionType-$actionId';

    final action = SyncActionModel(
      id: actionId,
      actionType: actionType,
      endpoint: endpoint,
      payload: payload,
      createdAt: DateTime.now(),
      idempotencyKey: idempotencyKey,
      status: SyncStatus.pending,
    );

    await _storage.enqueue(action);
    await _updatePendingCount();

    if (_isOnline) {
      // Trigger xử lý nền nếu đang online
      unawaited(processQueue());
    }

    return action;
  }

  /// Kích hoạt đồng bộ thủ công từ UI
  Future<SyncResult> syncNow() async {
    return processQueue();
  }

  /// Tiến trình duyệt và xử lý các tác vụ trong hàng đợi theo thứ tự FIFO
  Future<SyncResult> processQueue() async {
    if (_isSyncing) {
      debugPrint('[OfflineSyncManager] Tiến trình đồng bộ đang chạy, bỏ qua gọi trùng');
      return const SyncResult(processedCount: 0, successCount: 0, failedCount: 0);
    }

    if (!_isOnline) {
      debugPrint('[OfflineSyncManager] Đang ngoại tuyến, tạm hoãn đồng bộ');
      await _updatePendingCount();
      return const SyncResult(processedCount: 0, successCount: 0, failedCount: 0);
    }

    _isSyncing = true;
    _notifyState();

    int successCount = 0;
    int failedCount = 0;
    int processedCount = 0;

    try {
      final pendingActions = await _storage.getPendingActions();
      processedCount = pendingActions.length;

      for (final action in pendingActions) {
        if (!_isOnline) {
          debugPrint('[OfflineSyncManager] Mất kết nối trong lúc đồng bộ, tạm dừng');
          break;
        }

        // Cập nhật trạng thái syncing
        await _storage.updateAction(action.copyWith(status: SyncStatus.syncing));

        try {
          await _executeSingleAction(action);

          // Thành công: Xóa khỏi hàng đợi để tối ưu bộ nhớ
          await _storage.removeAction(action.id);
          successCount++;
        } catch (e) {
          failedCount++;
          final nextRetry = action.retryCount + 1;
          final isMaxRetry = nextRetry >= 5;

          debugPrint('[OfflineSyncManager] Lỗi xử lý action ${action.id} (lần $nextRetry): $e');

          await _storage.updateAction(
            action.copyWith(
              status: isMaxRetry ? SyncStatus.failed : SyncStatus.pending,
              retryCount: nextRetry,
              lastError: e.toString(),
            ),
          );

          // Nếu lỗi mạng thì tạm ngưng queue để tránh spam
          if (_isNetworkError(e)) {
            _isOnline = false;
            break;
          }
        }
      }

      await _storage.clearCompleted();
    } finally {
      _isSyncing = false;
      _currentState = _currentState.copyWith(
        isOnline: _isOnline,
        isSyncing: false,
        lastSyncAt: DateTime.now(),
      );
      await _updatePendingCount();
    }

    return SyncResult(
      processedCount: processedCount,
      successCount: successCount,
      failedCount: failedCount,
    );
  }

  Future<void> _executeSingleAction(SyncActionModel action) async {
    // 1. Kiểm tra custom executor
    if (_customExecutors.containsKey(action.actionType)) {
      await _customExecutors[action.actionType]!(action);
      return;
    }

    // 2. Mặc định gọi Supabase RPC hoặc Table Insert
    final client = _client ?? Supabase.instance.client;

    if (action.endpoint.startsWith('rpc/')) {
      final rpcName = action.endpoint.replaceFirst('rpc/', '');
      await client.rpc(rpcName, params: action.payload);
    } else {
      // Table insert hoặc RPC thông thường
      if (action.actionType == 'create_issue') {
        await client.from('issue_reports').insert(action.payload);
      } else if (action.actionType == 'execute_dunning') {
        await client.rpc('execute_dunning_action', params: action.payload);
      } else if (action.actionType == 'log_meter_reading') {
        await client.rpc('record_meter_reading', params: action.payload);
      } else if (action.actionType == 'submit_vote') {
        await client.rpc('submit_poll_vote', params: action.payload);
      } else {
        // Fallback gọi theo tên endpoint
        await client.rpc(action.endpoint, params: action.payload);
      }
    }
  }

  bool _isNetworkError(dynamic e) {
    final str = e.toString().toLowerCase();
    return str.contains('socket') ||
        str.contains('network') ||
        str.contains('timeout') ||
        str.contains('failed host lookup') ||
        str.contains('connection refused') ||
        str.contains('offline');
  }

  Future<void> _updatePendingCount() async {
    final count = await _storage.countPending();
    _currentState = _currentState.copyWith(
      isOnline: _isOnline,
      isSyncing: _isSyncing,
      pendingCount: count,
    );
    _notifyState();
  }

  void _notifyState() {
    _currentState = _currentState.copyWith(
      isOnline: _isOnline,
      isSyncing: _isSyncing,
    );
    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
  }

  void dispose() {
    _stateController.close();
  }
}
