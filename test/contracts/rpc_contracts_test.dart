import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/contracts/contracts.dart';

void main() {
  group('1. Finance RPC Contracts Tests', () {
    test('RecordMaintenanceTransactionRequestDto sinh đúng tham số PostgreSQL p_*', () {
      const dto = RecordMaintenanceTransactionRequestDto(
        buildingId: 'bld-123',
        transactionType: 'THU',
        amount: 50000000.0,
        category: 'PhiBaoTriDinhKy',
        description: 'Thu phí quỹ bảo trì kỳ 11/2026',
        receiptUrl: 'https://storage/receipt.jpg',
        referenceId: 'ref-999',
        createdBy: 'user-admin',
      );

      final params = dto.toRpcParams();
      expect(params['p_building_id'], 'bld-123');
      expect(params['p_transaction_type'], 'THU');
      expect(params['p_amount'], 50000000.0);
      expect(params['p_category'], 'PhiBaoTriDinhKy');
      expect(params['p_description'], 'Thu phí quỹ bảo trì kỳ 11/2026');
      expect(params['p_receipt_url'], 'https://storage/receipt.jpg');
      expect(params['p_reference_id'], 'ref-999');
      expect(params['p_created_by'], 'user-admin');
    });

    test('RecordMaintenanceTransactionResponseDto parse kết quả thành công và thất bại', () {
      final successRaw = {
        'success': true,
        'transaction_id': 'tx-001',
        'voucher_number': 'PT-202611-0001',
        'new_balance': 150000000.0,
        'message': 'Ghi sổ thành công.',
      };
      final successDto = RecordMaintenanceTransactionResponseDto.fromRpc(successRaw);
      expect(successDto.success, isTrue);
      expect(successDto.transactionId, 'tx-001');
      expect(successDto.voucherNumber, 'PT-202611-0001');
      expect(successDto.newBalance, 150000000.0);
      expect(successDto.message, 'Ghi sổ thành công.');

      final nullDto = RecordMaintenanceTransactionResponseDto.fromRpc(null);
      expect(nullDto.success, isFalse);
    });

    test('ProcessBankPaymentWebhookRequestDto & ResponseDto', () {
      const req = ProcessBankPaymentWebhookRequestDto(
        gatewayTransactionId: 'sepay-tx-888',
        amount: 1250000.0,
        content: 'PKA A0110 đóng tiền',
        accountNumber: '1903678888',
      );
      final params = req.toRpcParams();
      expect(params.containsKey('p_payload'), isTrue);
      final payload = params['p_payload'] as Map<String, dynamic>;
      expect(payload['gateway_transaction_id'], 'sepay-tx-888');
      expect(payload['amount'], 1250000.0);
      expect(payload['account_number'], '1903678888');

      final resRaw = {
        'success': true,
        'status': 'SUCCESS',
        'invoice_id': 'inv-123',
        'receipt_number': 'REC-20261104-ABCD',
        'message': 'Gạch nợ thành công.',
      };
      final res = ProcessBankPaymentWebhookResponseDto.fromRpc(resRaw);
      expect(res.success, isTrue);
      expect(res.status, 'SUCCESS');
      expect(res.invoiceId, 'inv-123');
      expect(res.receiptNumber, 'REC-20261104-ABCD');
    });

    test('OnboardBuildingCommercialConfigRequestDto & ResponseDto', () {
      const req = OnboardBuildingCommercialConfigRequestDto(
        buildingId: 'bld-01',
        bankBin: '970418',
        bankName: 'BIDV',
        bankAccountNumber: '1234567890',
        bankAccountName: 'BAN QUAN LY PKA',
        initialMaintenanceBalance: 1000000000.0,
      );
      final params = req.toRpcParams();
      expect(params['p_building_id'], 'bld-01');
      expect(params['p_bank_bin'], '970418');
      expect(params['p_initial_maintenance_balance'], 1000000000.0);

      final res = OnboardBuildingCommercialConfigResponseDto.fromRpc({
        'success': true,
        'building_id': 'bld-01',
        'message': 'Cấu hình hoàn tất.',
      });
      expect(res.success, isTrue);
      expect(res.buildingId, 'bld-01');
    });

    test('CalculateApartmentDebtRiskRequestDto & ResponseDto', () {
      const req = CalculateApartmentDebtRiskRequestDto(buildingId: 'bld-01', apartmentId: 'apt-01');
      expect(req.toRpcParams()['p_building_id'], 'bld-01');
      expect(req.toRpcParams()['p_apartment_id'], 'apt-01');

      final res = CalculateApartmentDebtRiskResponseDto.fromRpc({
        'success': true,
        'apartment_id': 'apt-01',
        'risk_score': 85.5,
        'risk_level': 'HIGH',
        'recommended_action': 'Gửi cảnh báo đôn đốc Tầng 2',
        'message': 'Đã phân tích rủi ro nợ',
      });
      expect(res.success, isTrue);
      expect(res.riskScore, 85.5);
      expect(res.riskLevel, 'HIGH');
    });

    test('ExecuteDunningActionRequestDto & ResponseDto', () {
      const req = ExecuteDunningActionRequestDto(
        buildingId: 'bld-01',
        apartmentId: 'apt-01',
        tier: 'tier_2',
        title: 'Nhắc nợ kỳ 2',
        content: 'Thông báo nhắc nợ kỳ 2',
      );
      final params = req.toRpcParams();
      expect(params['p_building_id'], 'bld-01');
      expect(params['p_apartment_id'], 'apt-01');
      expect(params['p_tier'], 'tier_2');
      expect(params['p_title'], 'Nhắc nợ kỳ 2');
      expect(params['p_content'], 'Thông báo nhắc nợ kỳ 2');

      final res = ExecuteDunningActionResponseDto.fromRpc({
        'success': true,
        'action_id': 'dun-77',
        'apartment_id': 'apt-01',
        'tier': 'tier_2',
        'status': 'sent',
        'created_at': '2026-11-04T22:00:00Z',
        'message': 'Đã gửi đôn đốc thành công',
      });
      expect(res.success, isTrue);
      expect(res.actionId, 'dun-77');
      expect(res.tier, 'tier_2');
    });
  });

  group('2. Booking RPC Contracts Tests', () {
    test('BookAmenitySlotRequestDto & ResponseDto', () {
      const req = BookAmenitySlotRequestDto(
        amenityId: 'amenity-pool',
        apartmentId: 'apt-a0110',
        bookingDate: '2026-11-10',
        timeSlot: '08:00 - 10:00',
        guestsCount: 4,
        allowWaitlist: true,
        notes: 'Gia đình bơi buổi sáng',
      );
      final params = req.toRpcParams();
      expect(params['p_amenity_id'], 'amenity-pool');
      expect(params['p_booking_date'], '2026-11-10');
      expect(params['p_guests_count'], 4);
      expect(params['p_allow_waitlist'], isTrue);

      final res = BookAmenitySlotResponseDto.fromRpc({
        'success': true,
        'booking_id': 'bk-1234',
        'status': 'confirmed',
        'message': 'Đặt chỗ tiện ích thành công',
      });
      expect(res.success, isTrue);
      expect(res.bookingId, 'bk-1234');
      expect(res.status, 'confirmed');
    });

    test('CancelAmenityBookingRequestDto & ResponseDto', () {
      const req = CancelAmenityBookingRequestDto(bookingId: 'bk-1234');
      expect(req.toRpcParams()['p_booking_id'], 'bk-1234');

      final res = CancelAmenityBookingResponseDto.fromRpc({
        'success': true,
        'booking_id': 'bk-1234',
        'status': 'cancelled',
        'message': 'Hủy đặt chỗ thành công',
      });
      expect(res.success, isTrue);
      expect(res.status, 'cancelled');
    });

    test('CheckInAmenityBookingRequestDto & ResponseDto', () {
      const req = CheckInAmenityBookingRequestDto(bookingId: 'bk-1234');
      expect(req.toRpcParams()['p_booking_id'], 'bk-1234');

      final res = CheckInAmenityBookingResponseDto.fromRpc({
        'success': true,
        'booking_id': 'bk-1234',
        'checked_in_at': '2026-11-10T08:05:00Z',
        'message': 'Đã check-in thành công',
      });
      expect(res.success, isTrue);
      expect(res.checkedInAt, '2026-11-10T08:05:00Z');
    });

    test('GetSlotAvailabilityRequestDto & SlotAvailabilityItemDto', () {
      const req = GetSlotAvailabilityRequestDto(
        amenityId: 'amenity-gym',
        bookingDate: '2026-11-15',
      );
      expect(req.toRpcParams()['p_amenity_id'], 'amenity-gym');

      final item = SlotAvailabilityItemDto.fromRpc({
        'time_slot': '06:00 - 08:00',
        'booked_count': 5,
        'max_capacity': 20,
        'is_available': true,
      });
      expect(item.timeSlot, '06:00 - 08:00');
      expect(item.bookedCount, 5);
      expect(item.maxCapacity, 20);
      expect(item.isAvailable, isTrue);
    });
  });

  group('3. Operations RPC Contracts Tests', () {
    test('TriageIssueReportRequestDto & ResponseDto', () {
      const req = TriageIssueReportRequestDto(issueId: 'iss-99', autoAssign: true);
      expect(req.toRpcParams()['p_issue_id'], 'iss-99');
      expect(req.toRpcParams()['p_auto_assign'], isTrue);

      final res = TriageIssueReportResponseDto.fromRpc({
        'success': true,
        'issue_id': 'iss-99',
        'auto_assigned': true,
        'assigned_staff_id': 'staff-01',
        'assigned_staff_name': 'Nguyễn Văn Kỹ Thuật',
        'category': 'DienNuoc',
        'priority': 'URGENT',
        'is_hazardous': true,
        'message': 'Đã phân loại sự cố nguy hiểm',
      });
      expect(res.success, isTrue);
      expect(res.autoAssigned, isTrue);
      expect(res.isHazardous, isTrue);
      expect(res.priority, 'URGENT');
    });

    test('VisitorPassCheckInRequestDto & ResponseDto', () {
      const req = VisitorPassCheckInRequestDto(passCode: 'VP-8888', guardId: 'guard-01');
      expect(req.toRpcParams()['p_pass_code'], 'VP-8888');

      final res = VisitorPassCheckInResponseDto.fromRpc({
        'success': true,
        'pass_id': 'vp-uuid',
        'pass_code': 'VP-8888',
        'visitor_name': 'Trần Văn Khách',
        'checked_in_at': '2026-11-04T10:00:00Z',
        'message': 'Đã check-in thành công',
      });
      expect(res.success, isTrue);
      expect(res.visitorName, 'Trần Văn Khách');
    });

    test('VisitorPassCheckOutRequestDto & ResponseDto', () {
      const req = VisitorPassCheckOutRequestDto(passCode: 'VP-8888', guardId: 'guard-01');
      expect(req.toRpcParams()['p_guard_id'], 'guard-01');

      final res = VisitorPassCheckOutResponseDto.fromRpc({
        'success': true,
        'pass_id': 'vp-uuid',
        'pass_code': 'VP-8888',
        'visitor_name': 'Trần Văn Khách',
        'checked_out_at': '2026-11-04T12:00:00Z',
        'message': 'Đã check-out thành công',
      });
      expect(res.success, isTrue);
      expect(res.checkedOutAt, '2026-11-04T12:00:00Z');
    });

    test('CollectParcelRequestDto & ResponseDto', () {
      const req = CollectParcelRequestDto(
        parcelId: 'par-01',
        pickupPin: '1234',
        staffId: 'staff-guard',
      );
      expect(req.toRpcParams()['p_pickup_pin'], '1234');

      final res = CollectParcelResponseDto.fromRpc({
        'success': true,
        'parcel_id': 'par-01',
        'parcel_code': 'PAR-202611-001',
        'collected_at': '2026-11-04T15:00:00Z',
        'message': 'Đã phát bưu kiện cho cư dân',
      });
      expect(res.success, isTrue);
      expect(res.parcelCode, 'PAR-202611-001');
    });

    test('DetectMeterAnomalyRequestDto & ResponseDto', () {
      const req = DetectMeterAnomalyRequestDto(
        meterId: 'meter-01',
        currentReading: 245.5,
        readingDate: '2026-11-01',
      );
      final params = req.toRpcParams();
      expect(params['p_current_reading'], 245.5);

      final res = DetectMeterAnomalyResponseDto.fromRpc({
        'success': true,
        'is_anomaly': true,
        'previous_reading': 150.0,
        'consumption': 95.5,
        'avg_consumption': 30.0,
        'deviation_percent': 218.3,
        'reason': 'Chỉ số tiêu thụ tăng đột biến vượt quá 200% so với trung bình.',
      });
      expect(res.isAnomaly, isTrue);
      expect(res.consumption, 95.5);
      expect(res.deviationPercent, 218.3);
    });
  });

  group('4. Community RPC Contracts Tests', () {
    test('SubmitPollVoteRequestDto & ResponseDto', () {
      const req = SubmitPollVoteRequestDto(
        pollId: 'poll-01',
        apartmentId: 'apt-a0110',
        voterUserId: 'user-01',
        optionIds: ['opt-agree'],
      );
      final params = req.toRpcParams();
      expect(params['p_poll_id'], 'poll-01');
      expect(params['p_option_ids'], ['opt-agree']);

      final res = SubmitPollVoteResponseDto.fromRpc({
        'success': true,
        'vote_id': 'vote-uuid',
        'weight': 85.5,
        'message': 'Gửi phiếu thành công',
      });
      expect(res.success, isTrue);
      expect(res.voteId, 'vote-uuid');
      expect(res.weight, 85.5);
    });

    test('EndorsePetitionRequestDto & ResponseDto', () {
      const req = EndorsePetitionRequestDto(
        petitionId: 'pet-01',
        apartmentId: 'apt-a0110',
        userId: 'user-01',
      );
      final params = req.toRpcParams();
      expect(params['p_petition_id'], 'pet-01');

      final res = EndorsePetitionResponseDto.fromRpc({
        'success': true,
        'endorsement_count': 42,
        'message': 'Đã ghi nhận sự đồng thuận',
      });
      expect(res.success, isTrue);
      expect(res.endorsementCount, 42);
    });
  });

  group('5. RpcContractException Tests', () {
    test('RpcContractException định dạng thông điệp lỗi rõ ràng', () {
      const ex = RpcContractException(
        rpcName: 'record_maintenance_fund_transaction',
        message: 'Lỗi thẩm quyền kế toán',
      );
      expect(ex.toString(), 'RpcContractException [record_maintenance_fund_transaction]: Lỗi thẩm quyền kế toán');
    });
  });
}
