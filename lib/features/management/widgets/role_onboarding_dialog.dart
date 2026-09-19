import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';

class RoleOnboardingDialog {
  static Future<void> checkAndShow(BuildContext context, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'has_seen_role_onboarding_${user.id}_${user.role}';
    final hasSeen = prefs.getBool(key) ?? false;

    if (hasSeen || !context.mounted) return;

    // Xác định thông tin hiển thị theo role
    Color roleColor = AppTheme.primary;
    IconData roleIcon = Icons.admin_panel_settings;
    String roleDesc = 'Toàn quyền quản trị hệ thống tòa nhà, cư dân, căn hộ và phân công nhiệm vụ.';
    List<String> keyFeatures = [
      'Quản lý danh sách căn hộ và cư dân',
      'Ủy quyền vai trò tạm thời cho nhân sự',
      'Theo dõi lịch sử hoạt động và hiệu suất',
    ];

    if (user.isAccountant) {
      roleColor = Colors.purple;
      roleIcon = Icons.receipt_long;
      roleDesc = 'Bạn phụ trách quản lý tài chính, hóa đơn và công nợ của toàn bộ căn hộ trong tòa nhà.';
      keyFeatures = [
        'Lập hóa đơn định kỳ (điện, nước, quản lý, gửi xe)',
        'Xác nhận thanh toán hóa đơn của cư dân',
        'Theo dõi tiến độ thanh toán và hóa đơn quá hạn',
      ];
    } else if (user.isTechnician) {
      roleColor = Colors.orange;
      roleIcon = Icons.build_circle;
      roleDesc = 'Bạn phụ trách tiếp nhận, khắc phục và báo cáo tiến độ xử lý các sự cố kỹ thuật trong tòa nhà.';
      keyFeatures = [
        'Tiếp nhận phản ánh sự cố từ cư dân',
        'Cập nhật tiến độ xử lý (Đang làm / Hoàn thành)',
        'Tra cứu danh bạ tiện ích và cẩm nang tòa nhà',
      ];
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(roleIcon, color: roleColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chào mừng ${user.fullName}!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.roleDisplayName,
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              roleDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quyền hạn chính của bạn:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...keyFeatures.map((feat) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, color: roleColor, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                feat,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nếu cần thêm quyền hạn, vui lòng liên hệ Quản trị viên để được cấp hoặc ủy quyền tạm thời.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: roleColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await prefs.setBool(key, true);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('ĐÃ HIỂU & BẮT ĐẦU', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
