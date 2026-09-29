import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_config.dart';
import '../../../data/models/invoice_model.dart';
import 'auth_provider.dart';
import 'invoice_items_provider.dart';
import 'resident_apartment_provider.dart';
export 'invoice_items_provider.dart' show invoiceItemsDetailProvider, invoiceDetailProvider;

final _invoicesStreamProvider = StreamProvider((ref) {
  final selectedAptId = ref.watch(selectedApartmentIdProvider);
  if (selectedAptId != null && selectedAptId.isNotEmpty) {
    return SupabaseConfig.client
        .from('invoices')
        .stream(primaryKey: ['id'])
        .eq('apartment_id', selectedAptId);
  }

  final userId = ref.watch(authProvider).valueOrNull?.id;
  if (userId == null) return const Stream.empty();

  return Stream.fromFuture(
    SupabaseConfig.client
        .from('residents_apartments')
        .select('apartment_id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle(),
  ).asyncExpand((linkData) {
    if (linkData == null || linkData['apartment_id'] == null) {
      return const Stream.empty();
    }
    final aptId = linkData['apartment_id'] as String;
    return SupabaseConfig.client
        .from('invoices')
        .stream(primaryKey: ['id'])
        .eq('apartment_id', aptId);
  });
});

final residentInvoiceProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  // Đăng ký lắng nghe Stream Realtime từ Supabase
  ref.watch(_invoicesStreamProvider);
  
  final response = await SupabaseConfig.client
      .from('invoices')
      .select('*, apartments(*)')
      .order('created_at', ascending: false);
  
  return (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
});


/// Delegate sang provider trung lập
final residentInvoiceDetailProvider = invoiceItemsDetailProvider;

class ResidentInvoiceService {
  static Future<void> confirmPayment(WidgetRef ref, String invoiceId, {SupabaseClient? client}) async {
    final supabase = client ?? SupabaseConfig.client;
    await supabase.rpc('confirm_payment', params: {'p_invoice_id': invoiceId});
    ref.invalidate(residentInvoiceProvider);
  }
}
