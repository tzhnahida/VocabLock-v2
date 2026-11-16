import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vocablock_ui/l10n/generated/app_localizations.dart';
import 'package:vocablock_ui/models/assignment.dart';
import 'package:vocablock_ui/models/session_summary.dart';
import 'package:vocablock_ui/providers/app_state.dart';
import 'package:vocablock_ui/widgets/ai_chat_panel.dart';
import 'package:vocablock_ui/widgets/assignment_sheet.dart';
import 'package:vocablock_ui/widgets/audio_panel.dart';
import 'package:vocablock_ui/widgets/config_panel.dart';
import 'package:vocablock_ui/widgets/pending_review_panel.dart';
import 'package:vocablock_ui/widgets/session_summary_view.dart';
import 'package:vocablock_ui/widgets/stats_panel.dart';
import 'package:vocablock_ui/widgets/words_panel.dart';

// Smoke coverage for the panel UI: every panel must build without exceptions
// when the backend is unavailable (AppState without API connection) — the
// same state a misconfigured app ends in. Previously panels had zero tests.
Widget _host(Widget child) => ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SizedBox(width: 900, height: 640, child: child)),
      ),
    );

void main() {
  testWidgets('WordsPanel builds without backend', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (c) {
      final s = Provider.of<AppState>(c);
      return WordsPanel(key: const ValueKey('w'), state: s, onPlayWordAudio: (_) async {}, onPlayTextAudio: (_) async {});
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WordsPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatsPanel builds without backend', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (c) {
      return StatsPanel(state: Provider.of<AppState>(c));
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AudioPanel builds without backend', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (c) {
      return AudioPanel(state: Provider.of<AppState>(c));
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AudioPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AIChatPanel builds without backend', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (c) {
      return AIChatPanel(state: Provider.of<AppState>(c));
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AIChatPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PendingReviewPanel builds without backend', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (c) {
      return PendingReviewPanel(state: Provider.of<AppState>(c));
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PendingReviewPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ConfigPanel builds without backend', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (c) {
      return ConfigPanel(state: Provider.of<AppState>(c));
    })));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ConfigPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AssignmentSheet renders empty state', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AssignmentSheet(
            onGetAssignments: () async => const AssignmentBatch(assignments: []),
            onSubmit: ({required assignmentId, required answer}) async =>
                const AssignmentGrade(original: '', corrected: '', score: 0),
            onGetCadence: () async => const CadenceRecommendation(cadenceDays: 3, cadenceCount: 2),
            onDone: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AssignmentSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SessionSummaryView renders summary and failure states', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SessionSummaryView(
          summary: const SessionSummary(
            summary: {
              'today_summary': {'overall': 'ok', 'strengths': 'a', 'weaknesses': 'b'},
              'suggestions': ['keep going'],
            },
          ),
          loading: false,
          onRetry: () {},
          onDismiss: () {},
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('AI 学习总结'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Failure state (summary == null)
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SessionSummaryView(summary: null, loading: false, onRetry: () {}, onDismiss: () {}),
      ),
    ));
    await tester.pump();
    expect(find.text('AI 分析失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
