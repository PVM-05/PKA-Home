import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/network_error_handler.dart';
import 'auth_provider.dart';

enum LinkStatus { loading, linked, pending, rejected, none }

class ResidentLinkStatus {
  final LinkStatus status;
  final String? requestId;
  final String? apartmentCode;
  
  ResidentLinkStatus({
    required this.status,
    this.requestId,
    this.apartmentCode,
  });
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
    final code = json['code'] as String? ?? '';
    final building = (json['building_code'] as String?) ??
        (code.isNotEmpty ? code[0].toUpperCase() : 'A');
    final floor = ((json['floor_number'] as int?) ??
        (code.length >= 3 ? int.tryParse(code.substring(1, 3)) ?? 1 : 1)).toString();

    return ParsedApartment(
      code: code,
      building: building,
      floor: floor,
      room: code,
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
  String? get _effectiveUserId => _userId ?? _supabase.auth.currentUser?.id;

  ResidentLinkNotifier(this._userId, [this._client]) : super(ResidentLinkStatus(status: LinkStatus.loading)) {
    if (_effectiveUserId != null) {
      checkStatus();
      _setupRealtime();
    } else {
      state = ResidentLinkStatus(status: LinkStatus.none);
    }
  }

  void _setupRealtime() {
    final uid = _effectiveUserId;
    if (uid == null) return;

    try {
      _reqChannel = _supabase
          .channel('apartment_link_requests_$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'apartment_link_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: (payload) {
              checkStatus();
            },
          )
          .subscribe();

      _aptChannel = _supabase
          .channel('residents_apartments_$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'residents_apartments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
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
    final uid = _effectiveUserId;
    if (uid == null) {
      state = ResidentLinkStatus(status: LinkStatus.none);
      return;
    }

    try {
      // 1. Kiểm tra bảng residents_apartments (nếu đã liên kết thành công)
      final res = await _supabase
          .from('residents_apartments')
          .select()
          .eq('user_id', uid)
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
          .select('*, apartments(code)')
          .eq('user_id', uid)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();

      if (pendingReq != null) {
        final aptCode = (pendingReq['apartments'] as Map?)?['code'] as String?;
        state = ResidentLinkStatus(
          status: LinkStatus.pending,
          requestId: pendingReq['id'] as String?,
          apartmentCode: aptCode,
        );
        return;
      }

      // 3. Nếu không có pending, kiểm tra yêu cầu gần nhất
      final req = await _supabase
          .from('apartment_link_requests')
          .select()
          .eq('user_id', uid)
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

  Future<void> cancelPendingRequest([String? reqId]) async {
    final uid = _effectiveUserId;
    if (uid == null) {
      throw const AppException('Vui lòng đăng nhập để thực hiện thao tác này.');
    }

    try {
      state = ResidentLinkStatus(status: LinkStatus.loading);
      String? targetId = reqId ?? state.requestId;
      if (targetId == null) {
        final pending = await _supabase
            .from('apartment_link_requests')
            .select('id')
            .eq('user_id', uid)
            .eq('status', 'pending')
            .limit(1)
            .maybeSingle();
        if (pending != null) {
          targetId = pending['id'] as String?;
        }
      }

      if (targetId == null) {
        state = ResidentLinkStatus(status: LinkStatus.none);
        return;
      }

      final res = await _supabase.rpc('cancel_apartment_link_request', params: {
        'p_request_id': targetId,
      });

      final resMap = res as Map<String, dynamic>;
      if (resMap['success'] != true) {
        throw AppException(resMap['message'] ?? 'Không thể hủy yêu cầu liên kết.');
      }

      await checkStatus();
    } on PostgrestException catch (pe) {
      await checkStatus();
      throw AppException(NetworkErrorHandler.getMessage(pe));
    } catch (e) {
      await checkStatus();
      rethrow;
    }
  }

  Future<void> submitRequest(String code, String relationRole) async {
    final uid = _effectiveUserId;
    if (uid == null) {
      throw const AppException('Vui lòng đăng nhập để thực hiện thao tác này.');
    }

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      throw const AppException('Vui lòng nhập mã căn hộ.');
    }

    try {
      state = ResidentLinkStatus(status: LinkStatus.loading);

      // 1. Ưu tiên gọi RPC submit_apartment_link_request nguyên tử
      try {
        final rpcRes = await _supabase.rpc('submit_apartment_link_request', params: {
          'p_apartment_code': cleanCode,
          'p_relation_role': relationRole,
        });

        if (rpcRes != null && rpcRes is Map && rpcRes['success'] == true) {
          await checkStatus();
          return;
        }
      } on PostgrestException catch (pe) {
        // Lỗi nghiệp vụ từ RPC (căn hộ không tồn tại, đang chờ duyệt,...) -> hiển thị trực tiếp
        if (pe.message.isNotEmpty && !pe.message.contains('function') && !pe.message.contains('not found')) {
          await checkStatus();
          throw AppException(NetworkErrorHandler.getMessage(pe));
        }
      } catch (e) {
        if (e is AppException) rethrow;
      }

      // 2. Dự phòng an toàn (Fallback): Thao tác client trực tiếp
      final existingPending = await _supabase
          .from('apartment_link_requests')
          .select('id')
          .eq('user_id', uid)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();

      if (existingPending != null) {
        await checkStatus();
        throw const AppException('Bạn đang có một yêu cầu liên kết đang chờ Ban quản lý phê duyệt. Vui lòng chờ xử lý trước khi gửi yêu cầu mới.');
      }
      
      // Lấy ID căn hộ từ mã (code)
      final res = await _supabase
          .rpc('find_apartment_by_code', params: {'p_code': cleanCode});
          
      if (res == null || (res as List).isEmpty) {
        throw AppException('Không tìm thấy căn hộ với mã $cleanCode trong hệ thống.');
      }
      
      final apartmentId = res[0]['id'];
      
      // Xóa các request cũ bị rejected/cancelled trước khi tạo mới
      try {
        await _supabase
            .from('apartment_link_requests')
            .delete()
            .eq('user_id', uid)
            .inFilter('status', ['rejected', 'cancelled']);
      } catch (_) {}

      await _supabase.from('apartment_link_requests').insert({
        'user_id': uid,
        'apartment_id': apartmentId,
        'requested_relation_role': relationRole,
        'status': 'pending',
      });
      
      await checkStatus();
    } on PostgrestException catch (pe) {
      await checkStatus();
      if (pe.code == '23505') {
        throw const AppException('Bạn đang có một yêu cầu liên kết đang chờ duyệt hoặc đã gửi yêu cầu cho căn hộ này.');
      }
      throw AppException(NetworkErrorHandler.getMessage(pe));
    } catch (e) {
      await checkStatus(); // Lấy lại state cũ nếu lỗi
      rethrow;
    }
  }

  void resetToForm() {
    state = ResidentLinkStatus(status: LinkStatus.none);
  }
}

