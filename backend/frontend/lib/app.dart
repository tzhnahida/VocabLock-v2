import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/app_log.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'l10n/generated/app_localizations.dart';

class VocabLockApp extends StatelessWidget {
  final String? apiPort;
  final String? authToken;

  const VocabLockApp({super.key, this.apiPort, this.authToken});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(apiPort: apiPort, authToken: authToken)..init(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          AppLog.debug('[app] Consumer building MaterialApp with locale=${state.locale} uiLang=${state.uiLang}');
          return MaterialApp(
            title: 'VocabLock',
            debugShowCheckedModeBanner: false,
            locale: state.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            themeMode: state.themeMode,
            theme: AppTheme.themeData,
            darkTheme: AppTheme.themeData,
            home: _buildHome(state),
          );
        },
      ),
    );
  }

  Widget _buildHome(AppState state) {
    if (!state.initialized) {
      return Scaffold(
        backgroundColor: AppTheme.bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (state.isFirstRun) {
      return OnboardingScreen(
        aiConfigured: state.aiConfigured,
        onGetLangConfig: state.configApi != null
            ? (code) async {
                final r = await state.configApi!.getLanguageConfig(code);
                return r;
              }
            : null,
        onAiChat: state.aiApi != null
            ? (msg, history) async {
                final r = await state.aiApi!.chat(msg, history: history
                    .map((m) => {'role': m.role, 'content': m.content})
                    .toList());
                return r['reply'] as String? ?? '(no response)';
              }
            : null,
        onComplete: ({
        required String uiLang,
        required ThemeMode themeMode,
        required String learnLang,
        required int dailyTarget,
        required int dailyTimeTarget,
        String? apiKey,
        String? model,
        String? baseUrl,
        String? profileText,
        String? direction,
        String? password,
      }) =>
          state.completeOnboarding(
            uiLang: uiLang,
            themeMode: themeMode,
            learnLang: learnLang,
            dailyTarget: dailyTarget,
            dailyTimeTarget: dailyTimeTarget,
            apiKey: apiKey,
            model: model,
            baseUrl: baseUrl,
            profileText: profileText,
            direction: direction,
            password: password,
          ));
    }
    return const HomeScreen();
  }
}
