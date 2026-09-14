import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/user_model.dart';

class UserRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<UserModel> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    try {
      // 1. Ưu tiên gọi RPC bảo mật cao update_own_profile (chỉ nhận full_name và phone)
      final rpcParams = <String, dynamic>{};
      if (fullName != null) rpcParams['p_full_name'] = fullName;
      if (phone != null) rpcParams['p_phone'] = phone;

      final rpcRes = await _client.rpc(
        'update_own_profile',
        params: rpcParams,
      );
      if (rpcRes != null) {
        return UserModel.fromJson(Map<String, dynamic>.from(rpcRes));
      }
    } catch (_) {
      // Fallback: Nếu CSDL chưa chạy migration RPC thì gọi update trực tiếp (không chạm vào cột role)
    }

    final updateData = <String, dynamic>{};
    if (fullName != null) updateData['full_name'] = fullName;
    if (phone != null) updateData['phone'] = phone;

    final response = await _client
        .from('users')
        .update(updateData)
        .eq('id', userId)
        .select()
        .single();

    return UserModel.fromJson(response);
  }

  Future<List<Map<String, dynamic>>> fetchCoResidents(String apartmentId) async {
    final response = await _client
        .from('residents_apartments')
        .select('relation_role, users(id, full_name, phone)')
        .eq('apartment_id', apartmentId);

    return List<Map<String, dynamic>>.from(response as List);
  }
}
