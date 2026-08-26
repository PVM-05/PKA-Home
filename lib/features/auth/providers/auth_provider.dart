import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../../../core/supabase_config.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      await _fetchUserInfo(session.user.id);
    } else {
      state = const AsyncValue.data(null);
    }

    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
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
      final data = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      final user = UserModel.fromJson(data);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // State is updated via onAuthStateChange listener
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await SupabaseConfig.client.auth.signOut();
  }
}
