import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/paginated_list.dart';
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

/// Notifier quản lý danh sách hóa đơn có phân trang (Pagination & Infinite Scroll)
class ResidentInvoicePaginatedNotifier extends StateNotifier<AsyncValue<PaginatedList<InvoiceModel>>> {
  final String? _apartmentId;
  static const int _pageSize = 20;

  ResidentInvoicePaginatedNotifier({required String? apartmentId})
      : this._(apartmentId);

  ResidentInvoicePaginatedNotifier._(this._apartmentId)
      : super(const AsyncValue.loading()) {
    fetchInitial();
  }

  Future<void> fetchInitial() async {
    try {
      state = const AsyncValue.loading();
      var query = SupabaseConfig.client
          .from('invoices')
          .select('*, apartments(*)');
      if (_apartmentId != null && _apartmentId.isNotEmpty) {
        query = query.eq('apartment_id', _apartmentId);
      }
      final response = await query
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);
      final items = (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
      state = AsyncValue.data(
        PaginatedList<InvoiceModel>(
          items: items,
          page: 1,
          pageSize: _pageSize,
          hasMore: items.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      var query = SupabaseConfig.client
          .from('invoices')
          .select('*, apartments(*)');
      if (_apartmentId != null && _apartmentId.isNotEmpty) {
        query = query.eq('apartment_id', _apartmentId);
      }
      final response = await query
          .order('created_at', ascending: false)
          .range(current.items.length, current.items.length + _pageSize - 1);
      final newItems = (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
      state = AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...newItems],
          page: current.page + 1,
          hasMore: newItems.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final residentInvoicePaginatedProvider = StateNotifierProvider.autoDispose<
    ResidentInvoicePaginatedNotifier, AsyncValue<PaginatedList<InvoiceModel>>>((ref) {
  ref.watch(_invoicesStreamProvider);
  final selectedAptId = ref.watch(selectedApartmentIdProvider);
  return ResidentInvoicePaginatedNotifier(apartmentId: selectedAptId);
});

/// Giữ nguyên tương thích ngược 100% cho các màn hình và test hiện có
final residentInvoiceProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  final paginated = ref.watch(residentInvoicePaginatedProvider);
  return paginated.when(
    data: (p) => p.items,
    loading: () => const [],
    error: (e, st) => throw e,
  );
});

/// Toàn bộ hóa đơn chưa thanh toán của căn hộ (không bị cắt ở limit 20 của phân trang)
final residentUnpaidInvoicesProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  ref.watch(_invoicesStreamProvider);
  final selectedAptId = ref.watch(selectedApartmentIdProvider);
  if (selectedAptId == null || selectedAptId.isEmpty) return [];

  final response = await SupabaseConfig.client
      .from('invoices')
      .select('*, apartments(*)')
      .eq('apartment_id', selectedAptId)
      .inFilter('status', ['unpaid', 'pending_confirmation'])
      .order('due_date', ascending: true);

  return (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
});

/// Delegate sang provider trung lập
final residentInvoiceDetailProvider = invoiceItemsDetailProvider;

class ResidentInvoiceService {
  static Future<void> confirmPayment(WidgetRef ref, String invoiceId, {SupabaseClient? client}) async {
    final supabase = client ?? SupabaseConfig.client;
    await supabase.rpc('confirm_payment', params: {'p_invoice_id': invoiceId});
    ref.invalidate(residentInvoicePaginatedProvider);
    ref.invalidate(residentInvoiceProvider);
  }
}
