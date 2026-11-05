import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_environment.dart';
import '../supabase_config.dart';

/// Mức độ nghiêm trọng của sự cố vận hành
enum AlertSeverity {
  info,
  warning,
  critical;

  String get label {
    switch (this) {
      case AlertSeverity.critical:
        return 'CRITICAL';
      case AlertSeverity.warning:
        return 'WARNING';
      case AlertSeverity.info:
        return 'INFO';
    }
  }
}

/// Kênh phân phối cảnh báo
enum AlertDispatchChannel {
  telegram,
  slack,
}

/// Cấu trúc dữ liệu sự cố cảnh báo
class OperationalAlert {
  final String title;
  final String message;
  final AlertSeverity severity;
  final String? errorCode;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  OperationalAlert({
    required this.title,
    required this.message,
    required this.severity,
    this.errorCode,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Khóa gom cụm phục vụ cơ chế chống bão cảnh báo (Throttling)
  String get deduplicationKey => '${severity.name}:${errorCode ?? title}';
}

/// Kết quả phân phối cảnh báo
class AlertDispatchResult {
  final bool isSuccess;
  final bool isThrottled;
  final String? errorMessage;
  final Map<AlertDispatchChannel, bool> channelResults;

  const AlertDispatchResult.success({
    this.channelResults = const {},
  })  : isSuccess = true,
        isThrottled = false,
        errorMessage = null;

  const AlertDispatchResult.throttled({
    required this.errorMessage,
  })  : isSuccess = false,
        isThrottled = true,
        channelResults = const {};

  const AlertDispatchResult.failure({
    required this.errorMessage,
    this.channelResults = const {},
  })  : isSuccess = false,
        isThrottled = false;
}

/// Trạng thái sức khỏe hệ thống (Uptime & Kết nối)
class SystemHealthStatus {
  final bool isHealthy;
  final int latencyMs;
  final String message;
  final DateTime checkedAt;

  SystemHealthStatus({
    required this.isHealthy,
    required this.latencyMs,
    required this.message,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? DateTime.now();
}

/// Dịch vụ gửi cảnh báo sự cố vận hành và giám sát uptime
class OperationalAlertService {
  final AppEnvironment environment;
  final http.Client httpClient;
  final SupabaseClient? supabaseClient;
  final Future<bool> Function()? pingFunction;
  final Duration cooldownDuration;

  final Map<String, DateTime> _lastAlertTimes = {};

  OperationalAlertService({
    AppEnvironment? environment,
    http.Client? httpClient,
    this.supabaseClient,
    this.pingFunction,
    this.cooldownDuration = const Duration(seconds: 60),
  })  : environment = environment ?? AppEnvironment.current,
        httpClient = httpClient ?? http.Client();

  /// Xóa bộ đệm throttling phục vụ kiểm thử
  void clearThrottlingCache() {
    _lastAlertTimes.clear();
  }

  /// Định dạng nội dung HTML gửi Telegram Bot
  String formatTelegramHtml(OperationalAlert alert) {
    final buffer = StringBuffer();
    buffer.writeln('<b>[PKA-HOME] CẢNH BÁO: ${alert.severity.label}</b>');
    buffer.writeln('<b>Môi trường:</b> ${environment.displayName}');
    if (alert.errorCode != null && alert.errorCode!.isNotEmpty) {
      buffer.writeln('<b>Mã lỗi:</b> ${alert.errorCode}');
    }
    buffer.writeln('<b>Tiêu đề:</b> ${alert.title}');
    buffer.writeln('<b>Chi tiết:</b> ${alert.message}');
    if (alert.metadata != null && alert.metadata!.isNotEmpty) {
      buffer.writeln('<b>Dữ liệu phụ:</b>');
      alert.metadata!.forEach((k, v) {
        buffer.writeln('  • $k: $v');
      });
    }
    buffer.writeln('<b>Thời gian:</b> ${alert.timestamp.toIso8601String()}');
    return buffer.toString().trim();
  }

  /// Định dạng payload JSON gửi Slack/Discord Webhook
  Map<String, dynamic> formatSlackPayload(OperationalAlert alert) {
    final textFallback = '[PKA-HOME - ${alert.severity.label}]: ${alert.title}';
    final metadataFormatted = alert.metadata != null && alert.metadata!.isNotEmpty
        ? alert.metadata!.entries.map((e) => '• *${e.key}:* ${e.value}').join('\n')
        : 'Không có';

    return {
      'text': textFallback,
      'blocks': [
        {
          'type': 'header',
          'text': {
            'type': 'plain_text',
            'text': 'CẢNH BÁO HỆ THỐNG PKA-HOME [${alert.severity.label}]',
          },
        },
        {
          'type': 'section',
          'fields': [
            {
              'type': 'mrkdwn',
              'text': '*Môi trường:*\n${environment.displayName}',
            },
            {
              'type': 'mrkdwn',
              'text': '*Mã lỗi:*\n${alert.errorCode ?? "N/A"}',
            },
          ],
        },
        {
          'type': 'section',
          'text': {
            'type': 'mrkdwn',
            'text': '*${alert.title}*\n${alert.message}',
          },
        },
        {
          'type': 'section',
          'text': {
            'type': 'mrkdwn',
            'text': '*Dữ liệu đính kèm:*\n$metadataFormatted',
          },
        },
        {
          'type': 'context',
          'elements': [
            {
              'type': 'mrkdwn',
              'text': 'Thời điểm phát hiện: ${alert.timestamp.toIso8601String()}',
            },
          ],
        },
      ],
    };
  }

  /// Gửi cảnh báo vận hành tới các kênh được cấu hình
  Future<AlertDispatchResult> sendAlert(OperationalAlert alert) async {
    final now = DateTime.now();
    final key = alert.deduplicationKey;

    // 1. Cơ chế Debouncing / Throttling chống spam cảnh báo
    if (_lastAlertTimes.containsKey(key)) {
      final lastSent = _lastAlertTimes[key]!;
      final elapsed = now.difference(lastSent);
      if (elapsed < cooldownDuration) {
        final remainingSeconds = cooldownDuration.inSeconds - elapsed.inSeconds;
        return AlertDispatchResult.throttled(
          errorMessage: 'Cảnh báo "$key" đang bị khóa lặp trong $remainingSeconds giây để chống bão tin nhắn.',
        );
      }
    }

    final channelResults = <AlertDispatchChannel, bool>{};

    // 2. Gửi Telegram nếu có cấu hình
    if (environment.telegramBotToken.isNotEmpty && environment.telegramChatId.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://api.telegram.org/bot${environment.telegramBotToken}/sendMessage',
        );
        final response = await httpClient.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chat_id': environment.telegramChatId,
            'text': formatTelegramHtml(alert),
            'parse_mode': 'HTML',
          }),
        );
        channelResults[AlertDispatchChannel.telegram] = response.statusCode == 200;
      } catch (e) {
        debugPrint('[CẢNH BÁO] Không thể gửi tới Telegram: $e');
        channelResults[AlertDispatchChannel.telegram] = false;
      }
    }

    // 3. Gửi Slack Webhook nếu có cấu hình
    if (environment.slackWebhookUrl.isNotEmpty) {
      try {
        final url = Uri.parse(environment.slackWebhookUrl);
        final response = await httpClient.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(formatSlackPayload(alert)),
        );
        channelResults[AlertDispatchChannel.slack] =
            response.statusCode >= 200 && response.statusCode < 300;
      } catch (e) {
        debugPrint('[CẢNH BÁO] Không thể gửi tới Slack: $e');
        channelResults[AlertDispatchChannel.slack] = false;
      }
    }

    // Cập nhật timestamp gửi gần nhất
    _lastAlertTimes[key] = now;

    // Nếu không cấu hình kênh nào thì log môi trường dev và báo thành công
    if (channelResults.isEmpty) {
      if (environment.enableDebugLogging) {
        debugPrint('[CẢNH BÁO GIẢ LẬP]: [${alert.severity.label}] ${alert.title}: ${alert.message}');
      }
      return const AlertDispatchResult.success();
    }

    final isAnySuccess = channelResults.values.any((success) => success);
    if (isAnySuccess) {
      return AlertDispatchResult.success(channelResults: channelResults);
    } else {
      return AlertDispatchResult.failure(
        errorMessage: 'Không thể phân phối cảnh báo tới bất kỳ kênh nào đã cấu hình.',
        channelResults: channelResults,
      );
    }
  }

  /// Kiểm tra sức khỏe kết nối CSDL và đo độ trễ mạng
  Future<SystemHealthStatus> checkHealthStatus() async {
    final stopwatch = Stopwatch()..start();
    try {
      final ping = pingFunction;
      if (ping != null) {
        final ok = await ping();
        stopwatch.stop();
        if (ok) {
          return SystemHealthStatus(
            isHealthy: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: 'Bình thường (Độ trễ: ${stopwatch.elapsedMilliseconds}ms)',
          );
        } else {
          return SystemHealthStatus(
            isHealthy: false,
            latencyMs: stopwatch.elapsedMilliseconds,
            message: 'Phản hồi kiểm tra không hợp lệ',
          );
        }
      }

      final client = supabaseClient ?? (SupabaseConfig.isConfigured ? SupabaseConfig.client : null);
      if (client == null) {
        stopwatch.stop();
        return SystemHealthStatus(
          isHealthy: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'SupabaseClient chưa được khởi tạo hoặc cấu hình thiếu',
        );
      }

      // Ping nhẹ nhàng tới bảng hệ thống hoặc kiểm tra phiên đăng nhập
      await client.from('apartments').select('id').limit(1);
      stopwatch.stop();

      return SystemHealthStatus(
        isHealthy: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Bình thường (Độ trễ: ${stopwatch.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      stopwatch.stop();
      return SystemHealthStatus(
        isHealthy: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Lỗi kiểm tra kết nối: $e',
      );
    }
  }
}

/// Riverpod provider cho OperationalAlertService
final operationalAlertServiceProvider = Provider<OperationalAlertService>((ref) {
  return OperationalAlertService(
    environment: AppEnvironment.current,
  );
});
