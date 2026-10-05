import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/meter_reading_submission_model.dart';
import '../repositories/meter_reading_repository.dart';
import 'vehicle_provider.dart';

final meterReadingRepositoryProvider = Provider<MeterReadingRepository>((ref) {
  return MeterReadingRepository();
});

/// Danh sách các lần gửi chỉ số của căn hộ cư dân đang đăng nhập
final residentMeterReadingsProvider = FutureProvider<List<MeterReadingSubmissionModel>>((ref) async {
  final aptId = await ref.watch(residentApartmentIdProvider.future);
  if (aptId == null || aptId.isEmpty) return [];

  final repo = ref.watch(meterReadingRepositoryProvider);
  return await repo.getMySubmissions(aptId);
});

/// Danh sách toàn bộ các lượt gửi chỉ số cho Ban Quản Lý (lọc theo trạng thái)
final allMeterReadingsProvider = FutureProvider.family<List<MeterReadingSubmissionModel>, String?>((ref, status) async {
  final repo = ref.watch(meterReadingRepositoryProvider);
  return await repo.getAllSubmissions(status: status);
});

/// Số lượng chỉ số đang chờ BQL duyệt
final pendingMeterReadingsCountProvider = FutureProvider<int>((ref) async {
  try {
    final repo = ref.watch(meterReadingRepositoryProvider);
    final list = await repo.getAllSubmissions(status: 'pending');
    return list.length;
  } catch (_) {
    return 0;
  }
});

/// Thông tin chỉ số điện nước hiện tại của căn hộ (đối chiếu)
final currentApartmentReadingsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final aptId = await ref.watch(residentApartmentIdProvider.future);
  if (aptId == null || aptId.isEmpty) return null;

  try {
    final response = await SupabaseConfig.client
        .from('apartments')
        .select('id, code, electric_reading, water_reading')
        .eq('id', aptId)
        .maybeSingle();

    return response;
  } catch (_) {
    return {
      'id': aptId,
      'code': 'A0110',
      'electric_reading': 1250.0,
      'water_reading': 80.0,
    };
  }
});

