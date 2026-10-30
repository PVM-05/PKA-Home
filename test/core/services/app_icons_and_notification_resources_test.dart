import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Launcher Icons and Notification Icons Verification Tests', () {
    test('Master icon assets exist in assets/icons/', () {
      final appIcon = File('assets/icons/app_icon.png');
      final appIconForeground = File('assets/icons/app_icon_foreground.png');
      final notifIcon = File('assets/icons/notification_icon.png');

      expect(appIcon.existsSync(), isTrue, reason: 'assets/icons/app_icon.png must exist');
      expect(appIcon.lengthSync(), greaterThan(1024), reason: 'app_icon.png must not be empty');

      expect(appIconForeground.existsSync(), isTrue, reason: 'assets/icons/app_icon_foreground.png must exist');
      expect(appIconForeground.lengthSync(), greaterThan(1024), reason: 'app_icon_foreground.png must not be empty');

      expect(notifIcon.existsSync(), isTrue, reason: 'assets/icons/notification_icon.png must exist');
      expect(notifIcon.lengthSync(), greaterThan(512), reason: 'notification_icon.png must not be empty');
    });

    test('Android Adaptive Icon and Mipmap files exist', () {
      final adaptiveXml = File('android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml');
      expect(adaptiveXml.existsSync(), isTrue, reason: 'Adaptive icon XML must exist for Android 8+');

      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final launcherPng = File('android/app/src/main/res/mipmap-$density/launcher_icon.png');
        expect(launcherPng.existsSync(), isTrue, reason: 'launcher_icon.png must exist in mipmap-$density');
      }
    });

    test('Android Notification Drawables exist across all density buckets and vector XML', () {
      final vectorXml = File('android/app/src/main/res/drawable/ic_notification.xml');
      expect(vectorXml.existsSync(), isTrue, reason: 'Vector drawable ic_notification.xml must exist');
      final xmlContent = vectorXml.readAsStringSync();
      expect(xmlContent, contains('android:pathData'), reason: 'Vector must contain path data');
      expect(xmlContent, contains('#FFFFFFFF'), reason: 'Vector must use pure white monochrome for status bar');

      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final notifPng = File('android/app/src/main/res/drawable-$density/ic_notification.png');
        expect(notifPng.existsSync(), isTrue, reason: 'ic_notification.png must exist in drawable-$density');
        expect(notifPng.lengthSync(), greaterThan(100), reason: 'Drawable must not be empty');
      }
    });

    test('AndroidManifest.xml configures default_notification_icon to @drawable/ic_notification', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      expect(manifest.existsSync(), isTrue);

      final content = manifest.readAsStringSync();
      expect(content, contains('com.google.firebase.messaging.default_notification_icon'));
      expect(content, contains('@drawable/ic_notification'));
      expect(content, contains('android:icon="@mipmap/launcher_icon"'));
    });

    test('PushNotificationService uses @drawable/ic_notification', () {
      final serviceFile = File('lib/core/services/push_notification_service.dart');
      expect(serviceFile.existsSync(), isTrue);

      final content = serviceFile.readAsStringSync();
      expect(content, contains("AndroidInitializationSettings('@drawable/ic_notification')"));
      expect(content, contains("icon: '@drawable/ic_notification'"));
    });
  });
}

