import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/repositories/notification_repository.dart';
import '../router/route_names.dart';

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

  PushNotificationService(this._notificationRepo);

  /// Kiểm tra an toàn xem Firebase đã được khởi tạo hay chưa
  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  /// Khởi tạo an toàn (Fail-safe): Tự động bắt lỗi nếu chạy trên môi trường test,
  /// Windows desktop hoặc thiết bị chưa có dịch vụ Google Play.
  Future<void> safeInitialize({required String userId}) async {
    try {
      if (!isFirebaseInitialized) {
        debugPrint('Firebase chưa được khởi tạo. Bỏ qua cấu hình FCM Push Notification.');
        return;
      }

      final fcm = FirebaseMessaging.instance;

      // 1. Xin quyền nhận thông báo (Android 13+ và iOS)
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('Người dùng đã cấp quyền nhận thông báo.');

        // 2. Lấy device token
        final token = await fcm.getToken();
        if (token != null) {
          debugPrint('FCM Device Token: $token');
          await registerTokenManually(
            userId: userId,
            token: token,
            deviceInfo: _getPlatformName(),
          );
        }

        // 3. Lắng nghe cập nhật token khi Google làm mới
        fcm.onTokenRefresh.listen((newToken) async {
          debugPrint('FCM Token đã được làm mới: $newToken');
          await registerTokenManually(
            userId: userId,
            token: newToken,
            deviceInfo: _getPlatformName(),
          );
        });

        // 4. Cấu hình hiển thị thông báo khi app đang mở (Foreground) trên iOS
        await fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        debugPrint('Người dùng từ chối quyền nhận thông báo.');
      }
    } catch (e, stackTrace) {
      debugPrint('Không thể khởi tạo FCM: $e\n$stackTrace');
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
