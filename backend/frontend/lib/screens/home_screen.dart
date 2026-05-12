import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/tool_sidebar.dart';
import '../widgets/glass_background.dart';
import '../widgets/dashboard_panel.dart';
import '../widgets/quiz_sheet.dart';
import '../widgets/words_panel.dart';
import '../widgets/stats_panel.dart';
import '../widgets/audio_panel.dart';
import '../widgets/config_panel.dart';
import '../widgets/ai_chat_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTool = -1;

  void _showQuiz(AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuizSheet(
        onNextQuestion: () => state.getNextQuestion(),
        onSubmit: ({required questionId, required wordId, required questionType, required answer}) =>
            state.submitAnswer(questionId: questionId, wordId: wordId, questionType: questionType, answer: answer),
        onGetStudyWords: () => state.getStudyWords(),
        onDone: () {
          Navigator.pop(context);
          state.refresh();
        },
        onComplete: () {
          Navigator.pop(context);
          state.completeDaily();
        },
      ),
    );
  }

  void _onToolSelected(int index, AppState state) {
    if (index == 0) {
      _showQuiz(state);
      return;
    }
    setState(() => _activeTool = index);
  }

  Widget _buildPanel(AppState state, double width) {
    final lang = state.activeLangCode;

    // Show completion view when on dashboard and daily is completed
    if (_activeTool < 0 && state.dailyCompleted) {
      return _CompletionView(state: state, width: width, onQuiz: () => _showQuiz(state));
    }

    switch (_activeTool) {
      case 1: return WordsPanel(key: ValueKey('words_$lang'), state: state);
      case 2: return AudioPanel(key: ValueKey('audio_$lang'), state: state);
      case 3: return StatsPanel(key: ValueKey('stats_$lang'), state: state);
      case 4: return ConfigPanel(key: ValueKey('config_$lang'), state: state);
      case 5: return AIChatPanel(key: ValueKey('ai_$lang'), state: state);
      default: return DashboardPanel(key: ValueKey('dash_$lang'), state: state, width: width, onStartQuiz: () => _showQuiz(state));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final languages = state.languages;
        if (languages.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          backgroundColor: AppTheme.bgColor,
          body: LayoutBuilder(
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
              accuracy >= 80 ? '恭喜完成今日学习！' : '今日任务完成',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniStat(label: '答题', value: '$reviewed'),
                const SizedBox(width: 32),
                _MiniStat(label: '正确', value: '$correct'),
                const SizedBox(width: 32),
                _MiniStat(label: '正确率', value: '$accuracy%'),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              '你可以继续浏览单词、使用AI助手或查看统计。',
              style: TextStyle(fontSize: 14, color: AppTheme.textHint),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onQuiz,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('再次练习'),
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
