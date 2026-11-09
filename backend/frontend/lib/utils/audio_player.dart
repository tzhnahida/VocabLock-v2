import 'dart:io';

class AppAudioPlayer {
  Process? _current;

  Future<void> playUrl(String url) async {
    await stop();
    if (Platform.isWindows) {
      _current = await Process.start('powershell', [
        '-NoProfile', '-WindowStyle', 'Hidden', '-Command',
        'Add-Type -AssemblyName PresentationCore; ' +
        '\$p = New-Object System.Windows.Media.MediaPlayer; ' +
        '\$p.Open([uri]"$url"); ' +
        '\$p.Play(); ' +
        'while(\$p.Position.Ticks -eq 0) { Start-Sleep -Milliseconds 200 }; ' +
        'Start-Sleep -Milliseconds 500; ' +
        '\$timeout = [DateTime]::Now.AddSeconds(30); ' +
        'while([DateTime]::Now -lt \$timeout) { ' +
        '  \$d = \$p.NaturalDuration.TimeSpan.TotalSeconds; ' +
        '  if (\$d -gt 0 -and \$p.Position.TotalSeconds -ge \$d - 0.3) { break }; ' +
        '  Start-Sleep -Milliseconds 300 ' +
        '}; ' +
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
        'while(\$p.Position.Ticks -eq 0) { Start-Sleep -Milliseconds 200 }; ' +
        'Start-Sleep -Milliseconds 500; ' +
        '\$timeout = [DateTime]::Now.AddSeconds(30); ' +
        'while([DateTime]::Now -lt \$timeout) { ' +
        '  \$d = \$p.NaturalDuration.TimeSpan.TotalSeconds; ' +
        '  if (\$d -gt 0 -and \$p.Position.TotalSeconds -ge \$d - 0.3) { break }; ' +
        '  Start-Sleep -Milliseconds 300 ' +
        '}; ' +
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
