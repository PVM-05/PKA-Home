import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_invitation_model.dart';
import 'package:pka_home/data/models/resident_lease_contract_model.dart';
import 'package:pka_home/data/repositories/resident_lifecycle_repository.dart';

class FakeResidentLifecycleRepository extends ResidentLifecycleRepository {
  final List<ResidentLeaseContractModel> mockContracts;
  final List<ApartmentInvitationModel> mockInvitations;

  FakeResidentLifecycleRepository({
    this.mockContracts = const [],
    this.mockInvitations = const [],
  });

  @override
  Future<List<ResidentLeaseContractModel>> fetchApartmentContracts(String apartmentId) async {
    return mockContracts;
  }

  @override
  Future<List<ApartmentInvitationModel>> fetchApartmentInvitations(String apartmentId) async {
    return mockInvitations;
  }

  @override
  Future<Map<String, dynamic>> createInvitation({
    required String apartmentId,
    required String targetRole,
    int expiresHours = 48,
    int maxUses = 1,
  }) async {
    return {
      'success': true,
      'invite_code': 'PKAA0110X',
      'apartment_id': apartmentId,
      'target_role': targetRole,
      'expires_at': DateTime.now().add(Duration(hours: expiresHours)).toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> acceptInvitation(String inviteCode) async {
    if (inviteCode == 'PKAA0110X') {
      return {
        'success': true,
        'message': 'Kích hoạt gia nhập căn hộ thành công!',
        'apartment_code': 'A0110',
        'role': 'member',
      };
    }
    return {
      'success': false,
      'message': 'Mã mời không tồn tại hoặc đã hết hạn.',
    };
  }

  @override
  Future<Map<String, dynamic>> terminateResidentStay({
    required String userId,
    required String apartmentId,
    DateTime? terminationDate,
    String? note,
  }) async {
    return {
      'success': true,
      'message': 'Đã kết thúc lưu trú thành công.',
      'user_id': userId,
      'apartment_id': apartmentId,
    };
  }
}

void main() {
  group('ResidentLifecycleRepository Tests', () {
    final now = DateTime(2026, 10, 30);
    final mockContract = ResidentLeaseContractModel(
      id: 'c-1',
      userId: 'u-1',
      apartmentId: 'apt-1',
      fullName: 'Tran Van B',
      relationRole: 'tenant',
      status: 'active',
      startDate: now,
      depositAmount: 5000000,
      createdAt: now,
    );

    final mockInvite = ApartmentInvitationModel(
      id: 'inv-1',
      apartmentId: 'apt-1',
      apartmentCode: 'A0110',
      createdBy: 'admin-1',
      inviteCode: 'PKAA0110X',
      targetRole: 'member',
      expiresAt: now.add(const Duration(hours: 48)),
      status: 'active',
      createdAt: now,
    );

    final repo = FakeResidentLifecycleRepository(
      mockContracts: [mockContract],
      mockInvitations: [mockInvite],
    );

    test('fetchApartmentContracts tra ve danh sach hop dong', () async {
      final contracts = await repo.fetchApartmentContracts('apt-1');
      expect(contracts.length, 1);
      expect(contracts.first.fullName, 'Tran Van B');
      expect(contracts.first.relationRole, 'tenant');
    });

    test('createInvitation sinh ma moi thanh cong', () async {
      final res = await repo.createInvitation(
        apartmentId: 'apt-1',
        targetRole: 'member',
        expiresHours: 24,
      );

      expect(res['success'], isTrue);
      expect(res['invite_code'], 'PKAA0110X');
    });

    test('acceptInvitation chap nhan ma hop le va tu choi ma sai', () async {
      final valid = await repo.acceptInvitation('PKAA0110X');
      expect(valid['success'], isTrue);
      expect(valid['apartment_code'], 'A0110');

      final invalid = await repo.acceptInvitation('SAI_MA');
      expect(invalid['success'], isFalse);
    });

    test('terminateResidentStay ket thuc quan he luu tru thanh cong', () async {
      final res = await repo.terminateResidentStay(
        userId: 'u-1',
        apartmentId: 'apt-1',
        note: 'Hết hạn hợp đồng thuê và đã hoàn cọc',
      );

      expect(res['success'], isTrue);
      expect(res['user_id'], 'u-1');
    });
  });
}
