import 'package:flutter/material.dart';
import '../models/word.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class WordsPanel extends StatefulWidget {
  final AppState state;
  const WordsPanel({super.key, required this.state});

  @override
  State<WordsPanel> createState() => _WordsPanelState();
}

class _WordsPanelState extends State<WordsPanel> {
  List<Word> _words = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    }
    if (_words.isEmpty) {
      _words = widget.state.recentMistakes;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.toLowerCase();
    final filtered = query.isEmpty ? _words : _words.where((w) =>
        w.word.toLowerCase().contains(query) ||
        w.meaning.toLowerCase().contains(query) ||
        w.reading.toLowerCase().contains(query)).toList();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Words', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              _buildStatsBar(),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search words...',
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
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => _WordRow(word: filtered[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final total = _words.length;
    final mastered = _words.where((w) => w.repetitions >= 3).length;
    return Row(
      children: [
        _MiniStat(label: 'Total', value: '$total'),
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
  const _WordRow({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(word.language.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.word, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(word.meaning, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(word.reading, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
              const SizedBox(height: 4),
              Text('${word.totalCorrect}/${word.totalAttempts}', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}
