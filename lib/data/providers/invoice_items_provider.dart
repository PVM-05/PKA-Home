import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_config.dart';

/// Stream lắng nghe thay đổi các mục chi phí (invoice_items) theo mã hóa đơn
final invoiceItemsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, invoiceId) {
  return SupabaseConfig.client
      .from('invoice_items')
      .stream(primaryKey: ['id'])
      .eq('invoice_id', invoiceId);
});

/// Provider tải chi tiết danh sách các mục chi phí của một hóa đơn
/// Dùng chung trung lập cho cả màn hình Cư dân và Ban Quản lý (xem / sửa hóa đơn)
final invoiceItemsDetailProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, invoiceId) async {
  // Lắng nghe thay đổi realtime của invoice items
  ref.watch(invoiceItemsStreamProvider(invoiceId));
  
  final response = await SupabaseConfig.client
      .from('invoice_items')
      .select()
      .eq('invoice_id', invoiceId)
      .order('created_at', ascending: true);
  
  return List<Map<String, dynamic>>.from(response);
});

/// Alias thân thiện giữ tương thích ngược hoàn toàn
final invoiceDetailProvider = invoiceItemsDetailProvider;
