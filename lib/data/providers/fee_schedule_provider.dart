import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fee_schedule_model.dart';
import '../repositories/fee_schedule_repository.dart';

final feeScheduleRepositoryProvider = Provider<FeeScheduleRepository>((ref) {
  return FeeScheduleRepository();
});

final activeFeeSchedulesProvider = FutureProvider<List<FeeScheduleModel>>((ref) async {
  final repo = ref.watch(feeScheduleRepositoryProvider);
  return repo.getActiveFeeSchedules();
});

final feeScheduleMapProvider = FutureProvider<Map<String, double>>((ref) async {
  final schedules = await ref.watch(activeFeeSchedulesProvider.future);
  return {
    for (final s in schedules) s.feeType: s.unitPrice,
  };
});
