import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/word.dart';
import '../theme/app_theme.dart';

/// Structured detail view for a vocabulary word, showing all known fields.
/// Layout mirrors the quiz learning phase's study card.
class WordDetailCard extends StatelessWidget {
  final Word word;
  final List<WordFieldConfig>? fieldConfig;
  final Future<void> Function() onPlayWord;
  final Future<void> Function(String text) onPlayText;

  const WordDetailCard({
    super.key,
    required this.word,
    this.fieldConfig,
    required this.onPlayWord,
    required this.onPlayText,
  });

  static const _badgeKeys = {'meaning', 'pos', 'level', 'syllable_count', 'register', 'pitch_accent'};
  static const _exampleKeys = {'example_sentence'};
  static const _playableFields = {'word', 'morphology', 'collocation', 'example_sentence'};

  static const _fallbackFieldOrder = [
    'pos', 'level', 'syllable_count',
    'morphology', 'syntax', 'collocation', 'register',
    'etymology', 'example_sentence',
    'pitch_accent', 'conjugation_class', 'case_government',
    'orthographic_variants', 'keigo_level',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final w = word;
    final detail = Map<String, dynamic>.from(w.detail ?? {});
    // Top-level fields merge into detail
    if (w.meaning.isNotEmpty) detail['meaning'] = w.meaning;
    if (w.pos.isNotEmpty) detail['pos'] = w.pos;
    if (w.level.isNotEmpty) detail['level'] = w.level;

    final List<String> fieldOrder;
    final Map<String, String> labels;
    if (fieldConfig != null && fieldConfig!.isNotEmpty) {
      fieldOrder = [];
      labels = {};
      for (final fc in fieldConfig!) {
        if (fc.key.isNotEmpty) {
          fieldOrder.add(fc.key);
          labels[fc.key] = fc.label;
        }
      }
    } else {
      fieldOrder = _fallbackFieldOrder;
      labels = {
        'pos': l10n.fieldPos, 'level': l10n.fieldLevel, 'syllable_count': l10n.fieldSyllableCount,
        'morphology': l10n.fieldMorphology, 'syntax': l10n.fieldSyntax, 'collocation': l10n.fieldCollocation,
        'register': l10n.fieldRegister, 'etymology': l10n.fieldEtymology, 'example_sentence': l10n.fieldExampleSentence,
        'pitch_accent': l10n.fieldPitchAccent, 'conjugation_class': l10n.fieldConjugationClass,
        'case_government': l10n.fieldCaseGovernment, 'orthographic_variants': l10n.fieldOrthographicVariants,
        'keigo_level': l10n.fieldKeigoLevel,
      };
    }

    final badges = <Widget>[];
    final gridFields = <Widget>[];
    Widget? exampleCard;
    final fullFields = <Widget>[];

    for (final key in fieldOrder) {
      if (key == 'meaning') continue; // shown as hero badge below
      final val = (detail[key] ?? '').toString();
      if (val.isEmpty) continue;
      if (_badgeKeys.contains(key)) {
        badges.add(_Badge(labels[key]?.isNotEmpty == true ? '${labels[key]}: $val' : val, AppTheme.primary));
      } else if (_exampleKeys.contains(key)) {
        final play = _playableFields.contains(key);
        exampleCard = _ExampleBlock(text: val, onPlay: play ? () => onPlayText(val) : null);
      } else if (_playableFields.contains(key)) {
        gridFields.add(_GridCell(label: labels[key] ?? key, value: val, onPlay: () => onPlayText(val)));
      } else {
        if (val.length < 30) {
          gridFields.add(_GridCell(label: labels[key] ?? key, value: val));
        } else {
          fullFields.add(_CompactRow(label: labels[key] ?? key, value: val));
        }
      }
    }

    if (gridFields.length.isOdd) gridFields.add(const SizedBox(width: 1));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Hero: word + reading
          Text(w.word, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          if (w.reading.isNotEmpty)
            Text(w.reading, style: TextStyle(fontSize: 20, color: AppTheme.accent)),
          const SizedBox(height: 10),
          _PlayButton(onTap: onPlayWord),
          const SizedBox(height: 20),
          // Meaning badge (prominent)
          if (detail['meaning']?.toString().isNotEmpty == true) ...[
            Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
              _Badge(detail['meaning'].toString(), AppTheme.accent),
              ...badges,
            ]),
            const SizedBox(height: 20),
          ] else if (badges.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: badges),
            const SizedBox(height: 20),
          ],
          // Example sentence
          if (exampleCard != null) ...[exampleCard, const SizedBox(height: 16)],
          // 2-column grid
          if (gridFields.isNotEmpty) ..._buildGrid(gridFields),
          // Full-width fields
          if (fullFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...fullFields,
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildGrid(List<Widget> cells) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            const SizedBox(width: 10),
            if (i + 1 < cells.length) Expanded(child: cells[i + 1]) else const Spacer(),
          ],
        ),
      ));
    }
    return rows;
  }
}

// ── Sub-widgets ──

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ExampleBlock extends StatelessWidget {
  final String text;
  final VoidCallback? onPlay;
  const _ExampleBlock({required this.text, this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.format_quote, size: 18, color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary, height: 1.5)),
          ),
          if (onPlay != null) ...[const SizedBox(width: 8), _PlayButton(onTap: onPlay!)],
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onPlay;
  const _GridCell({required this.label, required this.value, this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textHint))),
              if (onPlay != null) _PlayButton(onTap: onPlay!),
            ],
          ),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  final String label;
  final String value;
  const _CompactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint))),
            const SizedBox(width: 8),
            Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _playing = false;

  Future<void> _tap() async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      widget.onTap();
      if (mounted) await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _tap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          _playing ? Icons.volume_up : Icons.volume_up_outlined,
          size: 18,
          color: _playing ? AppTheme.accent : AppTheme.primary,
        ),
      ),
    );
  }
}
