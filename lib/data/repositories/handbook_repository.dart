import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/emergency_contact_model.dart';
import '../models/building_rule_model.dart';
import '../models/building_amenity_model.dart';

class HandbookRepository {
  final SupabaseClient _client = SupabaseConfig.client;
  
  // Cache keys
  static const String _contactsCacheKey = 'handbook_contacts_cache';
  static const String _rulesCacheKey = 'handbook_rules_cache';
  static const String _amenitiesCacheKey = 'handbook_amenities_cache';

  // ==========================================
  // 1. Emergency Contacts (Đường dây nóng)
  // ==========================================
  Future<List<EmergencyContactModel>> fetchEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _client
          .from('emergency_contacts')
          .select()
          .order('display_order', ascending: true);

      final data = (response as List).cast<Map<String, dynamic>>();
      // Cache data
      await prefs.setString(_contactsCacheKey, jsonEncode(data));

      return data.map((e) => EmergencyContactModel.fromJson(e)).toList();
    } catch (e) {
      // Load from cache if network fails
      final cachedStr = prefs.getString(_contactsCacheKey);
      if (cachedStr != null) {
        final cachedData = jsonDecode(cachedStr) as List;
        return cachedData.map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchContacts() {
    return _client.from('emergency_contacts').stream(primaryKey: ['id']);
  }

  Future<void> createEmergencyContact({
    required String name,
    required String phone,
    String contactType = 'security',
    int displayOrder = 0,
  }) async {
    await _client.from('emergency_contacts').insert({
      'name': name,
      'phone': phone,
      'contact_type': contactType,
      'display_order': displayOrder,
    });
  }

  Future<void> updateEmergencyContact({
    required String id,
    required String name,
    required String phone,
    String contactType = 'security',
    int displayOrder = 0,
  }) async {
    await _client.from('emergency_contacts').update({
      'name': name,
      'phone': phone,
      'contact_type': contactType,
      'display_order': displayOrder,
    }).eq('id', id);
  }

  Future<void> deleteEmergencyContact(String id) async {
    await _client.from('emergency_contacts').delete().eq('id', id);
  }

  // ==========================================
  // 2. Building Rules (Nội quy chung cư)
  // ==========================================
  Future<List<BuildingRuleModel>> fetchBuildingRules() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _client
          .from('building_rules')
          .select()
          .order('display_order', ascending: true);

      final data = (response as List).cast<Map<String, dynamic>>();
      // Cache data
      await prefs.setString(_rulesCacheKey, jsonEncode(data));

      return data.map((e) => BuildingRuleModel.fromJson(e)).toList();
    } catch (e) {
      // Load from cache if network fails
      final cachedStr = prefs.getString(_rulesCacheKey);
      if (cachedStr != null) {
        final cachedData = jsonDecode(cachedStr) as List;
        return cachedData.map((e) => BuildingRuleModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchRules() {
    return _client.from('building_rules').stream(primaryKey: ['id']);
  }

  Future<void> createBuildingRule({
    required String title,
    required String content,
    int displayOrder = 0,
  }) async {
    await _client.from('building_rules').insert({
      'title': title,
      'content': content,
      'display_order': displayOrder,
    });
  }

  Future<void> updateBuildingRule({
    required String id,
    required String title,
    required String content,
    int displayOrder = 0,
  }) async {
    await _client.from('building_rules').update({
      'title': title,
      'content': content,
      'display_order': displayOrder,
    }).eq('id', id);
  }

  Future<void> deleteBuildingRule(String id) async {
    await _client.from('building_rules').delete().eq('id', id);
  }

  // ==========================================
  // 3. Building Amenities (Tiện ích tòa nhà)
  // ==========================================
  Future<List<BuildingAmenityModel>> fetchBuildingAmenities() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _client
          .from('building_amenities')
          .select()
          .order('display_order', ascending: true);

      final data = (response as List).cast<Map<String, dynamic>>();
      // Cache data
      await prefs.setString(_amenitiesCacheKey, jsonEncode(data));

      return data.map((e) => BuildingAmenityModel.fromJson(e)).toList();
    } catch (e) {
      // Load from cache if network fails
      final cachedStr = prefs.getString(_amenitiesCacheKey);
      if (cachedStr != null) {
        final cachedData = jsonDecode(cachedStr) as List;
        return cachedData.map((e) => BuildingAmenityModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchAmenities() {
    return _client.from('building_amenities').stream(primaryKey: ['id']);
  }

  Future<void> createBuildingAmenity({
    required String name,
    String? description,
    String? openHours,
    int displayOrder = 0,
  }) async {
    await _client.from('building_amenities').insert({
      'name': name,
      'description': description,
      'open_hours': openHours,
      'display_order': displayOrder,
    });
  }

  Future<void> updateBuildingAmenity({
    required String id,
    required String name,
    String? description,
    String? openHours,
    int displayOrder = 0,
  }) async {
    await _client.from('building_amenities').update({
      'name': name,
      'description': description,
      'open_hours': openHours,
      'display_order': displayOrder,
    }).eq('id', id);
  }

  Future<void> deleteBuildingAmenity(String id) async {
    await _client.from('building_amenities').delete().eq('id', id);
  }
}
