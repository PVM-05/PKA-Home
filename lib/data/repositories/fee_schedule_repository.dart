import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/fee_schedule_model.dart';

class FeeScheduleRepository {
  final SupabaseClient _client;

  FeeScheduleRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

  Future<List<FeeScheduleModel>> getActiveFeeSchedules({DateTime? date}) async {
    final targetDate = (date ?? DateTime.now()).toIso8601String().split('T').first;
    final response = await _client
        .from('fee_schedules')
        .select()
        .eq('is_active', true)
        .lte('effective_from', targetDate)
        .order('effective_from', ascending: false);

    final list = (response as List<dynamic>)
        .map((e) => FeeScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final Map<String, FeeScheduleModel> latestByType = {};
    for (final item in list) {
      if (item.effectiveTo != null) {
        final toDate = item.effectiveTo!.toIso8601String().split('T').first;
        if (toDate.compareTo(targetDate) < 0) continue;
      }
      latestByType.putIfAbsent(item.feeType, () => item);
    }
    return latestByType.values.toList();
  }

  Future<double> getUnitPrice(String feeType, {DateTime? date, double fallbackPrice = 0.0}) async {
    try {
      final schedules = await getActiveFeeSchedules(date: date);
      final match = schedules.where((s) => s.feeType == feeType).firstOrNull;
      return match?.unitPrice ?? fallbackPrice;
    } catch (_) {
      return fallbackPrice;
    }
  }
}
