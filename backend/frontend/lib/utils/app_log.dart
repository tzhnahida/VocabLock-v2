import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Forwards log messages to the Go backend's POST /api/v1/debug/log
/// so they appear inline in the Go server terminal output.
///
/// Runs a dedicated drain loop (Timer-based) so every message is sent
/// via a fully-await-ed HttpClient request — no fire-and-forget.
class AppLog {
  static String _baseUrl = '';
  static bool _init = false;
  static Stopwatch _sw = Stopwatch()..start();

  static final _queue = <String>[];
  static Timer? _timer;

  static void init(String apiPort) {
    _init = true;
    _baseUrl = 'http://127.0.0.1:$apiPort';
    // Drain queue every 200ms
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _drain());
    debug('AppLog.init: baseUrl=$_baseUrl');
  }

  static void debug(String msg) {
    final ts = _sw.elapsedMilliseconds;
    _enqueue('[$ts ms] $msg');
  }

  static void _enqueue(String line) {
    if (!_init) return;
    if (_queue.length < 500) _queue.add(line);
  }

  static Future<void> _drain() async {
    if (_queue.isEmpty) return;

    // Take up to 10 messages this tick
    final batch = <String>[];
    for (var i = 0; i < 10 && _queue.isNotEmpty; i++) {
      batch.add(_queue.removeAt(0));
    }

    final payload = jsonEncode({
      'level': 'debug',
      'messages': batch,
    });

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final uri = Uri.parse('$_baseUrl/api/v1/debug/log');
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 2));
      req.headers.set('Content-Type', 'application/json');
      req.write(utf8.encode(payload));
      final resp = await req.close().timeout(const Duration(seconds: 2));
      await resp.drain();
      client.close();
    } catch (_) {}
  }
}
