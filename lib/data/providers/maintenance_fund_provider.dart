import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/maintenance_fund_model.dart';

final maintenanceFundProvider = FutureProvider<MaintenanceFundModel?>((ref) async {
  try {
    final response = await SupabaseConfig.client
        .from('maintenance_funds')
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return MaintenanceFundModel.fromJson(response);
  } catch (_) {
    return null;
  }
});
