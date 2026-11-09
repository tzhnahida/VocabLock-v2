import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/tool_sidebar.dart';
import '../widgets/glass_background.dart';
import '../widgets/dashboard_panel.dart';
import 'quiz_session_page.dart';
import '../widgets/words_panel.dart';
import '../widgets/stats_panel.dart';
import '../widgets/audio_panel.dart';
import '../widgets/config_panel.dart';
import '../widgets/ai_chat_panel.dart';
import '../widgets/pending_review_panel.dart';
import '../widgets/assignment_sheet.dart';
import '../models/assignment.dart';
import '../models/word.dart';
import '../utils/audio_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTool = -1;
  late final AppAudioPlayer _player = AppAudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _showQuiz(AppState state) {
    final quizApi = state.quizApi;
    final ttsApi = state.ttsApi;
    final baseUrl = state.baseUrl ?? 'http://127.0.0.1:8080';
    final token = state.token ?? '';
    final player = _player;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSessionPage(
          onSessionStart: () => quizApi?.sessionStart(language: state.activeLangCode) ?? Future.value(null),
          onNextQuestion: () => state.getNextQuestion(),
          onSubmit: ({required questionId, required subjectType, required subjectId, required questionType, required answer, audio, study}) =>
              state.submitAnswer(questionId: questionId, subjectType: subjectType, subjectId: subjectId, questionType: questionType, answer: answer, audio: audio, study: study ?? false),
          onGetStudyWords: () => state.getStudyWords(),
          onGetStudyGrammar: () => state.getStudyGrammarPoints(),
          onPlayWordAudio: (wordId) async {
            if (ttsApi == null) return;
            final result = await ttsApi.getWordAudio(wordId);
            final status = result['status'] as String? ?? '';
            if (status != 'ok') return;
            final url = result['url'] as String? ?? '';
            if (url.isEmpty) return;
            final fullUrl = '$baseUrl$url${url.contains('?') ? '&' : '?'}token=$token';
            await player.playUrl(fullUrl);
          },
          onPlayTextAudio: (text) async {
            if (ttsApi == null || text.isEmpty) return;
            final result = await ttsApi.getTextAudio(text);
            final status = result['status'] as String? ?? '';
            if (status != 'ok') return;
            final url = result['url'] as String? ?? '';
            if (url.isEmpty) return;
            final fullUrl = '$baseUrl$url${url.contains('?') ? '&' : '?'}token=$token';
            await player.playUrl(fullUrl);
          },
          onDispute: (logId) => state.quizApi?.dispute(logId) ?? Future.value(),
          onContinueSession: () => state.quizApi?.continueSession() ?? Future.value(),
          onGetFieldConfig: () async {
            if (state.configApi == null) return [];
            try {
              final lc = await state.configApi!.getLanguageConfig(state.activeLangCode);
              final base = (lc['word_fields_base'] as List<dynamic>?)
                      ?.map((e) => WordFieldConfig.fromJson(e as Map<String, dynamic>))
                      .toList() ??
                  [];
              final dlc = WordFieldConfig.listFromDLC(lc['word_fields_dlc'] as List<dynamic>?);
              return [...base, ...dlc];
            } catch (_) {
              return [];
            }
          },
          onSummarize: quizApi != null
              ? () => quizApi.summarize(language: state.activeLangCode)
              : null,
          onComplete: () {
            state.completeDaily();
          },
        ),
        fullscreenDialog: true,
      ),
    ).then((_) {
      state.refresh();
    });
  }

  void _onToolSelected(int index, AppState state) {
    if (index == 0) {
      _showQuiz(state);
      return;
    }
    if (index == 7) {
      _showAssignment(state);
      return;
    }
    setState(() => _activeTool = index);
  }

  void _showAssignment(AppState state) {
    final quizApi = state.quizApi;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignmentSheet(
        onGetAssignments: () => quizApi?.getAssignment(language: state.activeLangCode) ?? Future.value(const AssignmentBatch(assignments: [])),
        onSubmit: ({required assignmentId, required answer}) =>
            quizApi?.submitAssignment(assignmentId: assignmentId, answer: answer) ??
            Future.value(const AssignmentGrade(original: '', corrected: '', score: 0)),
        onGetCadence: () => quizApi?.getCadence(language: state.activeLangCode) ??
            Future.value(const CadenceRecommendation(cadenceDays: 3, cadenceCount: 2)),
        onDone: () {
          Navigator.pop(context);
          state.refresh();
        },
      ),
    );
  }

  Widget _buildPanel(AppState state, double width) {
    final lang = state.activeLangCode;
    final baseUrl = state.baseUrl ?? 'http://127.0.0.1:8080';
    final token = state.token ?? '';

    // Show completion view when on dashboard and daily is completed
    if (_activeTool < 0 && state.dailyCompleted) {
      return _CompletionView(state: state, width: width, onQuiz: () => _showQuiz(state));
    }

    switch (_activeTool) {
      case 1: return WordsPanel(
        key: ValueKey('words_$lang'),
        state: state,
        onPlayWordAudio: (wordId) async {
          if (state.ttsApi == null) return;
          final result = await state.ttsApi!.getWordAudio(wordId);
          final status = result['status'] as String? ?? '';
          if (status != 'ok') return;
          final url = result['url'] as String? ?? '';
          if (url.isEmpty) return;
          final fullUrl = '$baseUrl$url${url.contains('?') ? '&' : '?'}token=$token';
          await _player.playUrl(fullUrl);
        },
        onPlayTextAudio: (text) async {
          if (state.ttsApi == null || text.isEmpty) return;
          final result = await state.ttsApi!.getTextAudio(text);
          final status = result['status'] as String? ?? '';
          if (status != 'ok') return;
          final url = result['url'] as String? ?? '';
          if (url.isEmpty) return;
          final fullUrl = '$baseUrl$url${url.contains('?') ? '&' : '?'}token=$token';
          await _player.playUrl(fullUrl);
        },
      );
      case 2: return AudioPanel(key: ValueKey('audio_$lang'), state: state);
      case 3: return StatsPanel(key: ValueKey('stats_$lang'), state: state);
      case 4: return ConfigPanel(key: ValueKey('config_$lang'), state: state);
      case 5: return AIChatPanel(key: ValueKey('ai_$lang'), state: state);
      case 6: return PendingReviewPanel(key: ValueKey('review_$lang'), state: state);
      default: return DashboardPanel(key: ValueKey('dash_$lang'), state: state, width: width, onStartQuiz: () => _showQuiz(state));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final languages = state.languages;
        if (languages.isEmpty) {
          if (!state.serverReachable) {
            // Backend unreachable on first load — offer retry instead of
            // an endless spinner. (Previously the app showed a permanent
            // CircularProgressIndicator with no way out.)
            return Scaffold(
              backgroundColor: AppTheme.bgColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.serverOfflineBanner,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => state.refresh(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(AppLocalizations.of(context)!.retry),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          backgroundColor: AppTheme.bgColor,
          body: Column(
            children: [
              if (!state.serverReachable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.red.shade800,
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(AppLocalizations.of(context)!.serverOfflineBanner,
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () => state.refresh(),
                        child: Text(AppLocalizations.of(context)!.retry,
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
            builder: (context, constraints) {
              final sidebarWidth = 72.0;
              final contentWidth = constraints.maxWidth - sidebarWidth;
              return Row(
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: ToolSidebar(
                      activeToolIndex: _activeTool,
                      onToolSelected: (i) => _onToolSelected(i, state),
                      activeLangCode: state.activeLangCode,
                      langCodes: state.langCodes,
                      onLangChanged: (i) => state.switchLanguage(i),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (_activeTool < 0) const GlassBackground(),
                        _buildPanel(state, contentWidth),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
            ),
          ],
        ),
        );
      },
    );
  }
}

class _CompletionView extends StatelessWidget {
  final AppState state;
  final double width;
  final VoidCallback onQuiz;

  const _CompletionView({required this.state, required this.width, required this.onQuiz});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final todayStats = state.todayStats;
    final accuracy = todayStats != null ? (todayStats.accuracy * 100).toInt() : 0;
    final reviewed = todayStats?.reviewed ?? 0;
    final correct = todayStats?.correct ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: 28),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: AppTheme.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              accuracy >= 80 ? l10n.completionCongrats : l10n.completionDone,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniStat(label: l10n.statAnswered, value: '$reviewed'),
                const SizedBox(width: 32),
                _MiniStat(label: l10n.statCorrect, value: '$correct'),
                const SizedBox(width: 32),
                _MiniStat(label: l10n.statAccuracy, value: '$accuracy%'),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              l10n.completionHint,
              style: TextStyle(fontSize: 14, color: AppTheme.textHint),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onQuiz,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.practiceAgain),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
      ],
    );
  }
}
