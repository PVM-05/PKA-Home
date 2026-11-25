import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Trình quản lý chấp thuận dữ liệu cá nhân theo Luật 91/2025/QH15 & NĐ 356/2025/NĐ-CP
class PdplConsentManager {
  static const String kConsentKey = 'pdpl_consent_v1_accepted';
  static const String kConsentTimestampKey = 'pdpl_consent_v1_accepted_at';
  static const String kConsentVersion = 'v1.0-2026';
  static bool _isShowingDialog = false;

  static String _scopedKey(String base, String? userId) =>
      (userId != null && userId.isNotEmpty) ? '${base}_$userId' : base;

  static String? _tryCurrentUserId() {
    try {
      return SupabaseConfig.isConfigured
          ? Supabase.instance.client.auth.currentUser?.id
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Kiểm tra cư dân đã chấp thuận xử lý dữ liệu hay chưa (cách ly theo từng userId trên thiết bị dùng chung)
  static Future<bool> hasConsented({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveUid = userId ?? _tryCurrentUserId();
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      return prefs.getBool(_scopedKey(kConsentKey, effectiveUid)) ?? false;
    }
    return prefs.getBool(kConsentKey) ?? false;
  }

  /// Lưu trạng thái chấp thuận vào thiết bị đồng thời đồng bộ bằng chứng pháp lý lên máy chủ Supabase
  static Future<void> saveConsent({String? userId, String? deviceInfo}) async {
    final prefs = await SharedPreferences.getInstance();
    final nowIso = DateTime.now().toIso8601String();
    final effectiveUid = userId ?? _tryCurrentUserId();

    await prefs.setBool(kConsentKey, true);
    await prefs.setString(kConsentTimestampKey, nowIso);
    if (effectiveUid != null) {
      await prefs.setBool(_scopedKey(kConsentKey, effectiveUid), true);
      await prefs.setString(_scopedKey(kConsentTimestampKey, effectiveUid), nowIso);
    }

    await _syncConsentToServer(accepted: true, deviceInfo: deviceInfo);
  }

  /// Hủy hoặc rút lại chấp thuận (phục vụ thu hồi quyền xử lý dữ liệu)
  static Future<void> revokeConsent({String? userId, String? deviceInfo}) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveUid = userId ?? _tryCurrentUserId();

    await prefs.setBool(kConsentKey, false);
    await prefs.remove(kConsentTimestampKey);
    if (effectiveUid != null) {
      await prefs.setBool(_scopedKey(kConsentKey, effectiveUid), false);
      await prefs.remove(_scopedKey(kConsentTimestampKey, effectiveUid));
    }

    await _syncConsentToServer(accepted: false, deviceInfo: deviceInfo);
  }

  static Future<void> _syncConsentToServer({
    required bool accepted,
    String? deviceInfo,
  }) async {
    try {
      if (!SupabaseConfig.isConfigured) return;
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client.rpc(
        'record_pdpl_consent',
        params: {
          'p_consent_version': kConsentVersion,
          'p_accepted': accepted,
          'p_device_info': deviceInfo,
        },
      );
    } catch (_) {
      // Không chặn trải nghiệm người dùng khi ngoại tuyến hoặc môi trường kiểm thử cục bộ
    }
  }

  /// Lấy thời điểm chấp thuận gần nhất
  static Future<String?> getConsentTimestamp({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveUid = userId ?? _tryCurrentUserId();
    if (effectiveUid != null) {
      final scoped = prefs.getString(_scopedKey(kConsentTimestampKey, effectiveUid));
      if (scoped != null) return scoped;
    }
    return prefs.getString(kConsentTimestampKey);
  }

  /// Hiển thị hộp thoại chấp thuận nếu người dùng chưa đồng ý (chống bật chồng nhiều hộp thoại)
  static Future<bool> showConsentDialogIfNeeded(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_isShowingDialog && !force) return false;
    if (!force) {
      final consented = await hasConsented();
      if (consented) return true;
    }

    if (!context.mounted) return false;
    if (_isShowingDialog && !force) return false;

    _isShowingDialog = true;
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PdplConsentDialog(),
      );
      return result ?? false;
    } finally {
      _isShowingDialog = false;
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.rMd,
                    ),
                    child: Icon(
                      Icons.security_outlined,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bảo Vệ Dữ Liệu Cá Nhân',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Căn cứ Luật 91/2025/QH15 & NĐ 356/2025/NĐ-CP',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Content List
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vivona cam kết bảo mật tuyệt đối dữ liệu cá nhân của cư dân và ban quản trị. Vui lòng đọc kỹ phạm vi và mục đích thu thập thông tin:',
                        style: textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildScopeItem(
                        context,
                        icon: Icons.badge_outlined,
                        title: 'Định danh cư dân',
                        detail:
                            'Họ tên, SĐT, số CCCD/Hộ chiếu phục vụ quản lý nhân khẩu và xác thực quyền cư trú theo Luật Nhà ở 2023.',
                      ),
                      _buildScopeItem(
                        context,
                        icon: Icons.apartment_outlined,
                        title: 'Căn hộ & Diện tích',
                        detail:
                            'Mã căn hộ (Block + Tầng + Phòng), diện tích m² phục vụ tính phí dịch vụ và quyền biểu quyết điện tử.',
                      ),
                      _buildScopeItem(
                        context,
                        icon: Icons.directions_car_outlined,
                        title: 'Phương tiện giao thông',
                        detail:
                            'Biển số xe, loại xe để kiểm soát an ninh barie và xuất vé gửi xe hàng tháng.',
                      ),
                      _buildScopeItem(
                        context,
                        icon: Icons.electric_meter_outlined,
                        title: 'Chỉ số điện & nước',
                        detail:
                            'Hình ảnh công tơ và chỉ số tiêu thụ phục vụ tính toán hóa đơn lũy tiến minh bạch.',
                      ),
                      _buildScopeItem(
                        context,
                        icon: Icons.receipt_long_outlined,
                        title: 'Lịch sử thanh toán',
                        detail:
                            'Giao dịch chuyển khoản VietQR, hóa đơn dịch vụ và sổ cái quỹ bảo trì 2%.',
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: AppRadius.rMd,
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Dữ liệu được mã hóa AES-256 trên cơ sở dữ liệu và cách ly phân quyền bằng Supabase Row Level Security (RLS). Cư dân có toàn quyền xuất bản sao kê hoặc yêu cầu đóng băng dữ liệu bất cứ lúc nào.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
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
                label: Text(
                  'Xem chi tiết Toàn văn Chính sách Bảo mật 2026',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(0, 48),
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
                        child: Text(
                          'Tôi đã đọc, hiểu rõ quyền chủ thể dữ liệu và tự nguyện đồng ý cho phép Vivona thu thập, xử lý thông tin cá nhân phục vụ vận hành tòa nhà.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.rMd,
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                'Xác nhận và Đồng ý',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
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

  Widget _buildScopeItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
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
      borderRadius: AppRadius.bottomSheet,
    ),
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      final textTheme = Theme.of(ctx).textTheme;
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
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Chính Sách Bảo Mật Dữ Liệu',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Căn cứ Luật 91/2025/QH15 & Nghị định 356/2025/NĐ-CP',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
                            '- Quyền được biết và rút lại sự đồng thuận.\n- Quyền truy cập và chỉnh sửa hồ sơ.\n- Quyền xuất dữ liệu cá nhân theo Điều 15.\n- Quyền yêu cầu xóa / đóng băng dữ liệu theo Điều 16, 17 khi chuyển đi.',
                      ),
                      _PolicySectionCard(
                        number: '6',
                        title: 'Quy Trình Ứng Phó Sự Cố Dữ Liệu',
                        body:
                            'Kích hoạt cô lập hệ thống trong vòng 60 phút khi phát hiện sự cố. Báo cáo cơ quan nhà nước có thẩm quyền trong vòng 72 giờ theo Luật định và thông báo khẩn cấp đến cư dân qua app.',
                      ),
                      _PolicySectionCard(
                        number: '7',
                        title: 'Liên Hệ Bộ Phận Bảo Vệ Dữ Liệu',
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    number,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: textTheme.bodySmall?.copyWith(
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
