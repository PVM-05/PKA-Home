import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/emergency_contact_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/core/constants/app_constants.dart';

void main() {
  group('DisplayName and Constants Tests', () {
    test('EmergencyContactModel.contactTypeDisplayName maps correctly', () {
      final security = EmergencyContactModel(
        id: '1', name: 'Bảo vệ', phone: '0901', contactType: 'security', displayOrder: 1,
      );
      final medical = EmergencyContactModel(
        id: '2', name: 'Y tế', phone: '0902', contactType: 'medical', displayOrder: 2,
      );
      final fire = EmergencyContactModel(
        id: '3', name: 'PCCC', phone: '0903', contactType: 'fire', displayOrder: 3,
      );
      final management = EmergencyContactModel(
        id: '4', name: 'BQL', phone: '0904', contactType: 'management', displayOrder: 4,
      );
      final tech = EmergencyContactModel(
        id: '5', name: 'Kỹ thuật', phone: '0905', contactType: 'technical', displayOrder: 5,
      );
      final unknown = EmergencyContactModel(
        id: '6', name: 'Khác', phone: '0906', contactType: 'other', displayOrder: 6,
      );

      expect(security.contactTypeDisplayName, 'An ninh / Bảo vệ');
      expect(medical.contactTypeDisplayName, 'Cấp cứu / Y tế');
      expect(fire.contactTypeDisplayName, 'PCCC / Cứu hộ');
      expect(management.contactTypeDisplayName, 'Ban Quản Lý');
      expect(tech.contactTypeDisplayName, 'Đội Kỹ Thuật');
      expect(unknown.contactTypeDisplayName, 'Đường dây nóng');
    });

    test('UserModel.roleToDisplayName maps role strings accurately', () {
      expect(UserModel.roleToDisplayName('admin'), 'Quản trị viên');
      expect(UserModel.roleToDisplayName('management'), 'Quản trị viên');
      expect(UserModel.roleToDisplayName('accountant'), 'Kế toán');
      expect(UserModel.roleToDisplayName('technician'), 'Kỹ thuật viên');
      expect(UserModel.roleToDisplayName('resident'), 'Cư dân');
      expect(UserModel.roleToDisplayName(null), 'Không xác định');
      expect(UserModel.roleToDisplayName('guest'), 'guest');
    });

    test('AppConstants contains unified management and parking fee constants', () {
      expect(AppConstants.kDefaultManagementFeePerM2, 16500.0);
      expect(AppConstants.kDefaultManagementFeeFormatted, '16.500 đ/m²/tháng');
      expect(AppConstants.kMotorbikeFee, 100000.0);
      expect(AppConstants.kCarFee, 1200000.0);
    });
  });
}
