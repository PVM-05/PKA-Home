import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/guard_helper.dart';
import '../models/resident_activation_model.dart';

class ResidentActivationRepository {
  final SupabaseClient? _client;

  ResidentActivationRepository([this._client]);

  SupabaseClient? get _clientSafe {
    if (_client != null) return _client;
    try {
      if (SupabaseConfig.isConfigured) {
        return SupabaseConfig.client;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// BQL sinh mã kích hoạt cho toàn bộ cư dân chưa kích hoạt
  Future<Map<String, dynamic>> generateActivationCodes({
    required String buildingId,
  }) async {
    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ Supabase');
    }

    try {
      final response = await client.rpc(
        'generate_resident_activation_codes',
        params: {'p_building_id': buildingId},
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi sinh mã kích hoạt: $e',
      };
    }
  }

  /// Cư dân bước 1: Kiểm tra SĐT và Mã kích hoạt
  Future<Map<String, dynamic>> verifyActivationCode({
    required String phone,
    required String activationCode,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final cleanCode = activationCode.trim().toUpperCase();

    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ Supabase');
    }

    try {
      final response = await client.rpc(
        'verify_activation_code',
        params: {
          'p_phone': cleanPhone,
          'p_activation_code': cleanCode,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi máy chủ khi kiểm tra mã: $e',
      };
    }
  }

  /// Cư dân bước 2: Xác thực mã OTP
  Future<Map<String, dynamic>> verifyActivationOtp({
    required String phone,
    required String activationCode,
    required String otpCode,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final cleanCode = activationCode.trim().toUpperCase();
    final cleanOtp = otpCode.trim();

    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ Supabase');
    }

    try {
      final response = await client.rpc(
        'verify_activation_otp',
        params: {
          'p_phone': cleanPhone,
          'p_activation_code': cleanCode,
          'p_otp_code': cleanOtp,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi máy chủ khi xác thực OTP: $e',
      };
    }
  }

  /// Cư dân bước 3 & 4: Hoàn tất kích hoạt và liên kết auth_user_id
  Future<Map<String, dynamic>> completeActivation({
    required String phone,
    required String activationCode,
    required String otpCode,
    required String authUserId,
    String? email,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final cleanCode = activationCode.trim().toUpperCase();
    final cleanOtp = otpCode.trim();

    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ Supabase');
    }

    try {
      final response = await client.rpc(
        'complete_resident_activation',
        params: {
          'p_phone': cleanPhone,
          'p_activation_code': cleanCode,
          'p_otp_code': cleanOtp,
          'p_auth_user_id': authUserId,
          if (email != null && email.isNotEmpty) 'p_email': email.trim(),
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi máy chủ khi hoàn tất kích hoạt: $e',
      };
    }
  }

  /// BQL cấp lại mã kích hoạt mới cho một cư dân
  Future<Map<String, dynamic>> regenerateActivationCode({
    required String userId,
  }) async {
    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ Supabase');
    }

    try {
      final response = await client.rpc(
        'regenerate_resident_activation',
        params: {'p_user_id': userId},
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi máy chủ khi cấp lại mã: $e',
      };
    }
  }

  /// BQL thu hồi mã kích hoạt
  Future<Map<String, dynamic>> revokeActivation({
    required String activationId,
  }) async {
    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ Supabase');
    }

    try {
      final response = await client.rpc(
        'revoke_resident_activation',
        params: {'p_activation_id': activationId},
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi máy chủ khi thu hồi mã: $e',
      };
    }
  }

  /// BQL tra cứu danh sách kích hoạt theo tòa nhà
  Future<List<ResidentActivationModel>> fetchBuildingActivationList(
    String buildingId,
  ) async {
    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ Supabase');
    }

    try {
      final response = await client.rpc(
        'get_building_activation_list',
        params: {'p_building_id': buildingId},
      );

      if (response is List) {
        return response
            .map(
              (item) => ResidentActivationModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
