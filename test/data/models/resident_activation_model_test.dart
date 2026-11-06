import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/resident_activation_model.dart';

void main() {
  group('ResidentActivationModel Tests', () {
    test('serialization and deserialization works correctly', () {
      final model = ResidentActivationModel(
        activationId: 'act-1',
        userId: 'user-1',
        fullName: 'Nguyễn Văn An',
        phone: '0901234567',
        apartmentCode: 'A0110',
        relationRole: 'owner',
        activationCode: 'ACT-123456',
        status: 'pending',
        isActive: false,
        createdAt: DateTime(2026, 11, 6),
      );

      final json = model.toJson();
      expect(json['activation_id'], 'act-1');
      expect(json['full_name'], 'Nguyễn Văn An');
      expect(json['phone'], '0901234567');
      expect(json['apartment_code'], 'A0110');
      expect(json['activation_code'], 'ACT-123456');

      final fromJson = ResidentActivationModel.fromJson(json);
      expect(fromJson.activationId, model.activationId);
      expect(fromJson.userId, model.userId);
      expect(fromJson.fullName, model.fullName);
      expect(fromJson.phone, model.phone);
      expect(fromJson.apartmentCode, model.apartmentCode);
      expect(fromJson.relationRole, 'owner');
      expect(fromJson.activationCode, 'ACT-123456');
      expect(fromJson.status, 'pending');
      expect(fromJson.isActive, isFalse);
    });

    test('relationRoleText and statusText return accurate Vietnamese strings', () {
      const owner = ResidentActivationModel(
        userId: 'u1',
        fullName: 'A',
        phone: '090',
        apartmentCode: 'A0110',
        relationRole: 'owner',
        status: 'pending',
        activationCode: 'ACT-111111',
      );
      expect(owner.relationRoleText, 'Chủ hộ');
      expect(owner.statusText, 'Đã cấp mã (Chưa kích hoạt)');

      const tenant = ResidentActivationModel(
        userId: 'u2',
        fullName: 'B',
        phone: '091',
        apartmentCode: 'A0110',
        relationRole: 'tenant',
        status: 'otp_sent',
        activationCode: 'ACT-222222',
      );
      expect(tenant.relationRoleText, 'Người thuê');
      expect(tenant.statusText, 'Đang chờ OTP');

      const activated = ResidentActivationModel(
        userId: 'u3',
        fullName: 'C',
        phone: '092',
        apartmentCode: 'A0110',
        relationRole: 'family_member',
        status: 'activated',
        isActive: true,
      );
      expect(activated.relationRoleText, 'Thành viên');
      expect(activated.statusText, 'Đã kích hoạt');

      const unassigned = ResidentActivationModel(
        userId: 'u4',
        fullName: 'D',
        phone: '093',
        apartmentCode: 'A0110',
        relationRole: 'resident',
        status: 'pending',
        activationCode: '',
      );
      expect(unassigned.relationRoleText, 'Cư dân');
      expect(unassigned.statusText, 'Chưa cấp mã');
    });
  });
}
