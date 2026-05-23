import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';

class GrammarDetailPage extends StatelessWidget {
  final GrammarPoint grammar;
  final Future<void> Function(String text) onPlayText;

  const GrammarDetailPage({
    super.key,
    required this.grammar,
    required this.onPlayText,
  });

  @override
  Widget build(BuildContext context) {
    final detail = _parseDetail(grammar.detail);
    final pattern = detail['pattern']?.toString() ?? '';
    final usage = detail['usage_notes']?.toString() ?? '';
    final formality = detail['formality_level']?.toString() ?? '';
    final mistakes = detail['common_mistakes']?.toString() ?? '';
    final related = detail['related_points']?.toString() ?? '';
    final conjugation = detail['conjugation_table']?.toString() ?? '';
    final position = detail['sentence_position']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(grammar.title, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        actions: [
          if (grammar.example.isNotEmpty)
            IconButton(
              icon: Icon(Icons.volume_up_outlined, color: AppTheme.primary),
              onPressed: () => onPlayText(grammar.example),
              tooltip: 'Play example',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(grammar.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 20),

            // Explanation
            if (grammar.explanation.isNotEmpty) ...[
              _Section(title: '解释', child: Text(grammar.explanation, style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.6))),
            ],

            // Example with TTS
            if (grammar.example.isNotEmpty) ...[
              _Section(title: '例句', child: _ExampleBlock(text: grammar.example, onPlay: () => onPlayText(grammar.example))),
            ],

            // Pattern
            if (pattern.isNotEmpty) ...[
              _Section(title: '句型公式', child: _CodeBlock(pattern)),
            ],

            // Usage notes
            if (usage.isNotEmpty) ...[
              _Section(title: '使用要点', child: Text(usage, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5))),
            ],

            // DLC fields
            if (formality.isNotEmpty) _FieldRow('语体层级', formality),
            if (mistakes.isNotEmpty) _FieldRow('常见错误', mistakes),
            if (related.isNotEmpty) _FieldRow('关联语法', related),
            if (conjugation.isNotEmpty) _FieldRow('活用表', conjugation),
            if (position.isNotEmpty) _FieldRow('句中位置', position),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _parseDetail(String? d) {
    if (d == null || d.isEmpty || d == '{}') return {};
    try { return jsonDecode(d) as Map<String, dynamic>; } catch (_) { return {}; }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ExampleBlock extends StatelessWidget {
  final String text;
  final VoidCallback onPlay;
  const _ExampleBlock({required this.text, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: AppTheme.textPrimary, height: 1.5))),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.volume_up_outlined, size: 20, color: AppTheme.primary),
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;
  const _CodeBlock(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      child: Text(text, style: TextStyle(fontSize: 15, fontFamily: 'monospace', color: AppTheme.textPrimary)),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  const _FieldRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textHint))),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5))),
        ],
      ),
    );
  }
}
