import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import 'auth_provider.dart';

/// Provider danh sách các căn hộ gắn với tài khoản cư dân hiện tại
final residentApartmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider).value;
  if (user == null) return [];

  final response = await SupabaseConfig.client
      .from('residents_apartments')
      .select('relation_role, apartment_id, apartments(id, code, area, building_code, floor_number)')
      .eq('user_id', user.id);

  return List<Map<String, dynamic>>.from(response);
});

class SelectedApartmentNotifier extends StateNotifier<String?> {
  SelectedApartmentNotifier() : super(null);

  void selectApartment(String apartmentId) {
    state = apartmentId;
  }

  void selectDefaultIfEmpty(List<Map<String, dynamic>> apts) {
    if (state == null && apts.isNotEmpty) {
      final firstAptId = apts.first['apartment_id'] as String?;
      if (firstAptId != null) {
        state = firstAptId;
      }
    }
  }

  void clear() {
    state = null;
  }
}

final selectedApartmentIdProvider =
    StateNotifierProvider<SelectedApartmentNotifier, String?>((ref) {
  final notifier = SelectedApartmentNotifier();

  // Tự động gán căn hộ đầu tiên khi danh sách căn hộ tải xong (nếu chưa chọn)
  ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
    residentApartmentsProvider,
    (previous, next) {
      next.whenData((apts) {
        notifier.selectDefaultIfEmpty(apts);
      });
    },
  );

  return notifier;
});

/// Provider thông tin chi tiết căn hộ đang được chọn
final currentSelectedApartmentProvider = Provider<Map<String, dynamic>?>((ref) {
  final apts = ref.watch(residentApartmentsProvider).valueOrNull ?? [];
  final selectedId = ref.watch(selectedApartmentIdProvider);
  if (apts.isEmpty) return null;
  if (selectedId == null) return apts.first;
  return apts.firstWhere(
    (a) => a['apartment_id'] == selectedId,
    orElse: () => apts.first,
  );
});
