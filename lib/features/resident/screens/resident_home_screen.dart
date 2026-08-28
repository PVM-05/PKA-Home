import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../widgets/invoice_summary.dart';
import '../widgets/notification_card.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/announcement_provider.dart';
import 'resident_invoice_screen.dart';
import 'resident_issue_screen.dart';
import 'resident_profile_screen.dart';

class ResidentHomeScreen extends ConsumerStatefulWidget {
  const ResidentHomeScreen({super.key});

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
        title: Text('Xin chào, ${user?.fullName ?? 'Cư dân'}'),
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
          const ResidentInvoiceScreen(),
          const ResidentIssueScreen(),
          const ResidentProfileScreen(),
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
    final announcementsAsync = ref.watch(announcementsStreamProvider);

    return ListView(
      children: [
        const InvoiceSummary(
          totalAmount: 1500000,
          unpaidCount: 1,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Text(
            'Thông báo mới nhất',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        announcementsAsync.when(
          data: (announcements) {
            if (announcements.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Không có thông báo nào.'),
              );
            }
            return Column(
              children: announcements.map((announcement) {
                return NotificationCard(
                  title: announcement.title,
                  content: announcement.content,
                  date: '${announcement.createdAt.day}/${announcement.createdAt.month}/${announcement.createdAt.year}',
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Lỗi tải thông báo: $error')),
        ),
      ],
    );
  }
}
