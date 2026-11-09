import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
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
    final barHeights = List.generate(14, (i) => Random(i * 31 + DateTime.now().day).nextDouble() * 0.7 + 0.3);

    // Scrollable: on 720p window heights the fixed header (60) + progress
    // card (180) + bubbles (170) overflow by ~180px — the old Column
    // rendered a RenderFlex overflow (invisible in release, yellow/black
    // stripes in debug) and clipped the Recent Mistakes list.
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(state: state, onStartQuiz: onStartQuiz),
          if (state.expanding || state.expandStatus.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ExpandBanner(state: state, onRetry: () => state.expandWords(count: 10)),
          ],
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
                    display: _bubbleDisplay(e.key, e.value),
                    value: _bubbleRatio(e.key, e.value),
                    gradientColors: colors,
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(child: ReviewList(words: mistakes)),
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

  /// Bubbles carry two value contracts: ratios (0–1, rendered as %,
  /// e.g. Accuracy / mock AI-type ratios) and raw counts (rendered as
  /// integers, e.g. Correct/Remaining/Target from the real dashboard path).
  /// Keys known to be ratios render as percentages; everything else is a count.
  static const _ratioKeys = {'Accuracy', 'listening', 'reading_comp', 'grammar'};

  String _bubbleDisplay(String key, double v) {
    if (_ratioKeys.contains(key)) return '${(v * 100).toInt()}%';
    return v.round().toString();
  }

  /// Sizing ratio: percentages use the value directly, counts are
  /// normalized against the daily target so bubbles stay comparable.
  double _bubbleRatio(String key, double v) {
    if (_ratioKeys.contains(key)) return v.clamp(0.0, 1.0).toDouble();
    final target = state.progress?.dailyTarget ?? 20;
    if (target <= 0) return v.clamp(0.2, 1.0).toDouble();
    return (v / target).clamp(0.2, 1.0).toDouble();
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
    final l10n = AppLocalizations.of(context);
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
              remaining > 0 ? l10n.statusRemaining(remaining) : l10n.statusDailyComplete,
              style: TextStyle(fontSize: 13, color: AppTheme.textHint),
            ),
          ],
        ),
        Row(
          children: [
            _StatChip(label: AppLocalizations.of(context).labelAccuracy, value: '${((todayStats?.accuracy ?? 0) * 100).toInt()}%'),
            const SizedBox(width: 12),
            if (remaining > 0 && onStartQuiz != null)
              ElevatedButton.icon(
                onPressed: onStartQuiz,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(l10n.quizStart),
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

class _ExpandBanner extends StatelessWidget {
  final AppState state;
  final VoidCallback onRetry;
  const _ExpandBanner({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final expanding = state.expanding;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: expanding
            ? AppTheme.primary.withValues(alpha: 0.06)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expanding
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.green.shade100,
        ),
      ),
      child: Row(
        children: [
          if (expanding)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(Icons.check_circle, size: 20, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.expandStatus,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: expanding ? AppTheme.primary : Colors.green.shade800),
                ),
                if (state.expandTotal > 0 && !expanding) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.statusWordsReady(state.expandVerified),
                    style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                  ),
                ],
              ],
            ),
          ),
          if (!expanding && state.expandTotal == 0)
            TextButton(onPressed: onRetry, child: Text(l10n.labelRetry, style: TextStyle(fontSize: 12, color: AppTheme.primary))),
        ],
      ),
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
