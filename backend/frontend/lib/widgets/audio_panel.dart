import 'package:flutter/material.dart';
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
  final _player = AudioPlayer();
  String _status = '';
  String? _playingWord;

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
    setState(() => _status = '生成中...');
    final ttsApi = widget.state.ttsApi;
    if (ttsApi != null) {
      try {
        final result = await ttsApi.getTextAudio(text);
        final url = _fullUrl(result['url'] as String?);
        if (url.isNotEmpty) {
          setState(() => _status = '播放中...');
          await _player.playUrl(url);
          setState(() => _status = '播放完毕');
        } else {
          setState(() => _status = result['status'] == 'not_configured' ? 'TTS 未配置（需要外部二进制）' : '生成失败');
        }
      } catch (_) {
        setState(() => _status = 'TTS 播放失败');
      }
    } else {
      setState(() => _status = 'TTS 不可用');
    }
  }

  Future<void> _speakWord(int id, String word) async {
    setState(() { _status = '生成中...'; _playingWord = word; });
    final ttsApi = widget.state.ttsApi;
    if (ttsApi != null) {
      try {
        final result = await ttsApi.getWordAudio(id);
        final url = _fullUrl(result['url'] as String?);
        if (url.isNotEmpty) {
          setState(() => _status = '播放: $word');
          await _player.playUrl(url);
          setState(() { _status = '已播放: $word'; _playingWord = null; });
        } else {
          setState(() { _status = 'TTS 未配置'; _playingWord = null; });
        }
      } catch (_) {
        setState(() { _status = '播放失败'; _playingWord = null; });
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
          Text('Audio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: InputDecoration(
                    hintText: '输入文本试听...',
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
                  if (_status.startsWith('生成') || _status.startsWith('播放中'))
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  Expanded(child: Text(_status, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                ],
              ),
            ),
          const SizedBox(height: 28),
          Text('快速播放', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Expanded(
            child: words.isEmpty
                ? Center(child: Text('暂无单词', style: TextStyle(color: AppTheme.textHint)))
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
