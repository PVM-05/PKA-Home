import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/resident_model.dart';

void main() {
  group('Admin User Management & Multi-Apartment Tests (20261024_03)', () {
    test('Tập tin migration 20261024_03_admin_user_management.sql phải tồn tại', () {
      final file = File('supabase/migrations_archive/20261024_03_admin_user_management.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration 20261024_03_admin_user_management.sql chưa được tạo');
    });

    test('Migration phải định nghĩa đầy đủ RPC quản trị, audit log và trigger khóa tài khoản', () {
      final file = File('supabase/migrations_archive/20261024_03_admin_user_management.sql');
      final content = file.readAsStringSync();

      // 1. Cột email và is_active trên public.users
      expect(content.contains('ADD COLUMN IF NOT EXISTS email VARCHAR'), isTrue);
      expect(content.contains('ADD COLUMN IF NOT EXISTS is_active BOOLEAN'), isTrue);

      // 2. Trigger kiểm tra tài khoản khóa/vô hiệu hóa ở phía máy chủ
      expect(content.contains('check_user_active_and_unlocked'), isTrue);
      expect(content.contains('trg_check_user_active_amenities'), isTrue);
      expect(content.contains('trg_check_user_active_issues'), isTrue);

      // 3. RPC Admin tạo tài khoản
      expect(content.contains('admin_create_user'), isTrue);

      // 4. RPC Admin cập nhật hồ sơ & đổi vai trò
      expect(content.contains('admin_update_user_profile'), isTrue);

      // 5. RPC Admin khóa/mở khóa & kích hoạt/vô hiệu hóa
      expect(content.contains('admin_toggle_user_status'), isTrue);

      // 6. RPC Admin gỡ liên kết căn hộ an toàn
      expect(content.contains('admin_unlink_apartment'), isTrue);

      // 7. Ghi nhận audit log nhật ký thay đổi vai trò và trạng thái
      expect(content.contains('INSERT INTO public.role_change_log'), isTrue);
    });

    test('ResidentModel ánh xạ chính xác email, is_active và danh sách nhiều căn hộ', () {
      final jsonSample = {
        'id': 'user-multi-01',
        'full_name': 'Nguyễn Văn Đa Căn Hộ',
        'phone': '0901234567',
        'email': 'dacanho@pka-home.vn',
        'role': 'resident',
        'is_locked': false,
        'is_active': true,
        'created_at': '2026-10-24T12:00:00Z',
        'residents_apartments': [
          {
            'apartment_id': 'apt-101',
            'relation_role': 'owner',
            'apartments': {
              'id': 'apt-101',
              'code': 'A0101',
              'building_code': 'A',
              'floor_number': 1,
              'area': 75.5,
              'is_empty': false,
            },
          },
          {
            'apartment_id': 'apt-202',
            'relation_role': 'tenant',
            'apartments': {
              'id': 'apt-202',
              'code': 'A0202',
              'building_code': 'A',
              'floor_number': 2,
              'area': 60.0,
              'is_empty': false,
            },
          },
        ],
      };

      final resident = ResidentModel.fromJson(jsonSample);

      // Kiểm tra thông tin cơ bản
      expect(resident.id, 'user-multi-01');
      expect(resident.fullName, 'Nguyễn Văn Đa Căn Hộ');
      expect(resident.email, 'dacanho@pka-home.vn');
      expect(resident.phone, '0901234567');
      expect(resident.isActive, isTrue);
      expect(resident.isLocked, isFalse);
      expect(resident.statusDisplayName, 'Đang hoạt động');

      // Tương thích ngược: apartment trả về căn hộ đầu tiên
      expect(resident.apartment, isNotNull);
      expect(resident.apartment!.code, 'A0101');

      // Đa căn hộ: apartments chứa đủ 2 liên kết
      expect(resident.apartments.length, 2);
      expect(resident.apartments[0].apartmentId, 'apt-101');
      expect(resident.apartments[0].apartmentCode, 'A0101');
      expect(resident.apartments[0].relationRole, 'owner');
      expect(resident.apartments[0].relationRoleDisplayName, 'Chủ hộ');

      expect(resident.apartments[1].apartmentId, 'apt-202');
      expect(resident.apartments[1].apartmentCode, 'A0202');
      expect(resident.apartments[1].relationRole, 'tenant');
      expect(resident.apartments[1].relationRoleDisplayName, 'Người thuê');

      // Tóm tắt danh sách căn hộ
      expect(resident.apartmentSummary, 'A0101, A0202');
    });

    test('ResidentModel statusDisplayName phản ánh đúng trạng thái tài khoản', () {
      final activeUser = ResidentModel(
        id: 'u-1',
        fullName: 'Người Dùng 1',
        phone: '0901111111',
        role: 'resident',
        isActive: true,
        isLocked: false,
      );
      expect(activeUser.statusDisplayName, 'Đang hoạt động');

      final lockedUser = ResidentModel(
        id: 'u-2',
        fullName: 'Người Dùng 2',
        phone: '0902222222',
        role: 'resident',
        isActive: true,
        isLocked: true,
      );
      expect(lockedUser.statusDisplayName, 'Đang bị khóa');

      final deactivatedUser = ResidentModel(
        id: 'u-3',
        fullName: 'Người Dùng 3',
        phone: '0903333333',
        role: 'resident',
        isActive: false,
        isLocked: false,
      );
      expect(deactivatedUser.statusDisplayName, 'Đã vô hiệu hóa');
    });
  });
}

