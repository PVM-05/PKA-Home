import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/membership_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('MembershipRepository Unit Tests', () {
    late MockSupabaseClient mockClient;
    late MembershipRepository repository;

    setUp(() {
      mockClient = MockSupabaseClient();
      repository = MembershipRepository(client: mockClient);
    });

    test('Có thể khởi tạo MembershipRepository với client được tiêm vào', () {
      expect(repository, isNotNull);
    });

    test('buildAssignPayload ánh xạ chính xác các trường dữ liệu bắt buộc', () {
      final payload = repository.buildAssignPayload(
        buildingId: 'bld-001',
        userId: 'user-001',
        buildingRole: 'accountant',
      );

      expect(payload['building_id'], equals('bld-001'));
      expect(payload['user_id'], equals('user-001'));
      expect(payload['building_role'], equals('accountant'));
      expect(payload['is_active'], isTrue);
      expect(payload.containsKey('apartment_id'), isFalse);
      expect(payload.containsKey('expires_at'), isFalse);
    });

    test('buildAssignPayload ánh xạ căn hộ và thời hạn ủy quyền khi có chỉ định', () {
      final expireTime = DateTime(2026, 12, 31, 23, 59, 59);
      final payload = repository.buildAssignPayload(
        buildingId: 'bld-002',
        userId: 'user-002',
        buildingRole: 'resident',
        apartmentId: 'apt-0110',
        expiresAt: expireTime,
      );

      expect(payload['building_id'], equals('bld-002'));
      expect(payload['user_id'], equals('user-002'));
      expect(payload['building_role'], equals('resident'));
      expect(payload['apartment_id'], equals('apt-0110'));
      expect(payload['expires_at'], equals(expireTime.toIso8601String()));
      expect(payload['is_active'], isTrue);
    });

    test('fetchUserBuildingMemberships trả về danh sách rỗng an toàn khi client ném ngoại lệ', () async {
      when(() => mockClient.from('building_memberships')).thenThrow(
        const PostgrestException(message: 'Permission denied', code: '42501'),
      );

      final list = await repository.fetchUserBuildingMemberships('user-unknown');
      expect(list, isEmpty);
    });

    test('fetchBuildingMembers trả về danh sách rỗng an toàn khi mất kết nối mạng', () async {
      when(() => mockClient.from('building_memberships')).thenThrow(
        Exception('Network connection failed'),
      );

      final list = await repository.fetchBuildingMembers('bld-unknown');
      expect(list, isEmpty);
    });

    test('revokeBuildingMembership trả về false an toàn khi lỗi cơ sở dữ liệu', () async {
      when(() => mockClient.from('building_memberships')).thenThrow(
        const PostgrestException(message: 'Record not found', code: 'P0002'),
      );

      final success = await repository.revokeBuildingMembership('bm-invalid');
      expect(success, isFalse);
    });

    test('fetchUserOrganizations trả về rỗng an toàn khi lỗi kết nối', () async {
      when(() => mockClient.from('organization_memberships')).thenThrow(
        Exception('Timeout'),
      );

      final list = await repository.fetchUserOrganizations('user-test');
      expect(list, isEmpty);
    });
  });
}
