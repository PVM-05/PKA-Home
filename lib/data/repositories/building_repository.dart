import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/building_model.dart';

class BuildingRepository {
  final SupabaseClient? _customClient;

  BuildingRepository([SupabaseClient? client]) : _customClient = client;

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  static const String kDefaultCanonicalBuildingId = '00000000-0000-0000-0000-000000000002';
  static const String kDefaultCanonicalOrgId = '00000000-0000-0000-0000-000000000001';

  Future<List<BuildingModel>> getAllActiveBuildings() async {
    try {
      final client = _client;
      if (client == null) return [];
      final response = await client
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
      final client = _client;
      if (client == null) return [];
      final response = await client
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
      final client = _client;
      if (client == null) return null;
      final response = await client
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
