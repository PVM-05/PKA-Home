import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/meter_reading_submission_model.dart';

class MeterReadingRepository {
  final SupabaseClient _client;

  MeterReadingRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

  /// Cư dân gửi khai báo chỉ số điện nước mới
  Future<MeterReadingSubmissionModel> submitReading({
    required String apartmentId,
    required String userId,
    required String period,
    required double electricReading,
    required double waterReading,
    String? electricImageUrl,
    String? waterImageUrl,
  }) async {
    final response = await _client
        .from('meter_reading_submissions')
        .insert({
          'apartment_id': apartmentId,
          'submitted_by': userId,
          'period': period,
          'electric_reading': electricReading,
          'water_reading': waterReading,
          'electric_image_url': ?electricImageUrl,
          'water_image_url': ?waterImageUrl,
          'status': 'pending',
        })
        .select('*, apartments(code), users:users!meter_reading_submissions_submitted_by_fkey(full_name)')
        .single();

    return MeterReadingSubmissionModel.fromJson(response);
  }

  /// Lấy lịch sử các lần khai báo của căn hộ
  Future<List<MeterReadingSubmissionModel>> getMySubmissions(String apartmentId) async {
    final response = await _client
        .from('meter_reading_submissions')
        .select('*, apartments(code), users:users!meter_reading_submissions_submitted_by_fkey(full_name)')
        .eq('apartment_id', apartmentId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => MeterReadingSubmissionModel.fromJson(json))
        .toList();
  }

  /// Ban quản lý lấy toàn bộ danh sách chỉ số (lọc theo status nếu có)
  Future<List<MeterReadingSubmissionModel>> getAllSubmissions({String? status}) async {
    var query = _client
        .from('meter_reading_submissions')
        .select('*, apartments(code), users:users!meter_reading_submissions_submitted_by_fkey(full_name)');

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => MeterReadingSubmissionModel.fromJson(json))
        .toList();
  }

  /// Ban quản lý phê duyệt chỉ số và tùy chọn sinh hóa đơn tháng
  Future<Map<String, dynamic>> approveReading({
    required String submissionId,
    bool generateInvoice = false,
    DateTime? dueDate,
  }) async {
    final dueStr = (generateInvoice && dueDate != null)
        ? "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}"
        : null;

    final response = await _client.rpc('approve_meter_reading', params: {
      'p_submission_id': submissionId,
      'p_generate_invoice': generateInvoice,
      'p_due_date': dueStr,
    });

    return response as Map<String, dynamic>;
  }

  /// Ban quản lý từ chối chỉ số với lý do
  Future<Map<String, dynamic>> rejectReading({
    required String submissionId,
    required String reason,
  }) async {
    final response = await _client.rpc('reject_meter_reading', params: {
      'p_submission_id': submissionId,
      'p_reason': reason,
    });

    return response as Map<String, dynamic>;
  }

  /// Cư dân chỉnh sửa phiếu gửi chỉ số đang chờ duyệt
  Future<void> updatePendingSubmission({
    required String submissionId,
    required double electricReading,
    required double waterReading,
    String? electricImageUrl,
    String? waterImageUrl,
    bool clearElectricImage = false,
    bool clearWaterImage = false,
  }) async {
    final response = await _client.rpc('update_pending_meter_reading', params: {
      'p_submission_id': submissionId,
      'p_electric_reading': electricReading,
      'p_water_reading': waterReading,
      'p_electric_image_url': ?electricImageUrl,
      'p_water_image_url': ?waterImageUrl,
      'p_clear_electric_image': clearElectricImage,
      'p_clear_water_image': clearWaterImage,
    });
    final resMap = response as Map<String, dynamic>;
    if (resMap['success'] != true) {
      throw Exception(resMap['message'] ?? 'Không thể cập nhật chỉ số.');
    }
  }

  /// Cư dân hủy phiếu gửi chỉ số đang chờ duyệt
  Future<void> cancelPendingSubmission(String submissionId) async {
    final response = await _client.rpc('cancel_pending_meter_reading', params: {
      'p_submission_id': submissionId,
    });
    final resMap = response as Map<String, dynamic>;
    if (resMap['success'] != true) {
      throw Exception(resMap['message'] ?? 'Không thể hủy phiếu chỉ số.');
    }
  }
}

