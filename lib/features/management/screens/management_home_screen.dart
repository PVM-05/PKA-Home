import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../widgets/stat_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_providers.dart';
import 'resident_management_screen.dart';
import 'invoice_management_screen.dart';
import 'issue_management_screen.dart';

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
          const ResidentManagementScreen(),
          const InvoiceManagementScreen(),
          const IssueManagementScreen(),
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
            error: (_, __) => 'Lỗi',
          ),
          icon: FluentIcons.warning_24_filled,
          color: Colors.orange,
        ),
        StatCard(
          title: 'Tổng nợ phí',
          value: unpaidInvoicesAsync.when(
            data: (total) => '${(total / 1000000).toStringAsFixed(1)} Tr',
            loading: () => '...',
            error: (_, __) => 'Lỗi',
          ),
          icon: FluentIcons.money_24_filled,
          color: Colors.redAccent,
        ),
        const StatCard(
          title: 'Số căn hộ',
          value: '120',
          icon: FluentIcons.building_24_filled,
          color: Colors.blue,
        ),
        const StatCard(
          title: 'Đã thanh toán',
          value: '85%',
          icon: FluentIcons.checkmark_circle_24_filled,
          color: Colors.green,
        ),
      ],
    );
  }
}
