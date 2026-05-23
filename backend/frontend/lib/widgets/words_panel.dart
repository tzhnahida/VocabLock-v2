import 'package:flutter/material.dart';
import '../models/word.dart';
import '../models/question.dart';
import '../providers/app_state.dart';
import '../screens/word_detail_page.dart';
import '../theme/app_theme.dart';

class WordsPanel extends StatefulWidget {
  final AppState state;
  final Future<void> Function(int wordId) onPlayWordAudio;
  final Future<void> Function(String text) onPlayTextAudio;

  const WordsPanel({
    super.key,
    required this.state,
    required this.onPlayWordAudio,
    required this.onPlayTextAudio,
  });

  @override
  State<WordsPanel> createState() => _WordsPanelState();
}

class _WordsPanelState extends State<WordsPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Word> _words = [];
  List<GrammarPoint> _grammarPoints = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final wordsApi = widget.state.wordsApi;
    if (wordsApi != null) {
      try {
        final result = await wordsApi.list(language: widget.state.activeLangCode, limit: 50);
        _words = result.words;
      } catch (_) {}
      try {
        final result = await wordsApi.listGrammarPoints(language: widget.state.activeLangCode, limit: 50);
        _grammarPoints = result.points;
      } catch (_) {}
    }
    if (_words.isEmpty) {
      _words = widget.state.recentMistakes;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Library', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              _buildStatsBar(),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabCtrl,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textHint,
            indicatorColor: AppTheme.primary,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Words (${_words.length})'),
              Tab(text: 'Grammar (${_grammarPoints.length})'),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildWordsTab(),
                      _buildGrammarTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordsTab() {
    final query = _searchCtrl.text.toLowerCase();
    final filtered = query.isEmpty
        ? _words
        : _words.where((w) =>
            w.word.toLowerCase().contains(query) ||
            w.meaning.toLowerCase().contains(query) ||
            w.reading.toLowerCase().contains(query)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 48, color: AppTheme.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No words yet', style: TextStyle(color: AppTheme.textHint)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) => _WordRow(
        word: filtered[i],
        onPlayWord: () => widget.onPlayWordAudio(filtered[i].id),
        onPlayText: (text) => widget.onPlayTextAudio(text),
      ),
    );
  }

  Widget _buildGrammarTab() {
    final query = _searchCtrl.text.toLowerCase();
    final filtered = query.isEmpty
        ? _grammarPoints
        : _grammarPoints.where((g) =>
            g.title.toLowerCase().contains(query) ||
            g.explanation.toLowerCase().contains(query)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 48, color: AppTheme.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No grammar points yet', style: TextStyle(color: AppTheme.textHint)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) => _GrammarRow(grammar: filtered[i]),
    );
  }

  Widget _buildStatsBar() {
    final total = _words.length;
    final mastered = _words.where((w) => w.repetitions >= 3).length;
    return Row(
      children: [
        _MiniStat(label: 'Words', value: '$total'),
        const SizedBox(width: 16),
        _MiniStat(label: 'Grammar', value: '${_grammarPoints.length}'),
        const SizedBox(width: 16),
        _MiniStat(label: 'Mastered', value: '$mastered'),
      ],
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
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
      ],
    );
  }
}

class _WordRow extends StatelessWidget {
  final Word word;
  final VoidCallback onPlayWord;
  final ValueChanged<String> onPlayText;

  const _WordRow({
    required this.word,
    required this.onPlayWord,
    required this.onPlayText,
  });

  @override
  Widget build(BuildContext context) {
    final detail = word.detail ?? {};
    final chips = <Widget>[];
    if (word.pos.isNotEmpty) {
      chips.add(_Tag(word.pos, AppTheme.primary));
    }
    if (word.level.isNotEmpty) {
      chips.add(_Tag(word.level, Colors.teal));
    }
    final collocation = (detail['collocation'] ?? '').toString();
    if (collocation.isNotEmpty) {
      chips.add(_Tag(collocation, Colors.orange));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WordDetailPage(
              word: word,
              onPlayWord: () async => onPlayWord(),
              onPlayText: (text) async => onPlayText(text),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(word.language.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.word, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    if (word.reading.isNotEmpty)
                      Text(word.reading, style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(word.meaning, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text('${word.totalCorrect}/${word.totalAttempts}',
                      style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                ],
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: chips),
          ],
        ],
      ),
      ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _GrammarRow extends StatelessWidget {
  final GrammarPoint grammar;
  const _GrammarRow({required this.grammar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Expanded(child: Text(grammar.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
              Text(grammar.language.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textHint)),
            ],
          ),
          const SizedBox(height: 6),
          Text(grammar.explanation, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (grammar.example.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.isDark ? Colors.white10 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(grammar.example, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textPrimary)),
            ),
          ],
        ],
      ),
    );
  }
}
