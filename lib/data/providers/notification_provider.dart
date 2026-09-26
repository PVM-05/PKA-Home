import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import 'auth_provider.dart';

final notificationRepositoryProvider = Provider((ref) => NotificationRepository());

/// Stream danh sách thông báo theo thời gian thực của người dùng hiện tại
final notificationsStreamProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) {
    return Stream.value([]);
  }

  return SupabaseConfig.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .map((list) => list.map((json) => NotificationModel.fromJson(json)).toList());
});

/// Số lượng thông báo chưa đọc của người dùng hiện tại
final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notificationsAsync = ref.watch(notificationsStreamProvider);
  return notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;
});
