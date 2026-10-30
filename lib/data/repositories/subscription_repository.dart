import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/subscription_model.dart';
import '../models/subscription_plan_model.dart';

class SubscriptionRepository {
  final SupabaseClient? _injectedClient;

  SubscriptionRepository({SupabaseClient? client})
      : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  /// Lấy thông tin gói dịch vụ & hạn mức sử dụng của tòa nhà/tổ chức
  Future<SubscriptionStatusModel> fetchSubscriptionStatus({
    required String buildingId,
  }) async {
    final client = _client;
    if (client == null) {
      return buildOfflineFallbackStatus(buildingId: buildingId);
    }

    try {
      final response = await client.rpc(
        'get_organization_subscription_status',
        params: {'p_building_id': buildingId},
      );

      if (response is Map<String, dynamic>) {
        return SubscriptionStatusModel.fromJson(response);
      } else if (response is Map) {
        return SubscriptionStatusModel.fromJson(
          Map<String, dynamic>.from(response),
        );
      }

      return buildOfflineFallbackStatus(buildingId: buildingId);
    } catch (_) {
      return buildOfflineFallbackStatus(buildingId: buildingId);
    }
  }

  /// Lấy danh sách các gói cước đang mở bán từ CSDL
  Future<List<SubscriptionPlanModel>> fetchAvailablePlans() async {
    final client = _client;
    if (client == null) {
      return getFallbackPlans();
    }

    try {
      final response = await client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final list = <SubscriptionPlanModel>[];
      for (final item in (response as List)) {
        if (item is Map<String, dynamic>) {
          list.add(SubscriptionPlanModel.fromJson(item));
        } else if (item is Map) {
          list.add(SubscriptionPlanModel.fromJson(
            Map<String, dynamic>.from(item),
          ));
        }
      }

      return list.isNotEmpty ? list : getFallbackPlans();
    } catch (_) {
      return getFallbackPlans();
    }
  }

  /// Gửi yêu cầu nâng cấp gói dịch vụ hoặc gia hạn thuê bao
  Future<Map<String, dynamic>> requestPlanUpgrade({
    required String buildingId,
    required String targetPlanCode,
    String? contactPhone,
    String? notes,
  }) async {
    final client = _client;

    try {
      if (client != null) {
        // Ghi nhận yêu cầu vào audit log hoặc bảng thông báo
        await client.from('audit_logs').insert({
          'action': 'REQUEST_PLAN_UPGRADE',
          'entity_name': 'organization_subscriptions',
          'entity_id': buildingId,
          'details': {
            'target_plan': targetPlanCode,
            'contact_phone': contactPhone,
            'notes': notes,
            'requested_at': DateTime.now().toIso8601String(),
          },
        });
      }
    } catch (_) {
      // Bỏ qua lỗi ghi log nếu chưa cấu hình audit_logs
    }

    return {
      'success': true,
      'message':
          'Hệ thống đã tiếp nhận yêu cầu nâng cấp gói của bạn. Đội ngũ PKA-Home sẽ liên hệ hỗ trợ trong vòng 24 giờ làm việc.',
      'target_plan': targetPlanCode,
    };
  }

  // --- DỮ LIỆU DỰ PHÒNG & TÍNH TOÁN OFFLINE ---

  SubscriptionStatusModel buildOfflineFallbackStatus({
    required String buildingId,
    int totalApartments = 68,
  }) {
    final now = DateTime.now();
    final oneYearLater = now.add(const Duration(days: 365));
    final percent = ((totalApartments / 500) * 100).clamp(0.0, 100.0);

    return SubscriptionStatusModel(
      organizationId: 'canonical-org',
      subscriptionId: 'canonical-sub',
      planCode: 'pro',
      planName: 'Gói Nâng Cao',
      planDescription:
          'Lựa chọn tối ưu cho chung cư vừa và lớn (100 - 500 căn), mở khóa phân tích tài chính và đối soát tự động',
      status: 'active',
      startDate: now,
      expiresAt: oneYearLater,
      daysRemaining: 365,
      isExpiringSoon: false,
      billingCycle: 'yearly',
      autoRenew: true,
      priceMonthly: 1499000.0,
      priceYearly: 14990000.0,
      features: const {
        'batch_excel_import': true,
        'financial_aging_report': true,
        'progressive_fees': true,
        'vietqr_automated_webhook': true,
        'audit_trail': true,
      },
      usage: SubscriptionUsageMetricsModel(
        usedApartments: totalApartments,
        maxApartments: 500,
        apartmentUsagePercent: double.parse(percent.toStringAsFixed(1)),
        isNearLimit: percent >= 80.0,
        isAtLimit: totalApartments >= 500,
        usedBuildings: 1,
        maxBuildings: 5,
        usedStaff: 2,
        maxStaff: 10,
      ),
    );
  }

  List<SubscriptionPlanModel> getFallbackPlans() {
    return const [
      SubscriptionPlanModel(
        id: 'plan-starter',
        code: 'starter',
        name: 'Gói Tiêu Chuẩn',
        description:
            'Phù hợp tòa nhà chung cư mini, khu nhà trọ hoặc tòa nhà đơn lẻ dưới 100 căn hộ',
        maxApartments: 100,
        maxBuildings: 1,
        maxStaff: 2,
        priceMonthly: 499000.0,
        priceYearly: 4990000.0,
        features: {
          'batch_excel_import': true,
          'basic_invoicing': true,
          'issue_management': true,
          'vietqr_payment': true,
          'push_notifications': true,
        },
        sortOrder: 1,
      ),
      SubscriptionPlanModel(
        id: 'plan-pro',
        code: 'pro',
        name: 'Gói Nâng Cao',
        description:
            'Lựa chọn tối ưu cho chung cư 100 - 500 căn, mở khóa phân tích tài chính và đối soát tự động',
        maxApartments: 500,
        maxBuildings: 5,
        maxStaff: 10,
        priceMonthly: 1499000.0,
        priceYearly: 14990000.0,
        features: {
          'batch_excel_import': true,
          'financial_aging_report': true,
          'progressive_fees': true,
          'vietqr_automated_webhook': true,
          'audit_trail': true,
          'equipment_management': true,
        },
        sortOrder: 2,
      ),
      SubscriptionPlanModel(
        id: 'plan-enterprise',
        code: 'enterprise',
        name: 'Gói Doanh Nghiệp',
        description:
            'Giải pháp toàn diện cho chuỗi bất động sản, khu đô thị lớn với hạn mức không giới hạn',
        maxApartments: -1,
        maxBuildings: -1,
        maxStaff: -1,
        priceMonthly: 3999000.0,
        priceYearly: 39990000.0,
        features: {
          'all_features': true,
          'unlimited_units': true,
          'electronic_invoices': true,
          'dedicated_support_24_7': true,
          'api_integration': true,
        },
        sortOrder: 3,
      ),
    ];
  }
}
