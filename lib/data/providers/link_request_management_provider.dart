import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_config.dart';
import 'building_provider.dart';
import 'dashboard_providers.dart' show pendingLinkRequestsCountProvider, apartmentsStreamProvider;
import 'management_provider.dart' show residentsProvider;

final linkRequestManagementProvider = StateNotifierProvider<LinkRequestManagementNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  ref.watch(effectiveBuildingIdProvider);
  return LinkRequestManagementNotifier(ref);
});

class LinkRequestManagementNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  RealtimeChannel? _channel;

  LinkRequestManagementNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchRequests();
    _setupRealtime();
  }

  void _setupRealtime() {
    _channel = SupabaseConfig.client
        .channel('public:apartment_link_requests_admin')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'apartment_link_requests',
          callback: (payload) {
            fetchRequests();
            ref.invalidate(pendingLinkRequestsCountProvider);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      SupabaseConfig.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> fetchRequests() async {
    try {
      state = const AsyncValue.loading();
      final res = await SupabaseConfig.client
          .from('apartment_link_requests')
          .select('''
            id,
            user_id,
            apartment_id,
            requested_relation_role,
            created_at,
            users ( id, full_name, phone ),
            apartments ( id, code, building_id )
          ''')
          .eq('status', 'pending')
          .order('created_at');

      final effectiveBuildingId = ref.read(effectiveBuildingIdProvider);
      final rawList = List<Map<String, dynamic>>.from(res);
      final filtered = effectiveBuildingId == null
          ? rawList
          : rawList.where((row) {
              final apt = row['apartments'] as Map<String, dynamic>?;
              final aptBld = apt?['building_id']?.toString();
              return aptBld == effectiveBuildingId;
            }).toList();

      state = AsyncValue.data(filtered);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> approveRequest(String requestId) async {
    try {
      await SupabaseConfig.client.rpc('approve_link_request', params: {'p_request_id': requestId});
      await fetchRequests();
      ref.invalidate(pendingLinkRequestsCountProvider);
      ref.invalidate(residentsProvider);
      ref.invalidate(apartmentsStreamProvider);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId, {required String reason, String? reviewedBy}) async {
    try {
      final currentUserId = reviewedBy ?? SupabaseConfig.client.auth.currentUser?.id;
      final updateData = <String, dynamic>{
        'status': 'rejected',
        'rejection_reason': reason,
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (currentUserId != null) {
        updateData['reviewed_by'] = currentUserId;
      }
      await SupabaseConfig.client
          .from('apartment_link_requests')
          .update(updateData)
          .eq('id', requestId);
      await fetchRequests();
      ref.invalidate(pendingLinkRequestsCountProvider);
    } catch (e) {
      rethrow;
    }
  }
}
