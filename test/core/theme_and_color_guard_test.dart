import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Design System Theme & Color CI Guardrail Tests', () {
    /// Danh sách các file màn hình đã được chuẩn hóa theo Design Tokens (Whitelist)
    /// Khi một module hoàn thành refactor, thêm file của module đó vào danh sách này.
    final targetModulesWhitelist = <String>[
      // Module 1: Tài chính & Hóa đơn (Đã hoàn thiện chuẩn Design System)
      'lib/features/resident/screens/resident_invoice_screen.dart',
      'lib/features/resident/screens/resident_invoice_detail_screen.dart',
      'lib/features/management/screens/invoice_management_screen.dart',
      'lib/features/management/screens/management_invoice_detail_screen.dart',
      // Module 2: Sự cố & Vận hành (Đã hoàn thiện chuẩn Design System)
      'lib/features/resident/screens/resident_issue_screen.dart',
      'lib/features/resident/screens/issue_detail_screen.dart',
      'lib/features/management/screens/issue_management_screen.dart',
      // Module 3: Xác thực & Định danh (Auth Module)
      'lib/features/auth/screens/login_screen.dart',
      'lib/features/auth/screens/register_screen.dart',
      'lib/features/auth/screens/resident_activation_screen.dart',
      'lib/features/auth/screens/forgot_password_screen.dart',
      // Module 4: Cư dân - Trang chủ & Hồ sơ cá nhân (Resident Portal Foundation)
      'lib/features/resident/screens/resident_home_screen.dart',
      'lib/features/resident/screens/resident_profile_screen.dart',
      // Module 5: Cư dân - Phương tiện & Khai báo chỉ số đồng hồ (Vehicle & Meter Reading)
      'lib/features/resident/screens/vehicle_management_screen.dart',
      'lib/features/resident/screens/resident_meter_reading_screen.dart',
      'lib/features/resident/widgets/vehicle/resident_vehicle_card.dart',
      'lib/features/resident/widgets/meter/resident_meter_card.dart',
      // Module 6: Ban Quản Lý - Trang chủ, Cư dân, Căn hộ & Duyệt điện nước
      'lib/features/management/screens/management_home_screen.dart',
      'lib/features/management/screens/resident_management_screen.dart',
      'lib/features/management/screens/apartment_management_screen.dart',
      'lib/features/management/screens/management_meter_reading_screen.dart',
      'lib/features/management/widgets/home/management_financial_progress_card.dart',
      'lib/features/management/widgets/home/management_recent_transactions_card.dart',
      'lib/features/management/widgets/resident/management_resident_list_card.dart',
      'lib/features/management/widgets/apartment/management_apartment_grid_card.dart',
      'lib/features/management/widgets/meter/management_submission_card.dart',
      // Module 7: Ngôn ngữ thị giác 2026 (Visual Language 2026 - Bento & Motion)
      'lib/core/widgets/app_glass.dart',
      'lib/core/widgets/bounceable.dart',
      'lib/features/resident/widgets/home/resident_utility_consumption_chart_card.dart',
      'lib/features/resident/widgets/home/resident_home_upcoming_invoice_card.dart',
      'lib/features/resident/widgets/home/resident_home_quick_actions_row.dart',
      // Module 8: Thích ứng & Cá nhân hóa 2026 (Adaptive & Personalization)
      'lib/core/widgets/adaptive_master_detail_layout.dart',
      'lib/core/widgets/app_semantic_badge.dart',
      'lib/features/resident/providers/home_personalization_provider.dart',
      'lib/features/resident/widgets/home/meter_reading_reminder_banner.dart',
      // Module 9: Quản lý & Chi tiết Thông báo & Hệ thống Phản hồi (Announcement & AppSnackBar)
      'lib/core/widgets/app_snack_bar.dart',
      'lib/features/management/screens/announcement_management_screen.dart',
      'lib/features/resident/screens/resident_announcement_detail_screen.dart',
      // Module 10: Quản lý & Đặt chỗ Tiện ích (Amenity System)
      'lib/features/management/screens/amenity_management_screen.dart',
      'lib/features/resident/screens/amenity_booking_screen.dart',
      'lib/features/resident/widgets/resident_amenity_bookings_tab.dart',
      // Module 11: Tạo Phản ánh Sự cố, Duyệt xe & Quản lý Bãi đỗ xe (Issue & Parking System)
      'lib/features/resident/screens/create_issue_screen.dart',
      'lib/features/management/screens/vehicle_approval_screen.dart',
      'lib/features/management/screens/parking_management_screen.dart',
      // Module 12: Quản lý Biểu phí, Lập Hóa Đơn & Báo cáo Tài chính (Fee Policy, Invoicing & Financial Reports)
      'lib/features/management/screens/create_invoice_screen.dart',
      'lib/features/management/screens/fee_policy_management_screen.dart',
      'lib/features/management/screens/financial_report_screen.dart',
      // Module 13: Lễ tân, Khách thăm & Bàn giao căn hộ (Front Desk, Visitor Pass & Handover)
      'lib/features/management/screens/front_desk_workstation_screen.dart',
      'lib/features/resident/screens/resident_visitor_parcel_screen.dart',
      'lib/features/resident/screens/resident_handover_detail_screen.dart',
      // Module 14: Kỹ thuật, Quản lý Trang thiết bị & Vật tư bảo dưỡng (Equipment & Maintenance System)
      'lib/features/management/screens/equipment_detail_screen.dart',
      'lib/features/management/screens/equipment_management_screen.dart',
      'lib/features/management/screens/maintenance_materials_screen.dart',
      // Module 15: Bảng tin cộng đồng, Ý kiến cư dân & Sổ tay tòa nhà (Community & Handbook System)
      'lib/features/management/screens/community_management_screen.dart',
      'lib/features/resident/screens/resident_community_screen.dart',
      'lib/features/resident/screens/resident_handbook_screen.dart',
    ];

    test('Guardrail: Mọi file trong whitelist đều phải tồn tại trên đĩa', () {
      final missingFiles = <String>[];
      for (final filePath in targetModulesWhitelist) {
        final file = File(filePath);
        if (!file.existsSync()) {
          missingFiles.add(filePath);
        }
      }
      expect(
        missingFiles,
        isEmpty,
        reason: 'Có file nằm trong Whitelist nhưng không tồn tại trên đĩa:\n${missingFiles.join('\n')}',
      );
    });

    test('Guardrail: Các màn hình trong whitelist không được chứa mã màu cứng Color(0x...)', () {
      final hardcodedColorRegex = RegExp(r'Color\(0x[0-9a-fA-F]+\)');
      final violations = <String>[];

      for (final filePath in targetModulesWhitelist) {
        final file = File(filePath);
        if (!file.existsSync()) {
          fail('File nằm trong Whitelist nhưng không tồn tại: $filePath');
        }

        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//') || line.startsWith('/*')) continue;

          if (hardcodedColorRegex.hasMatch(line)) {
            violations.add('$filePath:${i + 1}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện mã màu cứng trong các module đã chuẩn hóa Design System:\n${violations.join('\n')}',
      );
    });

    test('Guardrail: Các màn hình trong whitelist không được chứa fontSize cứng', () {
      final hardcodedFontSizeRegex = RegExp(r'fontSize:\s*[0-9]+(\.[0-9]+)?');
      final violations = <String>[];

      for (final filePath in targetModulesWhitelist) {
        final file = File(filePath);
        if (!file.existsSync()) {
          fail('File nằm trong Whitelist nhưng không tồn tại: $filePath');
        }

        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//') || line.startsWith('/*')) continue;

          if (hardcodedFontSizeRegex.hasMatch(line)) {
            violations.add('$filePath:${i + 1}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện fontSize cứng trong các module đã chuẩn hóa Design System:\n${violations.join('\n')}',
      );
    });

    test('Guardrail test logic: Bắt chính xác lỗi nếu file có mã màu hoặc fontSize cứng', () {
      const sampleBadCode = '''
        Text("Sample", style: TextStyle(fontSize: 14, color: Color(0xFF123456)));
      ''';

      expect(RegExp(r'Color\(0x[0-9a-fA-F]+\)').hasMatch(sampleBadCode), isTrue);
      expect(RegExp(r'fontSize:\s*[0-9]+').hasMatch(sampleBadCode), isTrue);
    });
  });
}
