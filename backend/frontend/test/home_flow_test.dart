import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vocablock_ui/l10n/generated/app_localizations.dart';
import 'package:vocablock_ui/providers/app_state.dart';
import 'package:vocablock_ui/screens/home_screen.dart';
import 'package:vocablock_ui/widgets/diagnostics_panel.dart';
import 'package:vocablock_ui/widgets/passive_panel.dart';

// Drives the real HomeScreen widget tree against a real (loopback) HTTP server:
// tap the sidebar, read the panel, rate a passive card, open the homework sheet.
// This is the closest thing to clicking through the running app that a test can
// do — and it would have caught the sidebar overflow that hid the last two
// entries at 720p.
/// Real sockets, but no keep-alive: the default client parks idle connections
/// behind a 3-second timer, which flutter_test reports as a leaked Timer once
/// the widget tree is disposed.
class _NoKeepAliveOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.idleTimeout = Duration.zero;
    return client;
  }
}

void main() {
  late HttpServer server;
  final posts = <String, List<Map<String, dynamic>>>{};

  Map<String, dynamic> respond(String path) {
    switch (path) {
      case '/api/v1/config/languages':
        return {'value': ['ja']};
      case '/api/v1/config':
        return {'theme': 'vs-dark', 'interface_lang': 'zh-CN'};
      case '/api/v1/ai/profile':
        return {'configured': false};
      case '/api/v1/quiz/plan':
        return {'id': null};
      case '/api/v1/quiz/progress':
        return {'reviewed_today': 3, 'remaining': 5, 'daily_target': 20};
      case '/api/v1/quiz/today-stats':
        return {'reviewed': 3, 'correct': 2, 'accuracy': 0.67};
      case '/api/v1/stats/heatmap':
        return <String, dynamic>{};
      case '/api/v1/words':
        return {'words': <dynamic>[], 'total': 0};
      case '/api/v1/stats/diagnostics':
        return {
          'days': 30,
          'by_category': {'similarity': 3},
          'weak_phonemes': {'ɕ': 2},
          'phoneme_samples': 4,
          'ai_disagreement': {'ai_verdicts': 5, 'wrong_but_exact_hit': 1, 'samples': ['a|a']},
          'type_rates': {
            'choice': {'total': 8, 'correct': 7},
          },
          'coverage': {'total_words': 127, 'pending_review': 7, 'long_term_words': 30},
        };
      case '/api/v1/system/passive-q':
        return {'word_id': 42, 'word': '猫', 'reading': 'ねこ', 'meaning': 'cat'};
      case '/api/v1/system/passive-submit':
        return {'accepted': true};
      case '/api/v1/quiz/assignment':
        return {
          'assignments': <dynamic>[],
          'reason': 'ai_required',
          'message': 'AI required for assignments',
        };
      default:
        return <String, dynamic>{};
    }
  }

  setUp(() async {
    // flutter_test installs an HttpClient that answers 400 to everything; the
    // whole point here is a real request against a real socket.
    HttpOverrides.global = _NoKeepAliveOverrides();
    posts.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      if (body.isNotEmpty) {
        try {
          posts.putIfAbsent(req.uri.path, () => []).add(jsonDecode(body) as Map<String, dynamic>);
        } catch (_) {}
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(respond(req.uri.path)));
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 120)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('sidebar reaches diagnostics, passive and homework at 720p', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState(apiPort: '${server.port}', authToken: 'test-token');
    await tester.runAsync(() => state.init());

    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ));
    await tester.pump();

    // The two new entries must be inside the viewport, not just in the tree:
    // a ListView happily builds items the user can never reach.
    for (final icon in [Icons.monitor_heart_outlined, Icons.style_outlined]) {
      final f = find.byIcon(icon);
      expect(f, findsOneWidget, reason: 'sidebar icon $icon missing');
      final rect = tester.getRect(f);
      expect(rect.top, greaterThanOrEqualTo(0), reason: 'icon $icon above viewport');
      expect(rect.bottom, lessThanOrEqualTo(720), reason: 'icon $icon below the fold');
    }

    // ——— Diagnostics ———
    await tester.tap(find.byIcon(Icons.monitor_heart_outlined));
    await tester.pump();
    await settle(tester);
    expect(find.byType(DiagnosticsPanel), findsOneWidget);
    expect(find.text('学习诊断'), findsOneWidget);
    expect(find.text('错因分布'), findsOneWidget);
    expect(find.text('形近 / 音近'), findsOneWidget);
    expect(find.text('127'), findsOneWidget); // coverage.total_words
    expect(find.text('20.0%'), findsOneWidget); // AI false-negative rate 1/5

    // ——— Passive recall: reveal, then rate ———
    await tester.tap(find.byIcon(Icons.style_outlined));
    await tester.pump();
    await settle(tester);
    expect(find.byType(PassivePanel), findsOneWidget);
    expect(find.text('猫'), findsOneWidget);
    expect(find.text('cat'), findsNothing); // meaning stays hidden until reveal

    await tester.tap(find.text('显示释义'));
    await tester.pump();
    expect(find.text('cat'), findsOneWidget);

    await tester.tap(find.text('记得'));
    await settle(tester);
    final submitted = posts['/api/v1/system/passive-submit']!;
    expect(submitted.single['word_id'], 42);
    expect(submitted.single['recall'], 'easy');

    // ——— Homework: the sheet must explain the AI requirement ———
    await tester.tap(find.byIcon(Icons.assignment));
    await settle(tester);
    expect(find.text('作业需要 AI —— 请先在设置里配置。'), findsOneWidget);

    // Let the HTTP client's idle-connection timer fire; otherwise flutter_test
    // reports it as a TimersPending invariant failure after the tree is gone.
    await tester.pump(const Duration(seconds: 5));
  });
}
