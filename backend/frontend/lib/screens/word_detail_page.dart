import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/word.dart';
import '../theme/app_theme.dart';
import '../widgets/word_detail_card.dart';

class WordDetailPage extends StatefulWidget {
  final Word word;
  final List<WordFieldConfig>? fieldConfig;
  final Future<void> Function() onPlayWord;
  final Future<void> Function(String text) onPlayText;

  const WordDetailPage({
    super.key,
    required this.word,
    this.fieldConfig,
    required this.onPlayWord,
    required this.onPlayText,
  });

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPlayWord();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.word.word, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        actions: [
          if (widget.word.reading.isNotEmpty)
            IconButton(
              icon: Icon(Icons.volume_up_outlined, color: AppTheme.primary),
              onPressed: () => widget.onPlayWord(),
              tooltip: l10n.tooltipPlayAudio,
            ),
          if (widget.word.status == 'pending_review')
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l10n.statusPendingReview, style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
            ),
          if (widget.word.confidence == 'low')
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l10n.statusAIFilled, style: TextStyle(fontSize: 11, color: Colors.amber.shade800)),
            ),
        ],
      ),
      body: WordDetailCard(
        word: widget.word,
        fieldConfig: widget.fieldConfig,
        onPlayWord: widget.onPlayWord,
        onPlayText: widget.onPlayText,
      ),
    );
  }
}
