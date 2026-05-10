import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

class VocabLockApp extends StatelessWidget {
  const VocabLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'VocabLock',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
