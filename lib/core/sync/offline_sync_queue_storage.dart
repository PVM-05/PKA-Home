import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_action_model.dart';

class OfflineSyncQueueStorage {
  static const String _storageKey = 'pka_home_offline_sync_queue';
  final SharedPreferences? _prefs;

  OfflineSyncQueueStorage({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Đọc toàn bộ danh sách các tác vụ có trong hàng đợi
  Future<List<SyncActionModel>> getAllActions() async {
    try {
      final prefs = await _getPrefs();
      final rawString = prefs.getString(_storageKey);
      if (rawString == null || rawString.trim().isEmpty) {
        return [];
      }

      final rawList = jsonDecode(rawString);
      if (rawList is List) {
        return rawList
            .map((item) => SyncActionModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('[OfflineSyncQueueStorage] Lỗi khi đọc hàng đợi từ bộ nhớ: $e');
    }
    return [];
  }

  /// Lấy danh sách các tác vụ đang chờ đồng bộ (pending hoặc failed) theo thứ tự FIFO
  Future<List<SyncActionModel>> getPendingActions() async {
    final all = await getAllActions();
    final pending = all
        .where((a) => a.status == SyncStatus.pending || a.status == SyncStatus.failed)
        .toList();
    // Sắp xếp tăng dần theo thời gian tạo (FIFO)
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  /// Thêm một tác vụ mới vào hàng đợi (kiểm tra chống lặp theo idempotencyKey)
  Future<void> enqueue(SyncActionModel action) async {
    final all = await getAllActions();
    
    // Kiểm tra xem đã có action với idempotencyKey này chưa
    final exists = all.any((a) => a.idempotencyKey == action.idempotencyKey && action.idempotencyKey.isNotEmpty);
    if (exists) {
      debugPrint('[OfflineSyncQueueStorage] Action đã tồn tại với idempotencyKey: ${action.idempotencyKey}');
      return;
    }

    all.add(action);
    await _saveActions(all);
  }

  /// Cập nhật trạng thái của một tác vụ
  Future<void> updateAction(SyncActionModel action) async {
    final all = await getAllActions();
    final index = all.indexWhere((a) => a.id == action.id);
    if (index != -1) {
      all[index] = action;
      await _saveActions(all);
    }
  }

  /// Xóa một tác vụ khỏi hàng đợi theo ID
  Future<void> removeAction(String actionId) async {
    final all = await getAllActions();
    all.removeWhere((a) => a.id == actionId);
    await _saveActions(all);
  }

  /// Xóa toàn bộ các tác vụ đã hoàn thành (completed)
  Future<void> clearCompleted() async {
    final all = await getAllActions();
    all.removeWhere((a) => a.status == SyncStatus.completed);
    await _saveActions(all);
  }

  /// Đếm số lượng tác vụ đang chờ đồng bộ
  Future<int> countPending() async {
    final pending = await getPendingActions();
    return pending.length;
  }

  /// Xóa sạch hàng đợi (dùng cho test hoặc reset)
  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey);
  }

  Future<void> _saveActions(List<SyncActionModel> actions) async {
    try {
      final prefs = await _getPrefs();
      final jsonList = actions.map((a) => a.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[OfflineSyncQueueStorage] Lỗi khi lưu hàng đợi vào bộ nhớ: $e');
    }
  }
}
