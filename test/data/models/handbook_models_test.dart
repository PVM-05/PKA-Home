import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/emergency_contact_model.dart';
import 'package:pka_home/data/models/building_rule_model.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/user_model.dart';

void main() {
  group('EmergencyContactModel Tests', () {
    test('fromJson and toJson should work correctly', () {
      final json = {
        'id': 'contact-1',
        'name': 'Bảo vệ sảnh A',
        'phone': '02431234567',
        'contact_type': 'security',
        'display_order': 1,
        'created_at': '2026-09-06T10:00:00.000Z',
      };

      final model = EmergencyContactModel.fromJson(json);
      expect(model.id, 'contact-1');
      expect(model.name, 'Bảo vệ sảnh A');
      expect(model.phone, '02431234567');
      expect(model.contactType, 'security');
      expect(model.displayOrder, 1);

      final outJson = model.toJson();
      expect(outJson['id'], 'contact-1');
      expect(outJson['name'], 'Bảo vệ sảnh A');
      expect(outJson['phone'], '02431234567');
      expect(outJson['contact_type'], 'security');
      expect(outJson['display_order'], 1);
    });
  });

  group('BuildingRuleModel Tests', () {
    test('fromJson and toJson should work correctly', () {
      final json = {
        'id': 'rule-1',
        'title': 'Quy định tiếng ồn',
        'content': 'Không làm ồn sau 22h',
        'display_order': 2,
        'created_at': '2026-09-06T10:00:00.000Z',
      };

      final model = BuildingRuleModel.fromJson(json);
      expect(model.id, 'rule-1');
      expect(model.title, 'Quy định tiếng ồn');
      expect(model.content, 'Không làm ồn sau 22h');
      expect(model.displayOrder, 2);

      final outJson = model.toJson();
      expect(outJson['id'], 'rule-1');
      expect(outJson['title'], 'Quy định tiếng ồn');
      expect(outJson['content'], 'Không làm ồn sau 22h');
      expect(outJson['display_order'], 2);
    });
  });

  group('BuildingAmenityModel Tests', () {
    test('fromJson and toJson should work correctly', () {
      final json = {
        'id': 'amenity-1',
        'name': 'Hồ bơi',
        'description': 'Tầng 5',
        'open_hours': '06:00 - 21:00',
        'display_order': 1,
        'created_at': '2026-09-06T10:00:00.000Z',
      };

      final model = BuildingAmenityModel.fromJson(json);
      expect(model.id, 'amenity-1');
      expect(model.name, 'Hồ bơi');
      expect(model.description, 'Tầng 5');
      expect(model.openHours, '06:00 - 21:00');
      expect(model.displayOrder, 1);

      final outJson = model.toJson();
      expect(outJson['id'], 'amenity-1');
      expect(outJson['name'], 'Hồ bơi');
      expect(outJson['description'], 'Tầng 5');
      expect(outJson['open_hours'], '06:00 - 21:00');
      expect(outJson['display_order'], 1);
    });
  });

  group('UserModel Tests with Phone', () {
    test('fromJson and toJson should include phone', () {
      final json = {
        'id': 'user-1',
        'full_name': 'Nguyễn Văn A',
        'role': 'resident',
        'phone': '0987654321',
      };

      final model = UserModel.fromJson(json);
      expect(model.id, 'user-1');
      expect(model.fullName, 'Nguyễn Văn A');
      expect(model.role, 'resident');
      expect(model.phone, '0987654321');

      final outJson = model.toJson();
      expect(outJson['phone'], '0987654321');
    });
  });
}
