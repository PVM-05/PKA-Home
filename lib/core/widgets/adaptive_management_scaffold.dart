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
        return Scaffold(
          floatingActionButton: floatingActionButton,
          body: Row(
            children: [
              // Sidebar cố định bên trái
              Container(
                width: 250,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                    right: BorderSide(
                      color: AppTheme.border,
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
                      const Divider(height: 1),
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
                                : AppTheme.textSecondary,
                            size: 20,
                          );

                          if (item.badgeCount != null && item.badgeCount! > 0) {
                            leadingIcon = Badge(
                              label: Text('${item.badgeCount}'),
                              child: leadingIcon,
                            );
                          }

                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onDestinationSelected(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
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
                                            ? AppTheme.primary
                                            : AppTheme.textPrimary,
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
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: sidebarFooter!,
                      ),
                    ],
                  ],
                ),
              ),

              // Khu vực nội dung chính
              Expanded(
                child: Column(
                  children: [
                    ?appBar,
                    Expanded(child: body),
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
