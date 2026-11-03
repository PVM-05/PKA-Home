import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/app_logger.dart';
import '../models/building_membership_model.dart';
import '../models/organization_membership_model.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepository();
});

final userBuildingMembershipsProvider =
    FutureProvider.family<List<BuildingMembershipModel>, String>((ref, userId) async {
  return ref.watch(membershipRepositoryProvider).fetchUserBuildingMemberships(userId);
});

class MembershipRepository {
  final SupabaseClient _client;

  MembershipRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  /// Chuẩn bị payload gán vai trò tòa nhà để kiểm thử và gọi RPC/Table an toàn
  Map<String, dynamic> buildAssignPayload({
    required String buildingId,
    required String userId,
    required String buildingRole,
    String? apartmentId,
    DateTime? expiresAt,
  }) {
    return <String, dynamic>{
      'building_id': buildingId,
      'user_id': userId,
      'building_role': buildingRole,
      'apartment_id': ?apartmentId,
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      'is_active': true,
    };
  }

  /// Lấy danh sách tòa nhà và vai trò cụ thể của một người dùng
  Future<List<BuildingMembershipModel>> fetchUserBuildingMemberships(String userId) async {
    try {
      final response = await _client
          .from('building_memberships')
          .select('*, buildings(name, code), apartments(code)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => BuildingMembershipModel.fromJson(json)).toList();
    } catch (e, stack) {
      AppLogger.e('Lỗi tải danh sách membership tòa nhà của người dùng: $e', e, stack);
      return [];
    }
  }

  /// Lấy danh sách thành viên và nhân viên thuộc một tòa nhà cụ thể
  Future<List<BuildingMembershipModel>> fetchBuildingMembers(String buildingId) async {
    try {
      final response = await _client
          .from('building_memberships')
          .select('*, buildings(name, code), apartments(code)')
          .eq('building_id', buildingId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => BuildingMembershipModel.fromJson(json)).toList();
    } catch (e, stack) {
      AppLogger.e('Lỗi tải danh sách thành viên tòa nhà: $e', e, stack);
      return [];
    }
  }

  /// Gán vai trò thành viên tòa nhà mới
  Future<BuildingMembershipModel> assignBuildingMembership({
    required String buildingId,
    required String userId,
    required String buildingRole,
    String? apartmentId,
    DateTime? expiresAt,
  }) async {
    final payload = buildAssignPayload(
      buildingId: buildingId,
      userId: userId,
      buildingRole: buildingRole,
      apartmentId: apartmentId,
      expiresAt: expiresAt,
    );

    final response = await _client
        .from('building_memberships')
        .insert(payload)
        .select('*, buildings(name, code), apartments(code)')
        .single();

    return BuildingMembershipModel.fromJson(response);
  }

  /// Thu hồi quyền thành viên tòa nhà
  Future<bool> revokeBuildingMembership(String membershipId) async {
    try {
      await _client.from('building_memberships').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', membershipId);
      return true;
    } catch (e, stack) {
      AppLogger.e('Lỗi thu hồi quyền thành viên: $e', e, stack);
      return false;
    }
  }

  /// Lấy danh sách tổ chức mà người dùng là thành viên
  Future<List<OrganizationMembershipModel>> fetchUserOrganizations(String userId) async {
    try {
      final response = await _client
          .from('organization_memberships')
          .select('*, organizations(name, slug)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((json) => OrganizationMembershipModel.fromJson(json)).toList();
    } catch (e, stack) {
      AppLogger.e('Lỗi tải danh sách tổ chức của người dùng: $e', e, stack);
      return [];
    }
  }
}
