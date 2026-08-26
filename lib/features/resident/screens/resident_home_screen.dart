import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../widgets/invoice_summary.dart';
import '../widgets/notification_card.dart';
import '../../auth/providers/auth_provider.dart';

class ResidentHomeScreen extends ConsumerStatefulWidget {
  const ResidentHomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends ConsumerState<ResidentHomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Xin chào, ${user?.hoTen ?? 'Cư dân'}'),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.sign_out_24_regular),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          const Center(child: Text('Trang Hóa đơn')),
          const Center(child: Text('Trang Phản ánh')),
          const Center(child: Text('Trang Tài khoản')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(FluentIcons.home_24_regular),
            activeIcon: Icon(FluentIcons.home_24_filled),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(FluentIcons.receipt_24_regular),
            activeIcon: Icon(FluentIcons.receipt_24_filled),
            label: 'Hóa đơn',
          ),
          BottomNavigationBarItem(
            icon: Icon(FluentIcons.chat_warning_24_regular),
            activeIcon: Icon(FluentIcons.chat_warning_24_filled),
            label: 'Phản ánh',
          ),
          BottomNavigationBarItem(
            icon: Icon(FluentIcons.person_24_regular),
            activeIcon: Icon(FluentIcons.person_24_filled),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      children: const [
        InvoiceSummary(
          totalAmount: 1500000,
          unpaidCount: 1,
        ),
        Padding(
          padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Text(
            'Thông báo mới nhất',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        NotificationCard(
          title: 'Cắt nước toàn tòa nhà để bảo trì',
          content: 'Kính gửi Quý cư dân, ban quản lý sẽ tiến hành cắt nước từ 8h00 đến 12h00 ngày mai để bảo trì hệ thống máy bơm.',
          date: '26/08/2026',
        ),
        NotificationCard(
          title: 'Thu phí quản lý tháng 8',
          content: 'Ban quản lý đã lên hóa đơn phí quản lý tháng 8. Quý cư dân vui lòng thanh toán trước ngày 05/09.',
          date: '25/08/2026',
        ),
      ],
    );
  }
}
