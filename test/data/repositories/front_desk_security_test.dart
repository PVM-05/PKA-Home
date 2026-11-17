import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/security/visitor_pass_token_service.dart';
import 'package:vivona/data/contracts/community_rpc_contracts.dart';
import 'package:vivona/data/contracts/operations_rpc_contracts.dart';

void main() {
  group('Security Contracts & Replay Protection Tests (P0/P1)', () {
    test('VisitorPassCheckInRequestDto cho phép guardId rỗng để máy chủ dùng auth.uid()', () {
      const dto = VisitorPassCheckInRequestDto(
        passCode: 'VP-202611-00001',
      );

      final params = dto.toRpcParams();
      expect(params['p_pass_code'], 'VP-202611-00001');
      expect(params.containsKey('p_guard_id'), isFalse);
    });

    test('VisitorPassCheckOutRequestDto cho phép guardId rỗng', () {
      const dto = VisitorPassCheckOutRequestDto(
        passCode: 'VP-202611-00001',
      );

      final params = dto.toRpcParams();
      expect(params['p_pass_code'], 'VP-202611-00001');
      expect(params.containsKey('p_guard_id'), isFalse);
    });

    test('CollectParcelRequestDto cho phép staffId rỗng để máy chủ dùng auth.uid()', () {
      const dto = CollectParcelRequestDto(
        parcelId: 'pcl-01',
        pickupPin: '123456',
      );

      final params = dto.toRpcParams();
      expect(params['p_parcel_id'], 'pcl-01');
      expect(params['p_pickup_pin'], '123456');
      expect(params.containsKey('p_staff_id'), isFalse);
    });

    test('SubmitPollVoteRequestDto cho phép voterUserId rỗng', () {
      const dto = SubmitPollVoteRequestDto(
        pollId: 'poll-01',
        apartmentId: 'apt-01',
        optionIds: ['opt-1', 'opt-2'],
      );

      final params = dto.toRpcParams();
      expect(params['p_poll_id'], 'poll-01');
      expect(params['p_apartment_id'], 'apt-01');
      expect(params.containsKey('p_voter_user_id'), isFalse);
    });

    test('EndorsePetitionRequestDto cho phép userId rỗng', () {
      const dto = EndorsePetitionRequestDto(
        petitionId: 'pet-01',
        apartmentId: 'apt-01',
      );

      final params = dto.toRpcParams();
      expect(params['p_petition_id'], 'pet-01');
      expect(params['p_apartment_id'], 'apt-01');
      expect(params.containsKey('p_user_id'), isFalse);
    });

    test('VisitorPassTokenService sinh mã QR đã ký chuẩn PKAPASS.v1 thay cho fake random', () {
      final qrPayload = VisitorPassTokenService.generateSignedQrPayload(
        passCode: 'VP-202611-00001',
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      expect(qrPayload.startsWith('PKAPASS.v1.'), isTrue);
      expect(VisitorPassTokenService.verifyAndParseQrPayload(qrPayload).isValid, isTrue);
    });

    test('VisitorPassCheckInRequestDto mang thông tin mã vé chống replay attack', () {
      const dto = VisitorPassCheckInRequestDto(
        passCode: 'VP-202611-00001',
      );
      final params = dto.toRpcParams();
      expect(params['p_pass_code'], 'VP-202611-00001');
    });
  });
}

