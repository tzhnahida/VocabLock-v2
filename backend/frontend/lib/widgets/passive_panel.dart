import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

/// Passive recall card: one due word, recall it, then rate how it felt.
///
/// The rating is the whole point — it is sent to POST /api/v1/system/
/// passive-submit, which applies the light SM-2 update (easy→4, hard→3,
/// forgot→1) and writes a review_log row with source="passive". Nothing is
/// recorded until a rating is chosen, so opening this panel cannot damage a
/// schedule by itself.
class PassivePanel extends StatefulWidget {
  final AppState state;
  const PassivePanel({super.key, required this.state});

  @override
  State<PassivePanel> createState() => _PassivePanelState();
}

class _PassivePanelState extends State<PassivePanel> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _submitError;

  int _wordId = 0;
  String _word = '';
  String _reading = '';
  String _meaning = '';
  bool _revealed = false;

  /// How many cards were rated in this visit (session-local, not persisted).
  int _answered = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _submitError = null;
    });
    final api = widget.state.systemApi;
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await api.getPassiveQ();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _revealed = false;
        _wordId = (data['word_id'] as num?)?.toInt() ?? 0;
        _word = (data['word'] ?? '').toString();
        _reading = (data['reading'] ?? '').toString();
        _meaning = (data['meaning'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _rate(String recall) async {
    if (_submitting || _wordId <= 0) return;
    final api = widget.state.systemApi;
    if (api == null) return;
    // Captured before the await: the widget may be gone by the time the
    // request settles, and the error text is still worth composing.
    final l10n = AppLocalizations.of(context);
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final ok = await api.passiveSubmit(wordId: _wordId, recall: recall);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (ok) _answered++;
      });
      if (ok) {
        await _load();
      } else {
        setState(() => _submitError = l10n.passiveSubmitRejected);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = l10n.loadFailed(e.toString());
      });
    }
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
                child: Text(l10n.passiveTitle,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              Text(l10n.passiveAnswered(_answered),
                  style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ],
          ),
          const SizedBox(height: 6),
          Text(l10n.passiveHint,
              style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          const SizedBox(height: 20),
          Expanded(child: Center(child: _buildBody(l10n))),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) return const CircularProgressIndicator();

    if (_error != null) {
      return Column(
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
      );
    }

    if (_word.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 44, color: AppTheme.primary.withValues(alpha: 0.25)),
          const SizedBox(height: 14),
          Text(l10n.passiveEmpty,
              style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text(l10n.passiveEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _load,
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
            child: Text(l10n.retry),
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_word,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            if (_reading.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_reading,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
            ],
            const SizedBox(height: 24),
            if (!_revealed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _revealed = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(l10n.passiveReveal,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              )
            else ...[
              if (_meaning.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_meaning,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: AppTheme.textPrimary, height: 1.5)),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _RateButton(label: l10n.passiveForgot, color: Colors.redAccent, onTap: _submitting ? null : () => _rate('forgot'))),
                  const SizedBox(width: 10),
                  Expanded(child: _RateButton(label: l10n.passiveHard, color: Colors.orange, onTap: _submitting ? null : () => _rate('hard'))),
                  const SizedBox(width: 10),
                  Expanded(child: _RateButton(label: l10n.passiveRemember, color: Colors.green, onTap: _submitting ? null : () => _rate('easy'))),
                ],
              ),
            ],
            if (_submitting) ...[
              const SizedBox(height: 16),
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
            if (_submitError != null) ...[
              const SizedBox(height: 14),
              Text(_submitError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.redAccent.withValues(alpha: 0.8))),
            ],
          ],
        ),
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _RateButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
