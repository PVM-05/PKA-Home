import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/push_notification_service.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

/// Provider tự động kích hoạt đồng bộ hóa FCM Device Token khi người dùng đăng nhập
final fcmTokenSyncProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.valueOrNull;
  if (user != null) {
    ref.read(pushNotificationServiceProvider).safeInitialize(userId: user.id);
  }
});

/// Provider thông báo phiên làm việc hết hạn
final sessionExpiredNoticeProvider = StateProvider<bool>((ref) => false);

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  final notifier = AuthNotifier(ref.read(authRepositoryProvider), ref);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repository;
  final Ref? _ref;
  bool _isManualLogout = false;
  StreamSubscription? _authSubscription;

  AuthNotifier(this._repository, [this._ref]) : super(const AsyncValue.loading()) {
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final user = _repository.currentUser;
    if (user != null) {
      await _fetchUserInfo(user.id);
    } else {
      state = const AsyncValue.data(null);
    }

    _authSubscription = _repository.authStateChanges.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        _ref?.read(sessionExpiredNoticeProvider.notifier).state = false;
        _fetchUserInfo(session.user.id);
      } else if (event == AuthChangeEvent.signedOut || (event == AuthChangeEvent.tokenRefreshed && session == null)) {
        final wasLoggedIn = state.valueOrNull != null;
        state = const AsyncValue.data(null);
        if (wasLoggedIn && !_isManualLogout) {
          _ref?.read(sessionExpiredNoticeProvider.notifier).state = true;
        }
      }
    });
  }

  Future<void> _fetchUserInfo(String userId) async {
    try {
      state = const AsyncValue.loading();
      final data = await _repository.fetchUserInfo(userId);
      final userModel = UserModel.fromJson(data);

      if (userModel.isLocked) {
        await logout();
        state = AsyncValue.error(
          Exception('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ Ban Quản Lý để được hỗ trợ.'),
          StackTrace.current,
        );
        return;
      }

      state = AsyncValue.data(userModel);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    await _repository.login(email, password);
  }

  Future<void> register(String email, String password, String fullName) async {
    await _repository.register(email, password, fullName);
  }

  Future<void> logout() async {
    _isManualLogout = true;
    try {
      _ref?.read(sessionExpiredNoticeProvider.notifier).state = false;
      await _repository.logout();
    } finally {
      _isManualLogout = false;
    }
  }

  void updateUser(UserModel updated) {
    state = AsyncValue.data(updated);
  }

  Future<void> refreshUser() async {
    final user = _repository.currentUser;
    if (user != null) {
      await _fetchUserInfo(user.id);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
