import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AdaptiveNavigationItem {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final int? badgeCount;

  const AdaptiveNavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badgeCount,
  });
}

class AdaptiveManagementScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationItem> destinations;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final double breakpoint;

  const AdaptiveManagementScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.sidebarHeader,
    this.sidebarFooter,
    this.breakpoint = 900.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= breakpoint;

        if (!isLargeScreen) {
          // Bố cục Mobile (< 900dp)
          return Scaffold(
            appBar: appBar,
            body: body,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
              destinations: destinations.map((item) {
                Widget iconWidget = Icon(item.icon);
                Widget selectedIconWidget = Icon(item.selectedIcon ?? item.icon);

                if (item.badgeCount != null && item.badgeCount! > 0) {
                  iconWidget = Badge(
                    label: Text('${item.badgeCount}'),
                    child: iconWidget,
                  );
                  selectedIconWidget = Badge(
                    label: Text('${item.badgeCount}'),
                    child: selectedIconWidget,
                  );
                }

                return NavigationDestination(
                  icon: iconWidget,
                  selectedIcon: selectedIconWidget,
                  label: item.label,
                );
              }).toList(),
            ),
          );
        }

        // Bố cục Màn hình Lớn (Web / Desktop >= 900dp)
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final sidebarBg = isDark ? AppTheme.slate900 : Colors.white;
        final sidebarBorder = isDark 
            ? Colors.white.withValues(alpha: 0.08) 
            : Colors.black.withValues(alpha: 0.07);

        return Scaffold(
          floatingActionButton: floatingActionButton,
          body: Row(
            children: [
              // Sidebar cố định bên trái (chuẩn Enterprise SaaS 260dp)
              Container(
                width: 260,
                decoration: BoxDecoration(
                  color: sidebarBg,
                  border: Border(
                    right: BorderSide(
                      color: sidebarBorder,
                      width: 1.0,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sidebarHeader != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: sidebarHeader!,
                      ),
                      Divider(height: 1, color: sidebarBorder),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppGradients.brandPrimary,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: AppShadows.cardGlow,
                              ),
                              child: const Icon(
                                Icons.apartment_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Vivona',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.emerald,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Hệ thống Quản lý Tòa nhà',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white70 : AppTheme.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: sidebarBorder),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: destinations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final item = destinations[index];
                          final isSelected = index == selectedIndex;

                          Widget leadingIcon = Icon(
                            isSelected
                                ? (item.selectedIcon ?? item.icon)
                                : item.icon,
                            color: isSelected
                                ? AppTheme.primary
                                : (isDark ? Colors.white70 : AppTheme.textSecondary),
                            size: 20,
                          );

                          if (item.badgeCount != null && item.badgeCount! > 0) {
                            leadingIcon = Badge(
                              label: Text('${item.badgeCount}'),
                              backgroundColor: AppTheme.rose,
                              child: leadingIcon,
                            );
                          }

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onDestinationSelected(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(
                                        color: AppTheme.primary.withValues(alpha: isDark ? 0.4 : 0.25),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  leadingIcon,
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? (isDark ? Colors.white : AppTheme.primary)
                                            : (isDark ? Colors.white70 : AppTheme.textPrimary),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      width: 4,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (sidebarFooter != null) ...[
                      Divider(height: 1, color: sidebarBorder),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: sidebarFooter!,
                      ),
                    ],
                  ],
                ),
              ),

              // Khu vực nội dung chính (chống dãn vô tận trên 2K/4K)
              Expanded(
                child: Column(
                  children: [
                    ?appBar,
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1600),
                          child: body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
