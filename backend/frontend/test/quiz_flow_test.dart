import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocablock_ui/l10n/generated/app_localizations.dart';
import 'package:vocablock_ui/models/question.dart';
import 'package:vocablock_ui/models/quiz_result.dart';
import 'package:vocablock_ui/models/session_summary.dart';
import 'package:vocablock_ui/models/training_plan.dart';
import 'package:vocablock_ui/screens/quiz_session_page.dart';

Question _choiceQ() => Question(
      id: 'wc101',
      type: QuestionType.choice,
      subjectType: 'word',
      subjectId: 101,
      prompt: '「食べる」的意思是什么？',
      options: const ['吃', '喝', '睡', '走'],
    );

Widget _app(QuizSessionPage page) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: page,
    );

void main() {
  testWidgets('choice answer then next keeps working', (WidgetTester tester) async {
    var nextCount = 0;
    var submitCount = 0;
    await tester.pumpWidget(_app(QuizSessionPage(
      onSessionStart: () async =>
          {'new_words': 0, 'new_grammar': 0, 'review_words': 2, 'review_grammar': 0, 'daily_completed': false},
      onNextQuestion: () async {
        nextCount++;
        return _choiceQ();
      },
      onSubmit: ({required questionId, required subjectType, required subjectId, required questionType, required answer, audio, bool? study}) async {
        submitCount++;
        return const SubmitResult(correct: true, score: 1.0, feedback: 'Correct!');
      },
      onGetStudyWords: () async => [],
      onPlayWordAudio: (id) async {},
      onPlayTextAudio: (text) async {},
    )));
    await tester.pumpAndSettle();

    // Overview → start learning (no new words → quiz directly)
    expect(find.text('今日学习'), findsOneWidget);
    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle();
    expect(nextCount, 1);

    // Answer question 1
    await tester.tap(find.text('吃'));
    await tester.pumpAndSettle();
    expect(submitCount, 1);
    expect(find.text('Correct!'), findsOneWidget);

    // Next question
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    expect(nextCount, 2);

    // Answer question 2
    await tester.tap(find.text('吃'));
    await tester.pumpAndSettle();
    expect(submitCount, 2);

    // Repeat once more — the loop must stay alive
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    expect(nextCount, 3);
  });

  testWidgets('completed → completion screen with AI summary entry', (WidgetTester tester) async {
    var nexts = 0;
    var summaries = 0;
    await tester.pumpWidget(_app(QuizSessionPage(
      onSessionStart: () async =>
          {'new_words': 0, 'new_grammar': 0, 'review_words': 2, 'review_grammar': 0, 'daily_completed': false},
      onNextQuestion: () async {
        nexts++;
        // Backend serves ONE more item, then signals daily target met (null).
        return nexts > 1 ? null : _choiceQ();
      },
      onSubmit: ({required questionId, required subjectType, required subjectId, required questionType, required answer, audio, bool? study}) async =>
          const SubmitResult(correct: true, score: 1.0, feedback: 'Correct!'),
      onGetStudyWords: () async => [],
      onPlayWordAudio: (id) async {},
      onPlayTextAudio: (text) async {},
      onSummarize: () async {
        summaries++;
        return const SessionSummary(
          summary: {
            'today_summary': {'overall': '稳定', 'strengths': '词汇全对', 'weaknesses': '发音待练'},
            'suggestions': ['保持每日练习'],
          },
          plan: TrainingPlan(id: 1, direction: 'general', directionConfidence: 0.8, planJson: '{}'),
        );
      },
      onComplete: () {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始学习'));
    await tester.pumpAndSettle();

    // Answer the only item
    await tester.tap(find.text('吃'));
    await tester.pumpAndSettle();
    // Next → backend returns null (daily target met) → completion screen
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();

    // _Phase.complete must be reachable now (was dead code before the fix)
    expect(find.text('恭喜完成今日学习！'), findsOneWidget);
    final accuracyLabel = find.textContaining('正确率');
    expect(accuracyLabel, findsWidgets);

    // AI summary entry point
    await tester.tap(find.text('查看 AI 学习总结'));
    await tester.pumpAndSettle();
    expect(summaries, 1);
    expect(find.text('AI 学习总结'), findsOneWidget);
    expect(find.textContaining('发音待练'), findsOneWidget);
  });
}
