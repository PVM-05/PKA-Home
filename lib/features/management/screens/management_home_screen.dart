import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/dashboard_providers.dart';
import 'resident_management_screen.dart';
import 'invoice_management_screen.dart';
import 'issue_management_screen.dart';
import 'link_request_management_screen.dart';
import 'announcement_management_screen.dart';
import 'apartment_management_screen.dart';
import '../../auth/screens/change_password_screen.dart';

class ManagementHomeScreen extends ConsumerStatefulWidget {
  const ManagementHomeScreen({super.key});

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
          PopupMenuButton<String>(
            icon: const Icon(FluentIcons.person_circle_24_regular),
            onSelected: (value) {
              if (value == 'password') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                );
              } else if (value == 'logout') {
                ref.read(authProvider.notifier).logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'password',
                child: Row(
                  children: [
                    Icon(FluentIcons.key_24_regular, size: 20),
                    SizedBox(width: 8),
                    Text('Đổi mật khẩu'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(FluentIcons.sign_out_24_regular, size: 20, color: AppTheme.error),
                    SizedBox(width: 8),
                    Text('Đăng xuất', style: TextStyle(color: AppTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          const ResidentManagementScreen(),
          const InvoiceManagementScreen(),
          const IssueManagementScreen(),
          const AnnouncementManagementScreen(),
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
          BottomNavigationBarItem(
            icon: Icon(FluentIcons.alert_24_regular),
            activeIcon: Icon(FluentIcons.alert_24_filled),
            label: 'Thông báo',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final pendingIssuesAsync = ref.watch(pendingIssuesCountProvider);
    final unpaidInvoicesAsync = ref.watch(unpaidInvoicesTotalProvider);

    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        StatCard(
          title: 'Phản ánh mới',
          value: pendingIssuesAsync.when(
            data: (count) => '$count',
            loading: () => '...',
            error: (_, _) => 'Lỗi',
          ),
          icon: FluentIcons.warning_24_filled,
          color: Colors.orange,
        ),
        StatCard(
          title: 'Tổng nợ phí',
          value: unpaidInvoicesAsync.when(
            data: (total) => '${(total / 1000000).toStringAsFixed(1)} Tr',
            loading: () => '...',
            error: (_, _) => 'Lỗi',
          ),
          icon: FluentIcons.money_24_filled,
          color: Colors.redAccent,
        ),
        StatCard(
          title: 'Tổng số Căn hộ',
          value: ref.watch(totalApartmentsProvider).when(
            data: (count) => '$count',
            loading: () => '...',
            error: (_, _) => 'Lỗi',
          ),
          icon: FluentIcons.building_24_filled,
          color: Colors.blue,
        ),
        StatCard(
          title: 'Tổng Cư dân',
          value: ref.watch(totalResidentsProvider).when(
            data: (count) => '$count',
            loading: () => '...',
            error: (_, _) => 'Lỗi',
          ),
          icon: FluentIcons.people_24_filled,
          color: Colors.green,
        ),
        Card(
          color: AppTheme.primary,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LinkRequestManagementScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(FluentIcons.person_add_24_filled, color: Colors.white, size: 32),
                  Spacer(),
                  Text(
                    'Duyệt yêu cầu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Card(
          color: Colors.teal,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ApartmentManagementScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(FluentIcons.building_24_filled, color: Colors.white, size: 32),
                  Spacer(),
                  Text(
                    'Quản lý Căn hộ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
