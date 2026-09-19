import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/vehicle_model.dart';
import '../repositories/vehicle_repository.dart';
import 'auth_provider.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository();
});

/// Lấy ID căn hộ của cư dân đang đăng nhập
final residentApartmentIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return null;

  final res = await SupabaseConfig.client
      .from('residents_apartments')
      .select('apartment_id')
      .eq('user_id', user.id)
      .maybeSingle();

  if (res != null && res['apartment_id'] != null) {
    return res['apartment_id'] as String;
  }
  return null;
});

/// Stream danh sách phương tiện theo từng căn hộ cụ thể
final apartmentVehiclesProvider = StreamProvider.family<List<VehicleModel>, String>((ref, apartmentId) {
  final repo = ref.watch(vehicleRepositoryProvider);
  return repo.streamVehiclesByApartment(apartmentId);
});

/// Lắng nghe danh sách phương tiện của chính căn hộ cư dân hiện tại
final residentVehiclesProvider = StreamProvider<List<VehicleModel>>((ref) {
  final aptIdAsync = ref.watch(residentApartmentIdProvider);
  return aptIdAsync.when(
    data: (aptId) {
      if (aptId == null) return const Stream.empty();
      final repo = ref.watch(vehicleRepositoryProvider);
      return repo.streamVehiclesByApartment(aptId);
    },
    loading: () => const Stream.empty(),
    error: (e, st) => const Stream.empty(),
  );
});

/// Lấy số lượng xe máy và ô tô theo apartmentId phục vụ tự động điền hóa đơn
final apartmentVehicleCountsProvider = FutureProvider.family<Map<String, int>, String>((ref, apartmentId) async {
  final repo = ref.watch(vehicleRepositoryProvider);
  return await repo.getVehicleCounts(apartmentId);
});
