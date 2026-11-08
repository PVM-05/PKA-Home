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
  group('ResidentInvoiceService Tests', () {
    late MockSupabaseClient mockSupabase;
    late MockWidgetRef mockRef;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockRef = MockWidgetRef();
    });

    test('gọi RPC confirm_payment và làm mới residentInvoiceProvider', () async {
      final fakeBuilder = FakePostgrestFilterBuilder(null);

      when(() => mockSupabase.rpc('confirm_payment', params: {
        'p_invoice_id': 'inv-101',
      })).thenAnswer((_) => fakeBuilder);

      await ResidentInvoiceService.confirmPayment(
        mockRef,
        'inv-101',
        client: mockSupabase,
      );

      verify(() => mockSupabase.rpc('confirm_payment', params: {'p_invoice_id': 'inv-101'})).called(1);
      verify(() => mockRef.invalidate(residentInvoiceProvider)).called(1);
    });
  });
}
