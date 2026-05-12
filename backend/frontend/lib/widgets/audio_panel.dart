import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class AudioPanel extends StatefulWidget {
  final AppState state;
  const AudioPanel({super.key, required this.state});

  @override
  State<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<AudioPanel> {
  final _textCtrl = TextEditingController();
  String _status = '';

  Future<void> _speak() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _status = 'Generating...');
    final ttsApi = widget.state.ttsApi;
    if (ttsApi != null) {
      try {
        final result = await ttsApi.getTextAudio(text);
        setState(() => _status = result['status'] ?? 'done');
      } catch (_) {
        setState(() => _status = 'Failed');
      }
    } else {
      setState(() => _status = 'TTS not configured');
    }
  }

  Future<void> _speakWord(int id, String word) async {
    setState(() => _status = 'Playing: $word');
    final ttsApi = widget.state.ttsApi;
    if (ttsApi != null) {
      try {
        await ttsApi.getWordAudio(id);
        setState(() => _status = 'Played: $word');
      } catch (_) {
        setState(() => _status = 'Failed');
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
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
          Text('Audio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: InputDecoration(
                    hintText: 'Enter text to speak...',
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
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
              child: Text(_status, style: TextStyle(color: AppTheme.textSecondary)),
            ),
          const SizedBox(height: 28),
          Text('Quick Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: words.map((w) => ListTile(
                leading: Icon(Icons.volume_up, color: AppTheme.primary),
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
