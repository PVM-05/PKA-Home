import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/repositories/notification_repository.dart';
import '../router/route_names.dart';

/// Kênh thông báo Android ưu tiên cao nhất: Có chuông, rung và banner nổi
const AndroidNotificationChannel pkaHomeNotificationChannel = AndroidNotificationChannel(
  'pka_home_high_importance_channel',
  'Thông báo PKA-Home',
  description: 'Kênh nhận thông báo hóa đơn, sự cố và bảo trì tòa nhà có âm thanh và rung chuông.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

/// Top-level background message handler cho FCM (bắt buộc phải là top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    debugPrint('Đã nhận thông báo ngầm (FCM): ${message.messageId} - ${message.notification?.title}');
  } catch (e) {
    debugPrint('Lỗi xử lý thông báo ngầm: $e');
  }
}

/// Dịch vụ quản lý thông báo đẩy Firebase Cloud Messaging (FCM) & Trung tâm thông báo
class PushNotificationService {
  final NotificationRepository _notificationRepo;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  PushNotificationService(this._notificationRepo);

  bool _isLocalNotificationsInitialized = false;

  /// Đảm bảo plugin local notifications và notification channel luôn được khởi tạo trước khi gọi show
  Future<void> ensureLocalNotificationsInitialized([
    void Function(String route)? onSelectNotificationRoute,
  ]) async {
    if (_isLocalNotificationsInitialized) return;
    await _setupLocalNotifications(onSelectNotificationRoute);
    _isLocalNotificationsInitialized = true;
  }

  /// Kiểm tra an toàn xem Firebase đã được khởi tạo hay chưa
  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  /// Khởi tạo an toàn (Fail-safe): Tự động bắt lỗi nếu chạy trên môi trường test,
  /// Windows desktop hoặc thiết bị chưa có dịch vụ Google Play.
  Future<void> safeInitialize({
    required String userId,
    void Function(String route)? onSelectNotificationRoute,
  }) async {
    try {
      // 1. Khởi tạo Android Notification Channel và Local Notifications cho hiển thị Heads-up & Âm thanh
      await ensureLocalNotificationsInitialized(onSelectNotificationRoute);

      if (!isFirebaseInitialized) {
        debugPrint('Firebase chưa được khởi tạo. Bỏ qua cấu hình FCM Push Notification.');
        return;
      }

      final fcm = FirebaseMessaging.instance;

      // 2. Xin quyền nhận thông báo (Android 13+ POST_NOTIFICATIONS và iOS)
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('Người dùng đã cấp quyền nhận thông báo.');

        // 3. Lấy Device Token từ Google
        final token = await fcm.getToken();
        if (token != null) {
          debugPrint('FCM Device Token: $token');
          await registerTokenManually(
            userId: userId,
            token: token,
            deviceInfo: _getPlatformName(),
          );
        }

        // 4. Lắng nghe cập nhật token khi Google làm mới
        fcm.onTokenRefresh.listen((newToken) async {
          debugPrint('FCM Token đã được làm mới: $newToken');
          await registerTokenManually(
            userId: userId,
            token: newToken,
            deviceInfo: _getPlatformName(),
          );
        });

        // 5. Cấu hình hiển thị thông báo khi app đang mở (Foreground) trên iOS
        await fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // 6. Lắng nghe thông báo khi ứng dụng đang mở (Foreground) để hiện thông báo hệ thống có âm thanh
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showForegroundSystemNotification(message);
        });
      } else {
        debugPrint('Người dùng từ chối quyền nhận thông báo.');
      }
    } catch (e, stackTrace) {
      debugPrint('Không thể khởi tạo FCM: $e\n$stackTrace');
    }
  }

  /// Cấu hình Local Notifications và Android Channel
  Future<void> _setupLocalNotifications(
    void Function(String route)? onSelectNotificationRoute,
  ) async {
    try {
      if (kIsWeb) return;
      if (!Platform.isAndroid && !Platform.isIOS) return;

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null && details.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(details.payload!);
              final route = resolveRouteFromNotification(data);
              onSelectNotificationRoute?.call(route);
            } catch (_) {}
          }
        },
      );

      // Đăng ký kênh âm thanh cao cấp trên Android và xin quyền thông báo
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(pkaHomeNotificationChannel);
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Lỗi thiết lập Local Notification Channel: $e');
    }
  }

  /// Hiển thị thông báo trên thanh trạng thái Android có âm thanh và rung chuông khi app đang mở
  Future<void> _showForegroundSystemNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      await ensureLocalNotificationsInitialized();

      final android = message.notification?.android;
      debugPrint('🔔 [FCM Foreground] Nhận thông báo: "${notification.title}" - "${notification.body}"');

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            pkaHomeNotificationChannel.id,
            pkaHomeNotificationChannel.name,
            channelDescription: pkaHomeNotificationChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            styleInformation: notification.body != null
                ? BigTextStyleInformation(
                    notification.body!,
                    contentTitle: notification.title,
                  )
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
      debugPrint('✅ [FCM Foreground] Đã phát thông báo hệ thống Android thành công');
    } catch (e, stack) {
      debugPrint('❌ [FCM Foreground] Lỗi hiển thị thông báo foreground: $e\n$stack');
    }
  }

  /// Hiển thị thông báo trên thanh trạng thái Android có âm thanh và rung chuông từ dữ liệu thông báo
  Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      if (kIsWeb) return;
      if (!Platform.isAndroid && !Platform.isIOS) return;

      await ensureLocalNotificationsInitialized();

      debugPrint('🔔 [Hệ thống] Đang phát thông báo Android: "$title" - "$body"');

      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            pkaHomeNotificationChannel.id,
            pkaHomeNotificationChannel.name,
            channelDescription: pkaHomeNotificationChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload != null ? jsonEncode(payload) : null,
      );
      debugPrint('✅ [Hệ thống] Đã gửi thông báo Android thành công (id: $id)');
    } catch (e, stack) {
      debugPrint('❌ [Hệ thống] Lỗi hiển thị thông báo hệ thống: $e\n$stack');
    }
  }

  /// Đăng ký Token thiết bị thủ công vào Supabase CSDL
  Future<void> registerTokenManually({
    required String userId,
    required String token,
    String? deviceInfo,
  }) async {
    try {
      await _notificationRepo.registerFcmToken(
        userId: userId,
        token: token,
        deviceInfo: deviceInfo ?? _getPlatformName(),
      );
    } catch (e) {
      debugPrint('Lỗi đăng ký FCM token lên Supabase: $e');
    }
  }

  /// Phân tích dữ liệu thông báo và trả về Route điều hướng phù hợp trong ứng dụng
  String resolveRouteFromNotification(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    switch (type) {
      case 'new_invoice':
      case 'invoice_due_reminder':
        return AppRoutes.residentInvoices;
      case 'equipment_maintenance':
        return AppRoutes.residentHome;
      case 'issue_update':
        return AppRoutes.residentIssues;
      case 'announcement':
        return AppRoutes.residentHandbook;
      default:
        return AppRoutes.residentNotifications;
    }
  }

  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isLinux) return 'Linux';
    } catch (_) {}
    return 'Unknown';
  }
}

/// Provider cho PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return PushNotificationService(repo);
});
