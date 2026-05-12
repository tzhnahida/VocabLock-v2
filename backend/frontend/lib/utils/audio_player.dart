import 'dart:io';

class AudioPlayer {
  Process? _current;

  Future<void> playUrl(String url) async {
    await stop();
    if (Platform.isWindows) {
      _current = await Process.start('cmd', ['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      _current = await Process.start('afplay', [url]);
    } else {
      _current = await Process.start('xdg-open', [url]);
    }
  }

  Future<void> playFile(String path) async {
    await stop();
    if (Platform.isWindows) {
      _current = await Process.start('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isMacOS) {
      _current = await Process.start('afplay', [path]);
    } else {
      _current = await Process.start('aplay', [path]);
    }
  }

  Future<void> stop() async {
    _current?.kill();
    _current = null;
  }

  void dispose() {
    _current?.kill();
  }
}
