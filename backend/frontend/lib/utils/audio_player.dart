import 'package:audioplayers/audioplayers.dart' as ap;

class AudioPlayer {
  final ap.AudioPlayer _player = ap.AudioPlayer();

  Future<void> playUrl(String url) async {
    await _player.stop();
    await _player.play(ap.UrlSource(url));
  }

  Future<void> playFile(String path) async {
    await _player.stop();
    await _player.play(ap.DeviceFileSource(path));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
