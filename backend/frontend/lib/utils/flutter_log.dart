import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Sends log messages to the Go backend's /debug/log endpoint so they
/// appear in the unified server output stream.
class FlutterLog {
  static Future<void> Function(String message, {String level})? _send;

  /// Configure the log sender (called once during init with the API client).
  static void init(Future<void> Function(String url, {Map<String, dynamic>? body}) post) {
    _send = (msg, {level = 'debug'}) async {
      try {
        await post('/api/v1/debug/log', body: {
          'level': level,
          'message': msg,
        });
      } catch (_) {
        // Silently drop log failures — don't break the app
      }
    };
  }

  static void debug(String msg) {
    debugPrint('[flutter] $msg');
    _send?.call(msg, level: 'debug');
  }

  static void info(String msg) {
    debugPrint('[flutter] $msg');
    _send?.call(msg, level: 'info');
  }

  static void warn(String msg) {
    debugPrint('[flutter] $msg');
    _send?.call(msg, level: 'warn');
  }
}
