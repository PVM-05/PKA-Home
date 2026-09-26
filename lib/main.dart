import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/accessibility_provider.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'core/utils/provider_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await SupabaseConfig.initialize();
  runApp(
    ProviderScope(
      observers: [ProviderLogger()],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontSizeScaleProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Quản lý Chung cư',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
