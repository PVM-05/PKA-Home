import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final user = _repository.currentUser;
    if (user != null) {
      await _fetchUserInfo(user.id);
    } else {
      state = const AsyncValue.data(null);
    }

    _repository.authStateChanges.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      if (event == AuthChangeEvent.signedIn && session != null) {
         _fetchUserInfo(session.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
         state = const AsyncValue.data(null);
      }
    });
  }

  Future<void> _fetchUserInfo(String userId) async {
    try {
      state = const AsyncValue.loading();
      final data = await _repository.fetchUserInfo(userId);
      final userModel = UserModel.fromJson(data);
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
    await _repository.logout();
  }
}
