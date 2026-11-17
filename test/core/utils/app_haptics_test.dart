import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/utils/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      log.add(methodCall);
      return null;
    });
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('AppHaptics Tests', () {
    test('light invokes HapticFeedback.lightImpact', () async {
      await AppHaptics.light();
      expect(log, isNotEmpty);
      expect(log.last.method, 'HapticFeedback.vibrate');
      expect(log.last.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('medium invokes HapticFeedback.mediumImpact', () async {
      await AppHaptics.medium();
      expect(log, isNotEmpty);
      expect(log.last.method, 'HapticFeedback.vibrate');
      expect(log.last.arguments, 'HapticFeedbackType.mediumImpact');
    });

    test('heavy invokes HapticFeedback.heavyImpact', () async {
      await AppHaptics.heavy();
      expect(log, isNotEmpty);
      expect(log.last.method, 'HapticFeedback.vibrate');
      expect(log.last.arguments, 'HapticFeedbackType.heavyImpact');
    });

    test('selection invokes HapticFeedback.selectionClick', () async {
      await AppHaptics.selection();
      expect(log, isNotEmpty);
      expect(log.last.method, 'HapticFeedback.vibrate');
      expect(log.last.arguments, 'HapticFeedbackType.selectionClick');
    });

    test('success invokes feedback pattern without error', () async {
      await AppHaptics.success();
      expect(log, isNotEmpty);
    });

    test('error invokes feedback pattern without error', () async {
      await AppHaptics.error();
      expect(log, isNotEmpty);
    });
  });
}
