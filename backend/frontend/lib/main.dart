import 'package:flutter/material.dart';
import 'app.dart';

void main(List<String> args) {
  String? apiPort;
  String? authToken;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--api-port' && i + 1 < args.length) {
      apiPort = args[i + 1];
    }
    if (args[i] == '--auth-token' && i + 1 < args.length) {
      authToken = args[i + 1];
    }
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VocabLockApp());
}
