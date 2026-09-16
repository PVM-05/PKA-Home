import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';
import 'auth_provider.dart';

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
  final userId = ref.watch(authProvider).valueOrNull?.id;
  return ResidentLinkNotifier(userId);
});

class ResidentLinkNotifier extends StateNotifier<ResidentLinkStatus> {
  final String? _userId;
  final SupabaseClient? _client;
  RealtimeChannel? _reqChannel;
  RealtimeChannel? _aptChannel;

  SupabaseClient get _supabase => _client ?? SupabaseConfig.client;

  ResidentLinkNotifier(this._userId, [this._client]) : super(ResidentLinkStatus(status: LinkStatus.loading)) {
    if (_userId != null) {
      checkStatus();
      _setupRealtime();
    } else {
      state = ResidentLinkStatus(status: LinkStatus.none);
    }
  }

  void _setupRealtime() {
    if (_userId == null) return;

    try {
      _reqChannel = _supabase
          .channel('apartment_link_requests_$_userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'apartment_link_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _userId,
            ),
            callback: (payload) {
              checkStatus();
            },
          )
          .subscribe();

      _aptChannel = _supabase
          .channel('residents_apartments_$_userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'residents_apartments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _userId,
            ),
            callback: (payload) {
              checkStatus();
            },
          )
          .subscribe();
    } catch (e, st) {
      AppLogger.e('Error in _setupRealtime: $e', e, st);
    }
  }

  @override
  void dispose() {
    try {
      if (_reqChannel != null) _supabase.removeChannel(_reqChannel!);
      if (_aptChannel != null) _supabase.removeChannel(_aptChannel!);
    } catch (_) {}
    super.dispose();
  }

  Future<void> checkStatus() async {
    if (_userId == null) {
      state = ResidentLinkStatus(status: LinkStatus.none);
      return;
    }

    try {
      // 1. Kiểm tra bảng residents_apartments (nếu đã liên kết thành công)
      final res = await _supabase
          .from('residents_apartments')
          .select()
          .eq('user_id', _userId)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        state = ResidentLinkStatus(status: LinkStatus.linked);
        return;
      }

      // 2. Nếu chưa liên kết, kiểm tra yêu cầu đang pending trước
      // (ưu tiên pending để không bị che khuất nếu có nhiều yêu cầu)
      final pendingReq = await _supabase
          .from('apartment_link_requests')
          .select()
          .eq('user_id', _userId)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();

      if (pendingReq != null) {
        state = ResidentLinkStatus(status: LinkStatus.pending);
        return;
      }

      // 3. Nếu không có pending, kiểm tra yêu cầu gần nhất
      final req = await _supabase
          .from('apartment_link_requests')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (req != null) {
        if (req['status'] == 'rejected') {
          state = ResidentLinkStatus(status: LinkStatus.rejected);
          return;
        } else if (req['status'] == 'approved') {
          state = ResidentLinkStatus(status: LinkStatus.linked);
          return;
        }
      }

      state = ResidentLinkStatus(status: LinkStatus.none);
    } catch (e, st) {
      AppLogger.e('Error in checkStatus: $e', e, st);
      state = ResidentLinkStatus(status: LinkStatus.none);
    }
  }

  Future<void> submitRequest(String code, String relationRole) async {
    if (_userId == null) {
      throw Exception('Vui lòng đăng nhập để thực hiện thao tác này.');
    }

    try {
      state = ResidentLinkStatus(status: LinkStatus.loading);

      // Chặn tạo yêu cầu mới nếu đã có một yêu cầu đang pending
      final existingPending = await _supabase
          .from('apartment_link_requests')
          .select('id')
          .eq('user_id', _userId)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();

      if (existingPending != null) {
        await checkStatus();
        throw Exception('Bạn đang có một yêu cầu liên kết đang chờ Ban quản lý phê duyệt. Vui lòng chờ xử lý trước khi gửi yêu cầu mới.');
      }
      
      // Lấy ID căn hộ từ mã (code) (Chuyển sang viết hoa để không bị lỗi A0110 vs a0110)
      final res = await _supabase
          .rpc('find_apartment_by_code', params: {'p_code': code.toUpperCase()});
          
      if (res == null || (res as List).isEmpty) {
        throw Exception('Không tìm thấy căn hộ với mã này.');
      }
      
      final apartmentId = res[0]['id'];
      
      // Xóa các request cũ bị rejected trước khi tạo mới (tránh trùng lặp)
      await _supabase
          .from('apartment_link_requests')
          .delete()
          .eq('user_id', _userId)
          .eq('status', 'rejected');

      await _supabase.from('apartment_link_requests').insert({
        'user_id': _userId,
        'apartment_id': apartmentId,
        'requested_relation_role': relationRole,
        'status': 'pending',
      });
      
      await checkStatus();
    } on PostgrestException catch (pe) {
      await checkStatus();
      if (pe.code == '23505') {
        throw Exception('Bạn đang có một yêu cầu liên kết đang chờ duyệt hoặc đã gửi yêu cầu cho căn hộ này.');
      }
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

