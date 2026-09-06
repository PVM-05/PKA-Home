import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/handbook_provider.dart';
import '../../../data/models/emergency_contact_model.dart';

class ResidentHandbookScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const ResidentHandbookScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<ResidentHandbookScreen> createState() => _ResidentHandbookScreenState();
}

class _ResidentHandbookScreenState extends ConsumerState<ResidentHandbookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể thực hiện cuộc gọi đến $phoneNumber')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở ứng dụng điện thoại cho số: $phoneNumber')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cẩm Nang Cư Dân'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.emergency_outlined), text: 'Đường dây nóng'),
            Tab(icon: Icon(Icons.gavel_outlined), text: 'Nội quy tòa nhà'),
            Tab(icon: Icon(Icons.pool_outlined), text: 'Tiện ích chung'),
            Tab(icon: Icon(Icons.help_outline), text: 'Biểu phí & FAQ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmergencyContactsTab(),
          _buildBuildingRulesTab(),
          _buildBuildingAmenitiesTab(),
          _buildFeeScheduleAndFaqTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Đường Dây Nóng
  // ===========================================================================
  Widget _buildEmergencyContactsTab() {
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(emergencyContactsProvider),
      child: contactsAsync.when(
        data: (contacts) {
          if (contacts.isEmpty) {
            return const Center(
              child: Text('Chưa có thông tin đường dây nóng.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return _buildContactCard(contact);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
      ),
    );
  }

  Widget _buildContactCard(EmergencyContactModel contact) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;

    switch (contact.contactType) {
      case 'fire':
        typeColor = AppTheme.error;
        typeIcon = Icons.local_fire_department_outlined;
        typeLabel = 'Cứu hỏa / PCCC';
        break;
      case 'management':
        typeColor = AppTheme.primary;
        typeIcon = Icons.business_outlined;
        typeLabel = 'Văn phòng BQL';
        break;
      case 'technical':
        typeColor = AppStatusColors.pending;
        typeIcon = Icons.build_outlined;
        typeLabel = 'Đội kỹ thuật';
        break;
      case 'security':
      default:
        typeColor = AppStatusColors.paid;
        typeIcon = Icons.security_outlined;
        typeLabel = 'An ninh / Bảo vệ';
        break;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStatusColors.paid,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _makePhoneCall(contact.phone),
              icon: const Icon(Icons.phone, size: 16),
              label: const Text('Gọi ngay', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Tab 2: Nội Quy Tòa Nhà
  // ===========================================================================
  Widget _buildBuildingRulesTab() {
    final rulesAsync = ref.watch(buildingRulesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildingRulesProvider),
      child: rulesAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('Chưa có nội quy được đăng tải.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      rule.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          rule.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải nội quy: $e')),
      ),
    );
  }

  // ===========================================================================
  // Tab 3: Tiện Ích Chung
  // ===========================================================================
  Widget _buildBuildingAmenitiesTab() {
    final amenitiesAsync = ref.watch(buildingAmenitiesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildingAmenitiesProvider),
      child: amenitiesAsync.when(
        data: (amenities) {
          if (amenities.isEmpty) {
            return const Center(child: Text('Chưa có tiện ích nào được cập nhật.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: amenities.length,
            itemBuilder: (context, index) {
              final amenity = amenities[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              amenity.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          if (amenity.openHours != null && amenity.openHours!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppStatusColors.paid.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time, size: 14, color: AppStatusColors.paid),
                                  const SizedBox(width: 4),
                                  Text(
                                    amenity.openHours!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppStatusColors.paid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (amenity.description != null && amenity.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          amenity.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải tiện ích: $e')),
      ),
    );
  }

  // ===========================================================================
  // Tab 4: Biểu Phí & FAQ
  // ===========================================================================
  Widget _buildFeeScheduleAndFaqTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Biểu Phí Quản Lý & Vận Hành',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildFeeRow(
                  title: 'Phí dịch vụ quản lý',
                  rate: '12.000 đ/m²/tháng',
                  formula: 'Đơn giá × Diện tích thông thủy căn hộ',
                ),
                const Divider(height: 20),
                _buildFeeRow(
                  title: 'Phí gửi xe máy',
                  rate: '100.000 đ/tháng/xe',
                  formula: 'Đăng ký tối đa 2 xe máy/căn hộ',
                ),
                const Divider(height: 20),
                _buildFeeRow(
                  title: 'Phí gửi ô tô',
                  rate: '1.200.000 đ/tháng/xe',
                  formula: 'Theo vị trí đỗ xe tại tầng hầm',
                ),
                const Divider(height: 20),
                _buildFeeRow(
                  title: 'Tiền điện sinh hoạt',
                  rate: 'Biểu giá EVN',
                  formula: 'Bậc thang theo công tơ riêng của từng căn',
                ),
                const Divider(height: 20),
                _buildFeeRow(
                  title: 'Tiền nước sạch',
                  rate: 'Theo định mức nước',
                  formula: 'Chỉ số đồng hồ đo thực tế × Đơn giá',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Câu Hỏi Thường Gặp (FAQ)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        _buildFaqItem(
          question: 'Tôi thanh toán hóa đơn bằng cách nào?',
          answer:
              'Tại màn hình Hóa đơn, nhấn "Xem chi tiết" -> "Thanh toán". Ứng dụng sẽ tự động sinh mã VietQR QuickLink chuẩn với đúng số tiền và nội dung chuyển khoản. Bạn chỉ cần mở ứng dụng ngân hàng và quét mã để hoàn tất.',
        ),
        _buildFaqItem(
          question: 'Khi gặp sự cố trong căn hộ thì xử lý thế nào?',
          answer:
              'Bạn có thể vào mục "Phản ánh" để gửi hình ảnh và mô tả sự cố cho BQL tiếp nhận. Nếu là sự cố khẩn cấp (chập điện, rò nước), vui lòng gọi ngay hotline kỹ thuật tại tab "Đường dây nóng".',
        ),
        _buildFaqItem(
          question: 'Làm thế nào để thêm thành viên cùng ở vào căn hộ?',
          answer:
              'Thành viên mới cần cài đặt app, đăng ký tài khoản với vai trò Cư dân, sau đó tại màn hình "Tài khoản của tôi" bấm "Xin liên kết căn hộ". Ban Quản Lý sẽ xác minh và phê duyệt trong vòng 24 giờ.',
        ),
      ],
    );
  }

  Widget _buildFeeRow({
    required String title,
    required String rate,
    required String formula,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                formula,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Text(
          rate,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.help_outline, color: AppTheme.primary),
          title: Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
