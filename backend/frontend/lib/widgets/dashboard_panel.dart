import 'dart:math';
import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'progress_card.dart';
import 'stat_bubble.dart';
import 'review_list.dart';

class DashboardPanel extends StatelessWidget {
  final AppState state;
  final double width;
  final VoidCallback? onStartQuiz;

  const DashboardPanel({super.key, required this.state, required this.width, this.onStartQuiz});

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final bubbleStats = state.bubbleStats;
    final mistakes = state.recentMistakes;
    final barHeights = List.generate(14, (_) => Random().nextDouble() * 0.8 + 0.2);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(state: state, onStartQuiz: onStartQuiz),
          const SizedBox(height: 24),
          if (progress != null)
            ProgressCard(
              reviewed: progress.reviewedToday,
              target: progress.dailyTarget,
              barHeights: barHeights,
            ),
          const SizedBox(height: 24),
          if (bubbleStats.isNotEmpty)
            SizedBox(
              height: 170,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: bubbleStats.entries.map((e) {
                  final colors = _bubbleColors(bubbleStats.keys.toList().indexOf(e.key));
                  return StatBubble(
                    label: _bubbleLabel(e.key),
                    value: e.value,
                    gradientColors: colors,
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 28),
          Expanded(
            child: ReviewList(words: mistakes),
          ),
        ],
      ),
    );
  }

  String _bubbleLabel(String key) {
    switch (key) {
      case 'listening': return 'Listening';
      case 'reading_comp': return 'Reading';
      case 'grammar': return 'Grammar';
      default: return key;
    }
  }

  List<Color> _bubbleColors(int index) {
    final palettes = [
      AppTheme.accentGradient,
      [AppTheme.primary, AppTheme.accent],
      AppTheme.warmGradient,
    ];
    return palettes[index % palettes.length];
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  final VoidCallback? onStartQuiz;
  const _Header({required this.state, this.onStartQuiz});

  @override
  Widget build(BuildContext context) {
    final lang = state.activeLanguage;
    final todayStats = state.todayStats;
    final remaining = state.progress?.remaining ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang?.label ?? 'VocabLock', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(
              remaining > 0 ? '剩余 $remaining 题' : '今日任务完成',
              style: TextStyle(fontSize: 13, color: AppTheme.textHint),
            ),
          ],
        ),
        Row(
          children: [
            _StatChip(label: 'Accuracy', value: '${((todayStats?.accuracy ?? 0) * 100).toInt()}%'),
            const SizedBox(width: 12),
            if (remaining > 0 && onStartQuiz != null)
              ElevatedButton.icon(
                onPressed: onStartQuiz,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('测试'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
        ],
      ),
    );
  }
}
