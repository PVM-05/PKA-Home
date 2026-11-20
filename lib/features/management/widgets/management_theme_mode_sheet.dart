import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/core/theme/theme_mode_provider.dart';

void showManagementThemeModeSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final currentMode = ref.watch(themeModeProvider);
          final entries = [
            (
              ThemeMode.system,
              'Theo hệ thống',
              Icons.brightness_auto,
              'Tự động theo cài đặt thiết bị',
            ),
            (
              ThemeMode.light,
              'Sáng',
              Icons.light_mode,
              'Luôn dùng giao diện sáng',
            ),
            (ThemeMode.dark, 'Tối', Icons.dark_mode, 'Luôn dùng giao diện tối'),
          ];

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chọn giao diện',
                  style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...entries.map(
                  (entry) =>
                      // ignore: deprecated_member_use
                      RadioListTile<ThemeMode>(
                        value: entry.$1,
                        // ignore: deprecated_member_use
                        groupValue: currentMode,
                        // ignore: deprecated_member_use
                        onChanged: (mode) {
                          if (mode != null) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(mode);
                            Navigator.pop(ctx);
                          }
                        },
                        title: Row(
                          children: [
                            Icon(entry.$3, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(entry.$2)),
                          ],
                        ),
                        subtitle: Text(
                          entry.$4,
                          style: ctx.bodySmall,
                        ),
                        activeColor: AppTheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}
