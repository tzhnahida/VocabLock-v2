import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocablock_ui/api/api_client.dart';
import 'package:vocablock_ui/api/stats_api.dart';
import 'package:vocablock_ui/api/system_api.dart';

// Real-HTTP tests for the three endpoints the new panels depend on. They run a
// throwaway server on loopback, so they catch the failure a widget test cannot:
// a client that sends nothing (passiveSubmit used to POST an empty body) or a
// query the panel forgot to pass.
void main() {
  late HttpServer server;
  final seen = <String, Map<String, dynamic>>{};

  Map<String, dynamic> respond(String path) {
    switch (path) {
      case '/api/v1/stats/diagnostics':
        return {
          'days': 7,
          'by_category': {'similarity': 2},
          'weak_phonemes': {'ɕ': 1},
          'phoneme_samples': 1,
          'ai_disagreement': {
            'ai_verdicts': 4,
            'wrong_but_exact_hit': 1,
            'samples': ['a|a'],
          },
          'type_rates': {
            'choice': {'total': 4, 'correct': 3},
          },
          'coverage': {'total_words': 9, 'pending_review': 2, 'long_term_words': 3},
        };
      case '/api/v1/system/passive-q':
        return {'word_id': 42, 'word': '猫', 'reading': 'ねこ', 'meaning': 'cat'};
      case '/api/v1/system/passive-submit':
        return {'accepted': true};
      default:
        return {};
    }
  }

  setUp(() async {
    seen.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      seen[req.uri.path] = {
        'method': req.method,
        'body': body,
        'query': req.uri.query,
      };
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(respond(req.uri.path)));
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  ApiClient client() =>
      ApiClient(baseUrl: 'http://127.0.0.1:${server.port}', token: 'test-token');

  test('getDiagnostics parses a live payload and forwards the window', () async {
    final d = await StatsApi(client()).getDiagnostics(days: 7, language: 'ja');

    expect(seen['/api/v1/stats/diagnostics']!['query'], contains('days=7'));
    expect(d.days, 7);
    expect(d.wrongAnswers, 2);
    expect(d.categoriesDesc.first.key, 'similarity');
    expect(d.phonemesDesc.first.key, 'ɕ');
    expect(d.aiDisagreement!.aiVerdicts, 4);
    expect(d.aiDisagreement!.falseNegativeRate, closeTo(0.25, 1e-9));
    expect(d.typeRates['choice']!.accuracy, closeTo(0.75, 1e-9));
    expect(d.coverage.totalWords, 9);
    expect(d.isEmpty, isFalse);
  });

  test('getPassiveQ returns the due word', () async {
    final q = await SystemApi(client()).getPassiveQ();
    expect(q['word_id'], 42);
    expect(q['word'], '猫');
    expect(q['meaning'], 'cat');
  });

  test('passiveSubmit sends word_id and recall', () async {
    final ok = await SystemApi(client()).passiveSubmit(wordId: 42, recall: 'hard');
    expect(ok, isTrue);

    final sent = seen['/api/v1/system/passive-submit']!;
    expect(sent['method'], 'POST');
    final body = jsonDecode(sent['body'] as String) as Map<String, dynamic>;
    expect(body['word_id'], 42);
    expect(body['recall'], 'hard');
  });
}
