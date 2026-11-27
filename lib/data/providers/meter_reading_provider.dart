import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/meter_reading_submission_model.dart';
import '../models/building_utility_rate_model.dart';
import '../repositories/meter_reading_repository.dart';
import 'building_provider.dart';
import 'management_provider.dart';
import 'vehicle_provider.dart';

final meterReadingRepositoryProvider = Provider<MeterReadingRepository>((ref) {
  return MeterReadingRepository();
});

/// Danh sách biểu giá điện nước tòa nhà
final buildingUtilityRatesProvider =
    FutureProvider<List<BuildingUtilityRateModel>>((ref) async {
  final repo = ref.watch(meterReadingRepositoryProvider);
  final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
  final rates = await repo.getUtilityRates();
  if (effectiveBuildingId == null ||
      effectiveBuildingId.isEmpty ||
      !rates.any((r) => r.buildingId != null && r.buildingId!.isNotEmpty)) {
    return rates;
  }
  return rates
      .where((r) => r.buildingId == null || r.buildingId == effectiveBuildingId)
      .toList();
});

/// Danh sách các lần gửi chỉ số của căn hộ cư dân đang đăng nhập
final residentMeterReadingsProvider = FutureProvider<List<MeterReadingSubmissionModel>>((ref) async {
  final aptId = await ref.watch(residentApartmentIdProvider.future);
  if (aptId == null || aptId.isEmpty) return [];

  final repo = ref.watch(meterReadingRepositoryProvider);
  return await repo.getMySubmissions(aptId);
});

/// Danh sách toàn bộ các lượt gửi chỉ số cho Ban Quản Lý (lọc theo trạng thái & tòa nhà)
final allMeterReadingsProvider = FutureProvider.family<List<MeterReadingSubmissionModel>, String?>((ref, status) async {
  final repo = ref.watch(meterReadingRepositoryProvider);
  final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
  final list = await repo.getAllSubmissions(status: status);
  if (effectiveBuildingId == null || effectiveBuildingId.isEmpty) return list;
  final apts = await ref.watch(apartmentsProvider.future);
  final allowedAptIds = apts.map((a) => a.id).toSet();
  return list.where((s) => allowedAptIds.contains(s.apartmentId)).toList();
});

/// Danh sách các lượt gửi chỉ số bị gắn cờ bất thường (cho BQL kiểm tra kỹ thuật)
final anomalyMeterReadingsProvider = FutureProvider<List<MeterReadingSubmissionModel>>((ref) async {
  final repo = ref.watch(meterReadingRepositoryProvider);
  final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
  final list = await repo.getAllSubmissions(isAnomaly: true);
  if (effectiveBuildingId == null || effectiveBuildingId.isEmpty) return list;
  final apts = await ref.watch(apartmentsProvider.future);
  final allowedAptIds = apts.map((a) => a.id).toSet();
  return list.where((s) => allowedAptIds.contains(s.apartmentId)).toList();
});

/// Số lượng chỉ số đang chờ BQL duyệt
final pendingMeterReadingsCountProvider = FutureProvider<int>((ref) async {
  try {
    final repo = ref.watch(meterReadingRepositoryProvider);
    final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
    final list = await repo.getAllSubmissions(status: 'pending');
    if (effectiveBuildingId == null || effectiveBuildingId.isEmpty) return list.length;
    final apts = await ref.watch(apartmentsProvider.future);
    final allowedAptIds = apts.map((a) => a.id).toSet();
    return list.where((s) => allowedAptIds.contains(s.apartmentId)).length;
  } catch (_) {
    return 0;
  }
});

/// Số lượng chỉ số có cờ bất thường đang chờ duyệt
final pendingAnomalyCountProvider = FutureProvider<int>((ref) async {
  try {
    final repo = ref.watch(meterReadingRepositoryProvider);
    final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
    final list = await repo.getAllSubmissions(status: 'pending', isAnomaly: true);
    if (effectiveBuildingId == null || effectiveBuildingId.isEmpty) return list.length;
    final apts = await ref.watch(apartmentsProvider.future);
    final allowedAptIds = apts.map((a) => a.id).toSet();
    return list.where((s) => allowedAptIds.contains(s.apartmentId)).length;
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
    return null;
  }
});

/// Lịch sử tiêu thụ điện nước đã duyệt của căn hộ hiện tại (tối đa 6 kỳ) phục vụ biểu đồ xu hướng
final residentUtilityConsumptionHistoryProvider =
    FutureProvider.autoDispose<List<MeterReadingSubmissionModel>>((ref) async {
  final aptId = await ref.watch(residentApartmentIdProvider.future);
  if (aptId == null || aptId.isEmpty) return [];

  final repo = ref.watch(meterReadingRepositoryProvider);
  return await repo.getApprovedConsumptionHistory(aptId, limit: 6);
});
