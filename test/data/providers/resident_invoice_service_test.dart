import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockWidgetRef extends Mock implements WidgetRef {}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final dynamic _result;
  FakePostgrestFilterBuilder(this._result);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) {
    return Future.value(_result).then(onValue, onError: onError);
  }
}

void main() {
  group('ResidentInvoiceService.simulatePayment Tests', () {
    late MockSupabaseClient mockSupabase;
    late MockWidgetRef mockRef;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockRef = MockWidgetRef();
    });

    test('gọi RPC simulate_invoice_payment và trả về kết quả thành công', () async {
      final fakeBuilder = FakePostgrestFilterBuilder({
        'success': true,
        'status': 'paid',
        'transaction_code': 'PAY-20261005-00125',
        'amount': 500000.0,
      });

      when(() => mockSupabase.rpc('simulate_invoice_payment', params: {
        'p_invoice_id': 'inv-101',
        'p_outcome': 'SUCCESS',
      })).thenAnswer((_) => fakeBuilder);

      final result = await ResidentInvoiceService.simulatePayment(
        ref: mockRef,
        invoiceId: 'inv-101',
        outcome: 'SUCCESS',
        client: mockSupabase,
      );

      expect(result['success'], isTrue);
      expect(result['status'], 'paid');
      expect(result['transaction_code'], 'PAY-20261005-00125');
      verify(() => mockRef.invalidate(residentInvoiceProvider)).called(1);
    });
  });
}
