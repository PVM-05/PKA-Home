import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../widgets/stat_card.dart';
import '../../auth/providers/auth_provider.dart';

class ManagementHomeScreen extends ConsumerStatefulWidget {
  const ManagementHomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManagementHomeScreen> createState() => _ManagementHomeScreenState();
}

class _ManagementHomeScreenState extends ConsumerState<ManagementHomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ban Quản Lý'),
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
          const Center(child: Text('Danh sách Cư dân')),
          const Center(child: Text('Quản lý Hóa đơn')),
          const Center(child: Text('Xử lý Phản ánh')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(FluentIcons.data_bar_vertical_24_regular),
            activeIcon: Icon(FluentIcons.data_bar_vertical_24_filled),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(FluentIcons.people_24_regular),
            activeIcon: Icon(FluentIcons.people_24_filled),
            label: 'Cư dân',
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
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: const [
        StatCard(
          title: 'Phản ánh mới',
          value: '5',
          icon: FluentIcons.warning_24_filled,
          color: Colors.orange,
        ),
        StatCard(
          title: 'Tổng nợ phí',
          value: '15 Tr',
          icon: FluentIcons.money_24_filled,
          color: Colors.redAccent,
        ),
        StatCard(
          title: 'Số căn hộ',
          value: '120',
          icon: FluentIcons.building_24_filled,
          color: Colors.blue,
        ),
        StatCard(
          title: 'Đã thanh toán',
          value: '85%',
          icon: FluentIcons.checkmark_circle_24_filled,
          color: Colors.green,
        ),
      ],
    );
  }
}
