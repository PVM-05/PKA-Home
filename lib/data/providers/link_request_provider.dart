import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';

enum LinkStatus { loading, linked, pending, rejected, none }

class ResidentLinkStatus {
  final LinkStatus status;
  
  ResidentLinkStatus({required this.status});
}

class ParsedApartment {
  final String code;
  final String building;
  final String floor;
  final String room;

  ParsedApartment({
    required this.code,
    required this.building,
    required this.floor,
    required this.room,
  });

  factory ParsedApartment.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    final building = json['building_code'] as String;
    final floor = (json['floor_number'] as int).toString();
    
    // Room name can just be the code, or we can format it. 
    // Usually the user wants to see the code (e.g. A0101) or just the room number.
    // Let's use the code for clarity, e.g. "Phòng A0101".
    return ParsedApartment(
      code: code,
      building: building,
      floor: floor,
      room: code, // We will display the full code as the room name for absolute clarity
    );
  }
}

final availableApartmentsProvider = FutureProvider<List<ParsedApartment>>((ref) async {
  try {
    final res = await SupabaseConfig.client
        .from('apartments')
        .select('code, building_code, floor_number')
        .order('building_code')
        .order('floor_number')
        .order('code');
    
    return (res as List).map((e) => ParsedApartment.fromJson(e)).toList();
  } catch (e, st) {
    AppLogger.e('Error fetching apartments: $e', e, st);
    return [];
  }
});

final residentLinkProvider = StateNotifierProvider<ResidentLinkNotifier, ResidentLinkStatus>((ref) {
  return ResidentLinkNotifier();
});

class ResidentLinkNotifier extends StateNotifier<ResidentLinkStatus> {
  RealtimeChannel? _reqChannel;
  RealtimeChannel? _aptChannel;

  ResidentLinkNotifier() : super(ResidentLinkStatus(status: LinkStatus.loading)) {
    checkStatus();
    _setupRealtime();
  }

  void _setupRealtime() {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    _reqChannel = SupabaseConfig.client
        .channel('apartment_link_requests_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'apartment_link_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            checkStatus();
          },
        )
        .subscribe();

    _aptChannel = SupabaseConfig.client
        .channel('residents_apartments_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'residents_apartments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            checkStatus();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_reqChannel != null) SupabaseConfig.client.removeChannel(_reqChannel!);
    if (_aptChannel != null) SupabaseConfig.client.removeChannel(_aptChannel!);
    super.dispose();
  }

  Future<void> checkStatus() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      state = ResidentLinkStatus(status: LinkStatus.none);
      return;
    }

    try {
      // 1. Kiểm tra bảng residents_apartments
      final res = await SupabaseConfig.client
          .from('residents_apartments')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        state = ResidentLinkStatus(status: LinkStatus.linked);
        return;
      }

      // 2. Nếu chưa liên kết, kiểm tra yêu cầu đang pending/rejected
      final req = await SupabaseConfig.client
          .from('apartment_link_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (req != null) {
        if (req['status'] == 'pending') {
          state = ResidentLinkStatus(status: LinkStatus.pending);
        } else if (req['status'] == 'rejected') {
          state = ResidentLinkStatus(status: LinkStatus.rejected);
        } else if (req['status'] == 'approved') {
          state = ResidentLinkStatus(status: LinkStatus.linked);
        }
        return;
      }

      state = ResidentLinkStatus(status: LinkStatus.none);
    } catch (e, st) {
      AppLogger.e('Error in checkStatus: $e', e, st);
      state = ResidentLinkStatus(status: LinkStatus.none);
    }
  }

  Future<void> submitRequest(String code, String relationRole) async {
    try {
      state = ResidentLinkStatus(status: LinkStatus.loading);
      
      // Lấy ID căn hộ từ mã (code) (Chuyển sang viết hoa để không bị lỗi A101 vs a101)
      final res = await SupabaseConfig.client
          .rpc('find_apartment_by_code', params: {'p_code': code.toUpperCase()});
          
      if (res == null || (res as List).isEmpty) {
        throw Exception('Không tìm thấy căn hộ với mã này.');
      }
      
      final apartmentId = res[0]['id'];
      final userId = SupabaseConfig.client.auth.currentUser!.id;
      
      // Xóa các request cũ bị rejected trước khi tạo mới
      await SupabaseConfig.client
          .from('apartment_link_requests')
          .delete()
          .eq('user_id', userId)
          .eq('status', 'rejected');

      await SupabaseConfig.client.from('apartment_link_requests').insert({
        'user_id': userId,
        'apartment_id': apartmentId,
        'requested_relation_role': relationRole,
        'status': 'pending',
      });
      
      await checkStatus();
    } on PostgrestException catch (pe) {
      await checkStatus();
      throw Exception('Lỗi CSDL: ${pe.message}');
    } catch (e) {
      await checkStatus(); // Lấy lại state cũ nếu lỗi
      rethrow;
    }
  }

  void resetToForm() {
    state = ResidentLinkStatus(status: LinkStatus.none);
  }
}
