import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/building_model.dart';

class BuildingRepository {
  final SupabaseClient _client;

  BuildingRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

  static const String kDefaultCanonicalBuildingId = '00000000-0000-0000-0000-000000000002';
  static const String kDefaultCanonicalOrgId = '00000000-0000-0000-0000-000000000001';

  Future<List<BuildingModel>> getAllActiveBuildings() async {
    try {
      final response = await _client
          .from('buildings')
          .select()
          .eq('is_active', true)
          .order('name');
      return (response as List<dynamic>)
          .map((e) => BuildingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<BuildingModel>> getUserAssignedBuildings(String userId) async {
    try {
      final response = await _client
          .from('building_staff')
          .select('building_id, buildings(*)')
          .eq('user_id', userId);

      final list = <BuildingModel>[];
      for (final item in (response as List<dynamic>)) {
        if (item['buildings'] != null) {
          list.add(BuildingModel.fromJson(item['buildings'] as Map<String, dynamic>));
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<BuildingModel?> getBuildingById(String buildingId) async {
    try {
      final response = await _client
          .from('buildings')
          .select()
          .eq('id', buildingId)
          .maybeSingle();
      if (response == null) return null;
      return BuildingModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}
