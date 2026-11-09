import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/audio_player.dart';

class AudioPanel extends StatefulWidget {
  final AppState state;
  const AudioPanel({super.key, required this.state});

  @override
  State<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<AudioPanel> {
  final _textCtrl = TextEditingController();
  final _player = AppAudioPlayer();
  String _status = '';
  String? _playingWord;
  bool _busy = false;

  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = widget.state.baseUrl ?? 'http://127.0.0.1:8080';
    final token = widget.state.token ?? '';
    final sep = path.contains('?') ? '&' : '?';
    return '$base$path${sep}token=$token';
  }

  Future<void> _speak() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() { _busy = true; _status = l10n.audioGenerating; });
    final ttsApi = widget.state.ttsApi;
    if (ttsApi != null) {
      try {
        final result = await ttsApi.getTextAudio(text);
        if (!mounted) return;
        final url = _fullUrl(result['url'] as String?);
        if (url.isNotEmpty) {
          setState(() => _status = l10n.audioPlaying);
          await _player.playUrl(url);
          if (!mounted) return;
          setState(() { _busy = false; _status = l10n.audioPlayed; });
        } else {
          setState(() { _busy = false; _status = result['status'] == 'not_configured' ? l10n.audioNotConfigured : l10n.audioGenerateFailed; });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() { _busy = false; _status = l10n.audioPlayFailed; });
      }
    } else {
      setState(() { _busy = false; _status = l10n.audioUnavailable; });
    }
  }

  Future<void> _speakWord(int id, String word) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() { _busy = true; _status = l10n.audioGenerating; _playingWord = word; });
    final ttsApi = widget.state.ttsApi;
    if (ttsApi != null) {
      try {
        final result = await ttsApi.getWordAudio(id);
        if (!mounted) return;
        final url = _fullUrl(result['url'] as String?);
        if (url.isNotEmpty) {
          setState(() => _status = l10n.audioPlayingWord(word));
          await _player.playUrl(url);
          if (!mounted) return;
          setState(() { _busy = false; _status = l10n.audioPlayedWord(word); _playingWord = null; });
        } else {
          setState(() { _busy = false; _status = l10n.audioNotConfigured; _playingWord = null; });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() { _busy = false; _status = l10n.audioPlayFailed; _playingWord = null; });
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.state.recentMistakes;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.sidebarAudio, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.audioPreviewHint,
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _speak(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _speak,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.volume_up, size: 22),
              ),
            ],
          ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  Expanded(child: Text(_status, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                ],
              ),
            ),
          const SizedBox(height: 28),
          Text(AppLocalizations.of(context)!.audioQuickPlay, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Expanded(
            child: words.isEmpty
                ? Center(child: Text(AppLocalizations.of(context)!.audioNoWords, style: TextStyle(color: AppTheme.textHint)))
                : ListView(
                    children: words.map((w) => ListTile(
                      leading: Icon(
                        _playingWord == w.word ? Icons.music_note : Icons.volume_up,
                        color: _playingWord == w.word ? AppTheme.primary : AppTheme.textHint,
                      ),
                      title: Text(w.word, style: TextStyle(color: AppTheme.textPrimary)),
                      subtitle: Text(w.meaning, style: TextStyle(color: AppTheme.textSecondary)),
                      trailing: Text(w.reading, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      onTap: () => _speakWord(w.id, w.word),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: AppTheme.cardBg,
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
