import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/models/amenity_inspection_model.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final dynamic _result;
  FakePostgrestFilterBuilder(this._result);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) {
    return Future.value(_result).then(onValue, onError: onError);
  }
}

void main() {
  group('AmenityBookingRepository Lifecycle & Deposit Tests', () {
    late MockSupabaseClient mockClient;
    late AmenityBookingRepository repository;

    setUp(() {
      mockClient = MockSupabaseClient();
      repository = AmenityBookingRepository(mockClient);
    });

    test('checkInTicket gọi đúng RPC check_in_amenity_ticket với p_qr_ticket_token', () async {
      final fakeBuilder = FakePostgrestFilterBuilder({
        'success': true,
        'message': 'Check-in thành công!',
        'booking_id': 'bk-01',
        'amenity_name': 'Hồ bơi vô cực',
        'apartment_code': 'A0110',
        'booker_name': 'Nguyễn Văn A',
      });

      when(() => mockClient.rpc('check_in_amenity_ticket', params: {
        'p_qr_ticket_token': '550e8400-e29b-41d4-a716-446655440000',
      })).thenAnswer((_) => fakeBuilder);

      final result = await repository.checkInTicket('550e8400-e29b-41d4-a716-446655440000');

      expect(result['success'], isTrue);
      expect(result['amenity_name'], 'Hồ bơi vô cực');
      expect(result['apartment_code'], 'A0110');
      verify(() => mockClient.rpc('check_in_amenity_ticket', params: {
        'p_qr_ticket_token': '550e8400-e29b-41d4-a716-446655440000',
      })).called(1);
    });

    test('inspectAndSettleDeposit gọi RPC inspect_and_settle_amenity_deposit với đầy đủ params', () async {
      final fakeBuilder = FakePostgrestFilterBuilder({
        'success': true,
        'message': 'Nghiệm thu đạt! Tiền cọc đã được xác nhận hoàn trả.',
        'deposit_status': 'refunded',
        'refund_amount': 500000.0,
        'forfeited_amount': 0.0,
      });

      const inspection = AmenityInspectionModel(
        bookingId: 'bk-bbq-01',
        inspectionResult: 'passed',
        forfeitedAmount: 0.0,
        notes: 'Sạch sẽ, đầy đủ thiết bị.',
        imageUrls: ['https://storage.pka-home.vn/bbq.jpg'],
      );

      when(() => mockClient.rpc('inspect_and_settle_amenity_deposit', params: {
        'p_booking_id': 'bk-bbq-01',
        'p_inspection_result': 'passed',
        'p_forfeited_amount': 0.0,
        'p_notes': 'Sạch sẽ, đầy đủ thiết bị.',
        'p_image_urls': ['https://storage.pka-home.vn/bbq.jpg'],
      })).thenAnswer((_) => fakeBuilder);

      final result = await repository.inspectAndSettleDeposit(inspection);

      expect(result['success'], isTrue);
      expect(result['deposit_status'], 'refunded');
      expect(result['refund_amount'], 500000.0);
      verify(() => mockClient.rpc('inspect_and_settle_amenity_deposit', params: any(named: 'params'))).called(1);
    });
  });
}
