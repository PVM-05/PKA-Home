import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/services/push_notification_service.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/accessibility_provider.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'core/utils/provider_logger.dart';
import 'data/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await SupabaseConfig.initialize();

  // Khởi tạo Firebase (FCM) an toàn
  try {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    debugPrint("Firebase chưa thể khởi tạo: $e");
  }

  await initializeDateFormatting('vi', null);
  timeago.setLocaleMessages('vi', timeago.ViMessages());
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
    // Tự động đồng bộ FCM token khi người dùng đăng nhập
    ref.watch(fcmTokenSyncProvider);

    final fontScale = ref.watch(fontSizeScaleProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Quản lý Chung cư',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('vi', 'VN'),
      builder: (context, child) {
        final systemScale = MediaQuery.of(context).textScaler.scale(1.0);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(systemScale * fontScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
