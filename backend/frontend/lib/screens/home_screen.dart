import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/glass_background.dart';
import '../widgets/progress_card.dart';
import '../widgets/stat_bubble.dart';
import '../widgets/review_list.dart';
import '../widgets/language_switcher.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              final sidebarWidth = (constraints.maxWidth * 0.22).clamp(220.0, 280.0);
              final contentWidth = constraints.maxWidth - sidebarWidth;
              return Row(
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: Sidebar(
                      languages: languages,
                      activeIndex: state.activeLanguageIndex,
                      onLanguageSelected: (i) => state.switchLanguage(i),
                    ),
                  ),
                  Expanded(
                    child: _MainCanvas(state: state, width: contentWidth),
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

class _MainCanvas extends StatelessWidget {
  final AppState state;
  final double width;

  const _MainCanvas({required this.state, required this.width});

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final bubbleStats = state.bubbleStats;
    final mistakes = state.recentMistakes;
    final languages = state.languages;

    final barHeights = List.generate(14, (_) => Random().nextDouble() * 0.8 + 0.2);

    return Stack(
      children: [
        const GlassBackground(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(state: state),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: ReviewList(words: mistakes),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: LanguageSwitcher(
                        languages: languages,
                        activeIndex: state.activeLanguageIndex,
                        onSwitch: (i) => state.switchLanguage(i),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _bubbleLabel(String key) {
    switch (key) {
      case 'listening':
        return 'Listening';
      case 'reading_comp':
        return 'Reading';
      case 'grammar':
        return 'Grammar';
      default:
        return key;
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
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final lang = state.activeLanguage;
    final todayStats = state.todayStats;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              lang?.label ?? 'VocabLock',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Row(
          children: [
            _StatChip(label: 'Accuracy', value: '${((todayStats?.accuracy ?? 0) * 100).toInt()}%'),
            const SizedBox(width: 16),
            _StatChip(label: 'Streak', value: '3 days'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
