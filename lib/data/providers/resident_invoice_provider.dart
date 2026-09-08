import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_config.dart';
import '../../../data/models/invoice_model.dart';

final _invoicesStreamProvider = StreamProvider((ref) {
  final user = SupabaseConfig.client.auth.currentUser;
  if (user == null) return const Stream.empty();

  return Stream.fromFuture(
    SupabaseConfig.client
        .from('residents_apartments')
        .select('apartment_id')
        .eq('user_id', user.id)
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

final _invoiceItemsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, invoiceId) => SupabaseConfig.client.from('invoice_items').stream(primaryKey: ['id']).eq('invoice_id', invoiceId));

final residentInvoiceDetailProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, invoiceId) async {
  // Lắng nghe thay đổi của invoice items
  ref.watch(_invoiceItemsStreamProvider(invoiceId));
  
  final response = await SupabaseConfig.client
      .from('invoice_items')
      .select()
      .eq('invoice_id', invoiceId)
      .order('created_at', ascending: true);
  
  return List<Map<String, dynamic>>.from(response);
});

/// Provider chi tiết hóa đơn (invoice_items) dùng chung cho cả Cư dân và Ban Quản lý
final invoiceDetailProvider = residentInvoiceDetailProvider;

class ResidentInvoiceService {
  static Future<void> confirmPayment(WidgetRef ref, String invoiceId, {SupabaseClient? client}) async {
    final supabase = client ?? SupabaseConfig.client;
    await supabase.rpc('confirm_payment', params: {'p_invoice_id': invoiceId});
    ref.invalidate(residentInvoiceProvider);
  }
}
