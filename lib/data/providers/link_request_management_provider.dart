import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_config.dart';
import 'dashboard_providers.dart' show pendingLinkRequestsCountProvider, apartmentsStreamProvider;
import 'management_provider.dart' show residentsProvider;

final linkRequestManagementProvider = StateNotifierProvider<LinkRequestManagementNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
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
            requested_relation_role,
            created_at,
            users ( full_name ),
            apartments ( code )
          ''')
          .eq('status', 'pending')
          .order('created_at');
          
      state = AsyncValue.data(List<Map<String, dynamic>>.from(res));
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

  Future<void> rejectRequest(String requestId) async {
    try {
      await SupabaseConfig.client
          .from('apartment_link_requests')
          .update({'status': 'rejected', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', requestId);
      await fetchRequests();
      ref.invalidate(pendingLinkRequestsCountProvider);
    } catch (e) {
      rethrow;
    }
  }
}
