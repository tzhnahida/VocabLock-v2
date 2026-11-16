import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/diagnostics.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

/// Diagnostics panel: what the learner keeps getting wrong and why.
///
/// Data comes from GET /api/v1/stats/diagnostics (backend/internal/db/
/// diagnostics.go). The backend produces the numbers; this panel never
/// recomputes a rate the server already decided, so both views agree.
class DiagnosticsPanel extends StatefulWidget {
  final AppState state;
  const DiagnosticsPanel({super.key, required this.state});

  @override
  State<DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<DiagnosticsPanel> {
  static const _windows = <int>[7, 30, 90];

  int _days = 30;
  Diagnostics? _diag;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = widget.state.statsApi;
    if (api == null) {
      // No backend connection (mock mode) — show the honest empty state rather
      // than a spinner that never resolves.
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final d = await api.getDiagnostics(
        days: _days,
        language: widget.state.activeLangCode,
      );
      if (!mounted) return;
      setState(() {
        _diag = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectWindow(int days) {
    if (_days == days) return;
    setState(() => _days = days);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.diagnosticsTitle,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              for (final d in _windows)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _WindowChip(
                    label: l10n.diagnosticsWindowShort(d),
                    selected: d == _days,
                    onTap: () => _selectWindow(d),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l10n.diagnosticsWindow(_days),
              style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          const SizedBox(height: 20),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.redAccent.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(l10n.loadFailed(_error!),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final diag = _diag;
    if (diag == null || diag.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 44, color: AppTheme.primary.withValues(alpha: 0.25)),
            const SizedBox(height: 14),
            Text(l10n.diagnosticsEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Text(l10n.diagnosticsEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            title: l10n.diagnosticsCoverage,
            child: Row(
              children: [
                _Metric(label: l10n.diagnosticsWords, value: '${diag.coverage.totalWords}'),
                const SizedBox(width: 28),
                _Metric(
                  label: l10n.diagnosticsLongTerm,
                  value: '${diag.coverage.longTermWords}',
                  hint: '${(diag.coverage.longTermShare * 100).round()}%',
                ),
                const SizedBox(width: 28),
                _Metric(label: l10n.diagnosticsPending, value: '${diag.coverage.pendingReview}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: l10n.diagnosticsErrors,
            child: diag.wrongAnswers == 0
                ? _muted(l10n.diagnosticsNoErrors)
                : Column(
                    children: [
                      for (final e in diag.categoriesDesc)
                        _RateRow(
                          label: _categoryLabel(l10n, e.key),
                          value: e.value / diag.wrongAnswers,
                          trailing: '${e.value}',
                          color: Colors.redAccent,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: l10n.diagnosticsWeakPhonemes,
            child: diag.phonemeSamples == 0 || diag.phonemesDesc.isEmpty
                ? _muted(l10n.diagnosticsNoPhonemes)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in diag.phonemesDesc.take(16))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${p.key} × ${p.value}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(l10n.diagnosticsPhonemesMeasured(diag.phonemeSamples),
                          style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: l10n.diagnosticsAIDisagreement,
            child: diag.aiDisagreement == null
                ? _muted(l10n.diagnosticsNoAIVerdicts)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Metric(
                            label: l10n.diagnosticsAIVerdicts,
                            value: '${diag.aiDisagreement!.aiVerdicts}',
                          ),
                          const SizedBox(width: 28),
                          _Metric(
                            label: l10n.diagnosticsAIFalseNegatives,
                            value: '${(diag.aiDisagreement!.falseNegativeRate * 100).toStringAsFixed(1)}%',
                            hint: '${diag.aiDisagreement!.wrongButExactHit}/${diag.aiDisagreement!.aiVerdicts}',
                          ),
                        ],
                      ),
                      if (diag.aiDisagreement!.samples.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(l10n.diagnosticsAISamples,
                            style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        const SizedBox(height: 6),
                        for (final s in diag.aiDisagreement!.samples)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(s,
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: l10n.diagnosticsTypeAccuracy,
            child: diag.typeRates.isEmpty
                ? _muted(l10n.diagnosticsNoTypes)
                : Column(
                    children: [
                      for (final t in diag.typesByAccuracy)
                        _RateRow(
                          label: _typeLabel(t.key),
                          value: t.value.accuracy,
                          trailing: '${(t.value.accuracy * 100).round()}% · ${t.value.total}',
                          color: t.value.accuracy >= 0.8
                              ? Colors.green
                              : t.value.accuracy >= 0.6
                                  ? Colors.orange
                                  : Colors.redAccent,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _muted(String text) => Text(text,
      style: TextStyle(fontSize: 12, color: AppTheme.textHint));

  /// Error categories come from engine.classifyError / the AI judge.
  String _categoryLabel(AppLocalizations l10n, String c) {
    switch (c) {
      case 'similarity':
        return l10n.errorCategorySimilarity;
      case 'empty':
        return l10n.errorCategoryEmpty;
      case 'other':
        return l10n.errorCategoryOther;
      case '':
        return l10n.errorCategoryUnlabeled;
      default:
        return c;
    }
  }

  /// Question types are API identifiers; show them readable without inventing
  /// translations the API does not have.
  String _typeLabel(String type) => type.replaceAll('_', ' ');
}

class _WindowChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WindowChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primary : AppTheme.textHint,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;

  const _Metric({required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            if (hint != null) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(hint!, style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final double value;
  final String trailing;
  final Color color;

  const _RateRow({
    required this.label,
    required this.value,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
              Text(trailing, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 6,
                  width: constraints.maxWidth * value.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
