import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_invitation_model.dart';

void main() {
  group('ApartmentInvitationModel Tests', () {
    final now = DateTime(2026, 10, 30);
    final futureDate = now.add(const Duration(hours: 48));
    final pastDate = now.subtract(const Duration(hours: 1));

    final jsonActive = {
      'id': 'invite-01',
      'apartment_id': 'apt-01',
      'apartment_code': 'A0110',
      'created_by': 'admin-01',
      'invite_code': 'PKAA0110X',
      'target_role': 'member',
      'max_uses': 1,
      'used_count': 0,
      'expires_at': futureDate.toIso8601String(),
      'status': 'active',
      'created_at': now.toIso8601String(),
    };

    test('fromJson parses active invitation correctly', () {
      final model = ApartmentInvitationModel.fromJson(jsonActive);

      expect(model.id, 'invite-01');
      expect(model.apartmentId, 'apt-01');
      expect(model.apartmentCode, 'A0110');
      expect(model.inviteCode, 'PKAA0110X');
      expect(model.targetRole, 'member');
      expect(model.maxUses, 1);
      expect(model.usedCount, 0);
      expect(model.status, 'active');
      expect(model.isUsable, isTrue);
      expect(model.isExpired, isFalse);
      expect(model.displayTargetRole, 'Thành viên ở cùng');
      expect(model.displayStatus, 'Còn hiệu lực');
      expect(model.shareableUrl, 'https://pkahome.vn/invite?code=PKAA0110X');
    });

    test('isUsable and isExpired handle expired or exhausted invites', () {
      final jsonExpired = Map<String, dynamic>.from(jsonActive)
        ..['expires_at'] = pastDate.toIso8601String()
        ..['status'] = 'expired'
        ..['target_role'] = 'tenant';

      final modelExpired = ApartmentInvitationModel.fromJson(jsonExpired);
      expect(modelExpired.isExpired, isTrue);
      expect(modelExpired.isUsable, isFalse);
      expect(modelExpired.displayTargetRole, 'Người thuê');
      expect(modelExpired.displayStatus, 'Đã hết hạn');

      final jsonExhausted = Map<String, dynamic>.from(jsonActive)
        ..['used_count'] = 1
        ..['status'] = 'exhausted';

      final modelExhausted = ApartmentInvitationModel.fromJson(jsonExhausted);
      expect(modelExhausted.isUsable, isFalse);
      expect(modelExhausted.displayStatus, 'Đã dùng hết');
    });
  });
}
