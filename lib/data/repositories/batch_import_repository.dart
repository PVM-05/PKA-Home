import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/batch_import_model.dart';

class BatchImportRepository {
  final SupabaseClient? _injectedClient;

  BatchImportRepository({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  /// Lấy danh sách toàn bộ mã căn hộ hiện có trong tòa nhà để kiểm tra tồn tại
  Future<Set<String>> fetchExistingApartmentCodes(String buildingId) async {
    final client = _client;
    if (client == null) return <String>{};

    try {
      final response = await client
          .from('apartments')
          .select('code')
          .eq('building_id', buildingId);

      final codes = <String>{};
      for (final row in (response as List)) {
        final code = row['code']?.toString().toUpperCase().trim();
        if (code != null && code.isNotEmpty) {
          codes.add(code);
        }
      }
      return codes;
    } catch (_) {
      // Fallback nếu chưa có building_id hoặc môi trường test
      try {
        final fallbackRes = await client.from('apartments').select('code');
        final codes = <String>{};
        for (final row in (fallbackRes as List)) {
          final code = row['code']?.toString().toUpperCase().trim();
          if (code != null && code.isNotEmpty) {
            codes.add(code);
          }
        }
        return codes;
      } catch (_) {
        return <String>{};
      }
    }
  }

  /// Gọi RPC batch_import_apartments để lưu danh sách căn hộ theo lô
  Future<Map<String, dynamic>> importApartments({
    required String buildingId,
    required List<ApartmentImportItem> apartments,
  }) async {
    final client = _client;
    if (client == null) {
      return {
        'success': false,
        'total_imported': 0,
        'message': 'Không thể kết nối đến máy chủ Supabase. Vui lòng kiểm tra kết nối mạng và thử lại.',
      };
    }

    final payload = mapApartmentsPayload(apartments);
    final response = await client.rpc(
      'batch_import_apartments',
      params: {
        'p_building_id': buildingId,
        'p_apartments': payload,
      },
    );
    return parseRpcResult(response);
  }

  /// Gọi RPC batch_import_residents để lưu cư dân và gán quan hệ căn hộ
  Future<Map<String, dynamic>> importResidents({
    required String buildingId,
    required List<ResidentImportItem> residents,
  }) async {
    final client = _client;
    if (client == null) {
      return {
        'success': false,
        'total_imported': 0,
        'message': 'Không thể kết nối đến máy chủ Supabase. Vui lòng kiểm tra kết nối mạng và thử lại.',
      };
    }

    final payload = mapResidentsPayload(residents);
    final response = await client.rpc(
      'batch_import_residents',
      params: {
        'p_building_id': buildingId,
        'p_residents': payload,
      },
    );
    return parseRpcResult(response);
  }

  /// Gọi RPC batch_import_meter_readings để lưu chỉ số điện nước theo lô
  Future<Map<String, dynamic>> importMeterReadings({
    required String buildingId,
    required List<MeterReadingImportItem> readings,
  }) async {
    final client = _client;
    if (client == null) {
      return {
        'success': false,
        'total_imported': 0,
        'message': 'Không thể kết nối đến máy chủ Supabase. Vui lòng kiểm tra kết nối mạng và thử lại.',
      };
    }

    final payload = mapMeterReadingsPayload(readings);
    final response = await client.rpc(
      'batch_import_meter_readings',
      params: {
        'p_building_id': buildingId,
        'p_readings': payload,
      },
    );
    return parseRpcResult(response);
  }

  // --- HÀM ÁNH XẠ VÀ XỬ LÝ DỮ LIỆU ---

  List<Map<String, dynamic>> mapApartmentsPayload(List<ApartmentImportItem> items) {
    return items.map((i) => i.toJson()).toList();
  }

  List<Map<String, dynamic>> mapResidentsPayload(List<ResidentImportItem> items) {
    return items.map((i) => i.toJson()).toList();
  }

  List<Map<String, dynamic>> mapMeterReadingsPayload(List<MeterReadingImportItem> items) {
    return items.map((i) => i.toJson()).toList();
  }

  Map<String, dynamic> parseRpcResult(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {
      'success': true,
      'message': 'Đã hoàn tất thao tác nhập dữ liệu',
    };
  }
}
