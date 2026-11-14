import '../../core/utils/guard_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_config.dart';
import '../models/apartment_invitation_model.dart';
import '../models/resident_lease_contract_model.dart';

class ResidentLifecycleRepository {
  final SupabaseClient? _client;

  ResidentLifecycleRepository([this._client]);

  SupabaseClient get _supabase {
    final c = _client;
    if (c != null) return c;
    if (SupabaseConfig.isConfigured) {
      return SupabaseConfig.client;
    }
    throw const AppException('Supabase chưa sẵn sàng');
  }

  Future<List<ResidentLeaseContractModel>> fetchApartmentContracts(
    String apartmentId,
  ) async {
    return FailClosedGuard.guard(
      operation: 'fetchApartmentContracts',
      call: () async {
        final client = _supabase;
        final response = await client.rpc(
          'get_apartment_contracts',
          params: {'p_apartment_id': apartmentId},
        );

        if (response is List) {
          return response
              .map(
                (item) => ResidentLeaseContractModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        }
        return [];
      },
    );
  }

  Future<List<ApartmentInvitationModel>> fetchApartmentInvitations(
    String apartmentId,
  ) async {
    return FailClosedGuard.guard(
      operation: 'fetchApartmentInvitations',
      call: () async {
        final client = _supabase;
        final response = await client
            .from('apartment_invitations')
            .select('*, apartments(code)')
            .eq('apartment_id', apartmentId)
            .order('created_at', ascending: false);

        return (response as List).map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['apartments'] != null && map['apartments'] is Map) {
            map['apartment_code'] = (map['apartments'] as Map)['code'];
          }
          return ApartmentInvitationModel.fromJson(map);
        }).toList();
      },
    );
  }

  Future<Map<String, dynamic>> createInvitation({
    required String apartmentId,
    required String targetRole,
    int expiresHours = 48,
    int maxUses = 1,
  }) async {
    return FailClosedGuard.guard(
      operation: 'createInvitation',
      call: () async {
        final response = await _supabase.rpc(
          'create_apartment_invitation',
          params: {
            'p_apartment_id': apartmentId,
            'p_target_role': targetRole,
            'p_expires_hours': expiresHours,
            'p_max_uses': maxUses,
          },
        );
        return Map<String, dynamic>.from(response as Map);
      },
    );
  }

  Future<Map<String, dynamic>> acceptInvitation(String inviteCode) async {
    return FailClosedGuard.guard(
      operation: 'acceptInvitation',
      call: () async {
        final client = _supabase;
        final response = await client.rpc(
          'accept_apartment_invitation',
          params: {'p_invite_code': inviteCode.trim().toUpperCase()},
        );
        return Map<String, dynamic>.from(response as Map);
      },
    );
  }

  Future<Map<String, dynamic>> terminateResidentStay({
    required String userId,
    required String apartmentId,
    DateTime? terminationDate,
    String? note,
  }) async {
    return FailClosedGuard.guard(
      operation: 'terminateResidentStay',
      call: () async {
        final client = _supabase;
        final dateStr = (terminationDate ?? DateTime.now())
            .toIso8601String()
            .split('T')[0];
        final response = await client.rpc(
          'terminate_resident_stay',
          params: {
            'p_user_id': userId,
            'p_apartment_id': apartmentId,
            'p_termination_date': dateStr,
            'p_note': note ?? '',
          },
        );
        return Map<String, dynamic>.from(response as Map);
      },
    );
  }
}
