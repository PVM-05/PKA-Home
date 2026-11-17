import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// Trình quản lý chấp thuận dữ liệu cá nhân theo Luật 91/2025/QH15 & NĐ 356/2025/NĐ-CP
class PdplConsentManager {
  static const String kConsentKey = 'pdpl_consent_v1_accepted';
  static const String kConsentTimestampKey = 'pdpl_consent_v1_accepted_at';

  /// Kiểm tra cư dân đã chấp thuận xử lý dữ liệu hay chưa
  static Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kConsentKey) ?? false;
  }

  /// Lưu trạng thái chấp thuận vào bộ nhớ thiết bị
  static Future<void> saveConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kConsentKey, true);
    await prefs.setString(
      kConsentTimestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Hủy hoặc rút lại chấp thuận (phục vụ thu hồi quyền xử lý dữ liệu)
  static Future<void> revokeConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kConsentKey, false);
    await prefs.remove(kConsentTimestampKey);
  }

  /// Lấy thời điểm chấp thuận gần nhất
  static Future<String?> getConsentTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kConsentTimestampKey);
  }

  /// Hiển thị hộp thoại chấp thuận nếu người dùng chưa đồng ý
  static Future<bool> showConsentDialogIfNeeded(
    BuildContext context, {
    bool force = false,
  }) async {
    if (!force) {
      final consented = await hasConsented();
      if (consented) return true;
    }

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PdplConsentDialog(),
    );
    return result ?? false;
  }
}

/// Hộp thoại Chấp thuận Xử lý Dữ liệu Cá nhân (PDPL Consent Dialog)
class PdplConsentDialog extends StatefulWidget {
  final bool isReviewMode;

  const PdplConsentDialog({super.key, this.isReviewMode = false});

  @override
  State<PdplConsentDialog> createState() => _PdplConsentDialogState();
}

class _PdplConsentDialogState extends State<PdplConsentDialog> {
  bool _agreed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isReviewMode) {
      _agreed = true;
    }
  }

  Future<void> _handleConfirm() async {
    if (!_agreed) return;

    setState(() => _isSaving = true);
    await PdplConsentManager.saveConsent();
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.security_outlined,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bảo Vệ Dữ Liệu Cá Nhân',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Căn cứ Luật 91/2025/QH15 & NĐ 356/2025/NĐ-CP',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Content List
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vivona cam kết bảo mật tuyệt đối dữ liệu cá nhân của cư dân và ban quản trị. Vui lòng đọc kỹ phạm vi và mục đích thu thập thông tin:',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildScopeItem(
                        icon: Icons.badge_outlined,
                        title: 'Định danh cư dân',
                        detail:
                            'Họ tên, SĐT, số CCCD/Hộ chiếu phục vụ quản lý nhân khẩu và xác thực quyền cư trú theo Luật Nhà ở 2023.',
                      ),
                      _buildScopeItem(
                        icon: Icons.apartment_outlined,
                        title: 'Căn hộ & Diện tích',
                        detail:
                            'Mã căn hộ (Block + Tầng + Phòng), diện tích m² phục vụ tính phí dịch vụ và quyền biểu quyết điện tử.',
                      ),
                      _buildScopeItem(
                        icon: Icons.directions_car_outlined,
                        title: 'Phương tiện giao thông',
                        detail:
                            'Biển số xe, loại xe để kiểm soát an ninh barie và xuất vé gửi xe hàng tháng.',
                      ),
                      _buildScopeItem(
                        icon: Icons.electric_meter_outlined,
                        title: 'Chỉ số điện & nước',
                        detail:
                            'Hình ảnh công tơ và chỉ số tiêu thụ phục vụ tính toán hóa đơn lũy tiến minh bạch.',
                      ),
                      _buildScopeItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Lịch sử thanh toán',
                        detail:
                            'Giao dịch chuyển khoản VietQR, hóa đơn dịch vụ và sổ cái quỹ bảo trì 2%.',
                      ),

                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.slate100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Dữ liệu được mã hóa AES-256 trên cơ sở dữ liệu và cách ly phân quyền bằng Supabase Row Level Security (RLS). Cư dân có toàn quyền xuất bản sao kê hoặc yêu cầu đóng băng dữ liệu bất cứ lúc nào.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.slate700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Policy Sheet Action
              TextButton.icon(
                onPressed: () => showPrivacyPolicyBottomSheet(context),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text(
                  'Xem chi tiết Toàn văn Chính sách Bảo mật (PDPL 2026)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),
              ),

              if (!widget.isReviewMode) ...[
                // Checkbox Agree
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreed,
                        onChanged: (val) {
                          setState(() => _agreed = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _agreed = !_agreed);
                        },
                        child: const Text(
                          'Tôi đã đọc, hiểu rõ quyền chủ thể dữ liệu và tự nguyện đồng ý cho phép Vivona thu thập, xử lý thông tin cá nhân phục vụ vận hành tòa nhà.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              Row(
                children: [
                  if (widget.isReviewMode) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Đóng'),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_agreed && !_isSaving)
                            ? _handleConfirm
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Xác nhận và Đồng ý',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeItem({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hiển thị toàn văn chính sách bảo mật dạng Bottom Sheet
void showPrivacyPolicyBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Chính Sách Bảo Mật Dữ Liệu (PDPL)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Text(
                  'Căn cứ Luật 91/2025/QH15 & Nghị định 356/2025/NĐ-CP',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: const [
                      _PolicySectionCard(
                        number: '1',
                        title: 'Tôn Chỉ & Phạm Vi Áp Dụng',
                        body:
                            'Vivona cam kết bảo vệ an toàn tính riêng tư dữ liệu cá nhân cho Ban Quản Lý, Chủ căn hộ, Cư dân và Khách thuê theo nguyên tắc đặc quyền tối thiểu (Least Privilege) và bảo mật theo thiết kế (Privacy by Design).',
                      ),
                      _PolicySectionCard(
                        number: '2',
                        title: 'Danh Mục Dữ Liệu Thu Thập',
                        body:
                            '- Định danh cá nhân: Họ tên, SĐT, CCCD/Hộ chiếu, email.\n- Cư trú & Bất động sản: Mã căn hộ A0110, diện tích m², vai trò cư dân.\n- Phương tiện & Gửi xe: Biển số xe, loại xe.\n- Tiêu thụ năng lượng: Ảnh công tơ, chỉ số điện nước.\n- Lễ tân & Khách thăm: QR Token, thời gian check-in/out.\n- Tài chính: Hóa đơn dịch vụ, chuyển khoản VietQR, quỹ bảo trì 2%.',
                      ),
                      _PolicySectionCard(
                        number: '3',
                        title: 'Căn Cứ Pháp Lý Xử Lý Dữ Liệu',
                        body:
                            '1. Sự đồng thuận của chủ thể dữ liệu khi tham gia hệ thống.\n2. Thực hiện nghĩa vụ hợp đồng quản lý vận hành tòa nhà.\n3. Tuân thủ Luật Nhà ở 2023, Luật PCCC và các Nghị định về hóa đơn, chứng từ điện tử.',
                      ),
                      _PolicySectionCard(
                        number: '4',
                        title: 'Biện Pháp Kỹ Thuật Bảo Vệ',
                        body:
                            '- Mã hóa toàn trình TLS 1.3/HTTPS và AES-256 cho dữ liệu lưu trữ.\n- Phân quyền hàng dữ liệu Supabase Row Level Security (RLS) - cách ly tuyệt đối căn hộ A và B.\n- Fail-Closed: Khóa truy cập khi phát hiện bất thường kết nối.\n- Nhật ký kiểm toán bất biến (Immutable Audit Logs) có dấu thời gian.',
                      ),
                      _PolicySectionCard(
                        number: '5',
                        title: 'Quyền Của Chủ Thể Dữ Liệu',
                        body:
                            '- Quyền được biết và rút lại sự đồng thuận.\n- Quyền truy cập và chỉnh sửa hồ sơ.\n- Quyền xuất dữ liệu cá nhân (Data Portability theo Điều 15).\n- Quyền yêu cầu xóa / đóng băng dữ liệu (Right to be Forgotten theo Điều 16, 17) khi chuyển đi.',
                      ),
                      _PolicySectionCard(
                        number: '6',
                        title: 'Quy Trình Ứng Phó Sự Cố Dữ Liệu',
                        body:
                            'Kích hoạt cô lập hệ thống trong vòng 60 phút khi phát hiện sự cố. Báo cáo cơ quan nhà nước có thẩm quyền trong vòng 72 giờ theo Luật định và thông báo khẩn cấp đến cư dân qua app.',
                      ),
                      _PolicySectionCard(
                        number: '7',
                        title: 'Liên Hệ Bộ Phận Bảo Vệ Dữ Liệu (DPO)',
                        body:
                            'Email tiếp nhận: security@vivona.vn\nĐơn vị vận hành: Ban Quản Trị & Giải Pháp PropTech Vivona.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _PolicySectionCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _PolicySectionCard({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.slate700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
