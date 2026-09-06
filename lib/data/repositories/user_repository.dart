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
