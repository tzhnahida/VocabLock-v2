import 'dart:io';

class AppAudioPlayer {
  Process? _current;

  Future<void> playUrl(String url) async {
    await stop();
    // Play audio inline via PowerShell MediaPlayer — no popup windows
    if (Platform.isWindows) {
      _current = await Process.start('powershell', [
        '-NoProfile', '-WindowStyle', 'Hidden', '-Command',
        'Add-Type -AssemblyName PresentationCore; ' +
        '\$p = New-Object System.Windows.Media.MediaPlayer; ' +
        '\$p.Open([uri]"$url"); ' +
        '\$p.Play(); ' +
        'while(\$p.Position.Ticks -eq 0) { Start-Sleep -Milliseconds 100 }; ' +
        '\$total = \$p.NaturalDuration.TimeSpan.TotalSeconds; ' +
        'while(\$p.Position.TotalSeconds -lt \$total - 0.1) { Start-Sleep -Milliseconds 200 }; ' +
        '\$p.Close()',
      ]);
    } else if (Platform.isMacOS) {
      _current = await Process.start('afplay', [url]);
    } else {
      _current = await Process.start('aplay', [url]);
    }
  }

  Future<void> playFile(String path) async {
    await stop();
    if (Platform.isWindows) {
      _current = await Process.start('powershell', [
        '-NoProfile', '-WindowStyle', 'Hidden', '-Command',
        'Add-Type -AssemblyName PresentationCore; ' +
        '\$p = New-Object System.Windows.Media.MediaPlayer; ' +
        '\$p.Open([uri]"file:///$path"); ' +
        '\$p.Play(); ' +
        'while(\$p.Position.Ticks -eq 0) { Start-Sleep -Milliseconds 100 }; ' +
        '\$total = \$p.NaturalDuration.TimeSpan.TotalSeconds; ' +
        'while(\$p.Position.TotalSeconds -lt \$total - 0.1) { Start-Sleep -Milliseconds 200 }; ' +
        '\$p.Close()',
      ]);
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
