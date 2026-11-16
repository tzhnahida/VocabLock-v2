import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vocablock_ui/l10n/generated/app_localizations.dart';
import 'package:vocablock_ui/models/diagnostics.dart';
import 'package:vocablock_ui/providers/app_state.dart';
import 'package:vocablock_ui/widgets/diagnostics_panel.dart';
import 'package:vocablock_ui/widgets/passive_panel.dart';

Widget _host(Widget child) => ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SizedBox(width: 900, height: 640, child: child)),
      ),
    );

// The diagnostics JSON contract is owned by backend/internal/db/diagnostics.go.
// These tests pin the shape the panel relies on, so a backend field rename
// fails here instead of silently rendering an empty panel.
void main() {
  test('Diagnostics parses the backend payload', () {
    final d = Diagnostics.fromJson({
      'days': 30,
      'by_category': {'similarity': 4, 'empty': 1},
      'weak_phonemes': {'ɕ': 3, 'ɯ': 1},
      'phoneme_samples': 2,
      'ai_disagreement': {
        'ai_verdicts': 10,
        'wrong_but_exact_hit': 2,
        'samples': ['aaa|aaa'],
      },
      'type_rates': {
        'choice': {'total': 10, 'correct': 8},
        'spelling': {'total': 4, 'correct': 1},
      },
      'coverage': {'total_words': 120, 'pending_review': 5, 'long_term_words': 30},
    });

    expect(d.days, 30);
    expect(d.wrongAnswers, 5);
    expect(d.categoriesDesc.first.key, 'similarity');
    expect(d.categoriesDesc.first.value, 4);
    expect(d.phonemesDesc.first.key, 'ɕ');
    expect(d.phonemeSamples, 2);
    expect(d.aiDisagreement!.falseNegativeRate, closeTo(0.2, 1e-9));
    // Weakest question type sorts first — that is the row worth reading.
    expect(d.typesByAccuracy.first.key, 'spelling');
    expect(d.typeRates['choice']!.accuracy, closeTo(0.8, 1e-9));
    expect(d.coverage.longTermShare, closeTo(0.25, 1e-9));
    expect(d.isEmpty, isFalse);
  });

  test('Diagnostics tolerates absent sections', () {
    final d = Diagnostics.fromJson({'days': 7});
    expect(d.days, 7);
    expect(d.byCategory, isEmpty);
    expect(d.weakPhonemes, isEmpty);
    expect(d.aiDisagreement, isNull);
    expect(d.typeRates, isEmpty);
    expect(d.coverage.totalWords, 0);
    expect(d.isEmpty, isTrue);
  });

  testWidgets('DiagnosticsPanel builds without backend', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (c) {
      return DiagnosticsPanel(state: Provider.of<AppState>(c));
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DiagnosticsPanel), findsOneWidget);
    expect(find.text('还没有可诊断的数据'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PassivePanel builds without backend', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (c) {
      return PassivePanel(state: Provider.of<AppState>(c));
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PassivePanel), findsOneWidget);
    expect(find.text('当前没有到期的词'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
