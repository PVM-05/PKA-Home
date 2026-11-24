import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Interface nguồn dữ liệu phục vụ các quyền PDPL
abstract class DataPrivacySource {
  Future<List<Map<String, dynamic>>> fetchApartments(String userId);
  Future<List<Map<String, dynamic>>> fetchVehicles(String userId);
  Future<List<Map<String, dynamic>>> fetchIssues(String userId);
  Future<List<Map<String, dynamic>>> fetchInvoices(List<String> apartmentIds);
  Future<void> recordAuditLog({
    required String actorId,
    required String action,
    required String entityName,
    required String entityId,
    required Map<String, dynamic> details,
  });
}

/// Nguồn dữ liệu thực tế kết nối cơ sở dữ liệu Supabase PostgreSQL
class SupabaseDataPrivacySource implements DataPrivacySource {
  final SupabaseClient? _client;

  SupabaseDataPrivacySource([this._client]);

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchApartments(String userId) async {
    final res = await _db
        .from('residents_apartments')
        .select('id, relation_role, created_at, apartments(id, code, area)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(res as List);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchVehicles(String userId) async {
    final res = await _db
        .from('vehicles')
        .select('id, license_plate, vehicle_type, status, created_at')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(res as List);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchIssues(String userId) async {
    final res = await _db
        .from('issue_reports')
        .select('id, title, description, status, created_at')
        .eq('reporter_id', userId);
    return List<Map<String, dynamic>>.from(res as List);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInvoices(
    List<String> apartmentIds,
  ) async {
    if (apartmentIds.isEmpty) return [];
    final res = await _db
        .from('invoices')
        .select('id, period, total_amount, status, due_date, created_at')
        .inFilter('apartment_id', apartmentIds);
    return List<Map<String, dynamic>>.from(res as List);
  }

  @override
  Future<void> recordAuditLog({
    required String actorId,
    required String action,
    required String entityName,
    required String entityId,
    required Map<String, dynamic> details,
  }) async {
    await _db.from('audit_logs').insert({
      'actor_id': actorId,
      'action': action,
      'entity_name': entityName,
      'entity_id': entityId,
      'details': details,
    });
  }
}

/// Dịch vụ Thực thi Quyền Chủ thể Dữ liệu theo Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15
class DataPrivacyService {
  final DataPrivacySource _source;

  DataPrivacyService({DataPrivacySource? source})
      : _source = source ?? SupabaseDataPrivacySource();

  /// Điều 15 Luật 91/2025/QH15: Quyền xuất dữ liệu (Data Portability)
  /// Trích xuất toàn bộ dữ liệu cá nhân của cư dân thành cấu trúc JSON có chữ ký toàn vẹn (Integrity Hash)
  Future<Map<String, dynamic>> exportUserData({
    required UserModel user,
  }) async {
    // 1. Căn hộ
    List<Map<String, dynamic>> apartments = [];
    try {
      apartments = await _source.fetchApartments(user.id);
    } catch (e) {
      debugPrint('Export apartments fallback: $e');
    }

    // 2. Phương tiện
    List<Map<String, dynamic>> vehicles = [];
    try {
      vehicles = await _source.fetchVehicles(user.id);
    } catch (e) {
      debugPrint('Export vehicles fallback: $e');
    }

    // 3. Phản ánh
    List<Map<String, dynamic>> issues = [];
    try {
      issues = await _source.fetchIssues(user.id);
    } catch (e) {
      debugPrint('Export issues fallback: $e');
    }

    // 4. Hóa đơn
    List<Map<String, dynamic>> invoices = [];
    try {
      final aptIds = apartments
          .map((a) => (a['apartments'] as Map<String, dynamic>?)?['id'])
          .whereType<String>()
          .toList();
      invoices = await _source.fetchInvoices(aptIds);
    } catch (e) {
      debugPrint('Export invoices fallback: $e');
    }

    // 5. Đóng gói payload xuất dữ liệu cá nhân theo quy chuẩn PDPL
    final rawPayload = {
      'export_metadata': {
        'platform': 'Vivona Commercial PropTech SaaS',
        'export_standard': 'PDPL_VN_91_2025_QH15_ART15',
        'exported_at': DateTime.now().toIso8601String(),
        'dpo_contact': 'security@vivona.vn',
      },
      'subject_identity': {
        'user_id': user.id,
        'full_name': user.fullName,
        'phone': user.phone ?? '',
        'role': user.role,
        'account_status': user.isLocked ? 'LOCKED' : 'ACTIVE',
      },
      'apartments': apartments,
      'registered_vehicles': vehicles,
      'service_invoices': invoices,
      'issue_reports': issues,
    };

    final jsonString = jsonEncode(rawPayload);
    final integrityHash = sha256.convert(utf8.encode(jsonString)).toString();

    final completePayload = {
      ...rawPayload,
      'integrity_verification': {
        'algorithm': 'SHA-256',
        'hash': integrityHash,
        'tamper_evident_notice':
            'Dữ liệu này được chứng thực và bảo vệ theo Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15.',
      },
    };

    // Ghi nhật ký xuất dữ liệu vào audit_logs
    try {
      await _source.recordAuditLog(
        actorId: user.id,
        action: 'PDPL_DATA_EXPORTED',
        entityName: 'users',
        entityId: user.id,
        details: {
          'integrity_hash': integrityHash,
          'apartments_count': apartments.length,
          'vehicles_count': vehicles.length,
          'invoices_count': invoices.length,
        },
      );
    } catch (e) {
      debugPrint('Audit log data export write skipped: $e');
    }

    return completePayload;
  }

  /// Ghi file xuất dữ liệu ra đĩa và kích hoạt chia sẻ / tải về
  Future<String> saveAndShareExportFile({
    required Map<String, dynamic> exportData,
    required String userName,
  }) async {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(exportData);
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedName = userName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final filePath = '${directory.path}/vivona_pdpl_data_${sanitizedName}_$timestamp.json';

    final file = File(filePath);
    await file.writeAsString(prettyJson, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Sao kê dữ liệu cá nhân Vivona (PDPL)',
        text: 'Bản sao kê dữ liệu cá nhân cư dân theo Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15.',
      ),
    );

    return filePath;
  }

  /// Điều 16 & 17 Luật 91/2025/QH15: Quyền yêu cầu xóa / hạn chế xử lý dữ liệu (Right to be Forgotten)
  /// Gửi yêu cầu đóng băng và ẩn danh hóa danh tính PII lên Ban Quản Lý và Ban Quản Trị
  Future<bool> requestDataAnonymization({
    required String userId,
    required String reason,
    String? notes,
  }) async {
    try {
      await _source.recordAuditLog(
        actorId: userId,
        action: 'PDPL_ANONYMIZATION_REQUEST',
        entityName: 'users',
        entityId: userId,
        details: {
          'reason': reason,
          'notes': notes ?? '',
          'legal_basis':
              'Luật Bảo vệ dữ liệu cá nhân số 91/2025/QH15 (Điều 16 & 17)',
          'status': 'PENDING_DPO_REVIEW',
          'sla_hours': 72,
          'retention_exception':
              'Chứng từ kế toán và hóa đơn lưu giữ 5 năm theo Luật Kế toán 2015.',
        },
      );

      return true;
    } catch (e) {
      debugPrint('Lỗi gửi yêu cầu đóng băng dữ liệu: $e');
      rethrow;
    }
  }
}

/// Riverpod provider cho DataPrivacyService
final dataPrivacyServiceProvider = Provider<DataPrivacyService>((ref) {
  return DataPrivacyService();
});
