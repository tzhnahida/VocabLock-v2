import 'package:flutter/material.dart';
import 'app.dart';
import 'utils/app_log.dart';

void main(List<String> args) {
  // flutter run cannot forward CLI args to the app on desktop — support
  // --dart-define fallbacks for attached debugging (flutter run --dart-define=...).
  const envPort = String.fromEnvironment('API_PORT');
  const envToken = String.fromEnvironment('AUTH_TOKEN');
  String? apiPort = envPort.isNotEmpty ? envPort : null;
  String? authToken = envToken.isNotEmpty ? envToken : null;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--api-port' && i + 1 < args.length) {
      apiPort = args[i + 1];
    }
    if (args[i] == '--auth-token' && i + 1 < args.length) {
      authToken = args[i + 1];
    }
  }

  AppLog.init(apiPort ?? '0'); // init even if null so we can see the issue
  AppLog.debug('main: apiPort=$apiPort authToken=$authToken');

  WidgetsFlutterBinding.ensureInitialized();
  runApp(VocabLockApp(apiPort: apiPort, authToken: authToken));
}
