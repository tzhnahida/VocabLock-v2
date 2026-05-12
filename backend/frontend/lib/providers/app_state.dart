import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/ai_api.dart';
import '../api/quiz_api.dart';
import '../api/words_api.dart';
import '../api/stats_api.dart';
import '../api/config_api.dart';
import '../api/tts_api.dart';
import '../models/language.dart';
import '../models/stats.dart';
import '../models/question.dart';
import '../models/word.dart';
import '../mock/mock_data.dart';
import '../models/quiz_result.dart';
import '../theme/app_theme.dart';

class AppState extends ChangeNotifier {
  final ApiClient? _apiClient;
  late final QuizApi? _quizApi;
  late final WordsApi? _wordsApi;
  late final StatsApi? _statsApi;
  late final ConfigApi? _configApi;
  late final TtsApi? _ttsApi;
  late final AiApi? _aiApi;

  QuizApi? get quizApi => _quizApi;
  WordsApi? get wordsApi => _wordsApi;
  StatsApi? get statsApi => _statsApi;
  ConfigApi? get configApi => _configApi;
  TtsApi? get ttsApi => _ttsApi;
  AiApi? get aiApi => _aiApi;

  AppState({String? apiPort, String? authToken})
      : _apiClient = (apiPort != null && authToken != null)
            ? ApiClient(
                baseUrl: 'http://127.0.0.1:$apiPort',
                token: authToken,
              )
            : null {
    final api = _apiClient;
    if (api != null) {
      _quizApi = QuizApi(api);
      _wordsApi = WordsApi(api);
      _statsApi = StatsApi(api);
      _configApi = ConfigApi(api);
      _ttsApi = TtsApi(api);
      _aiApi = AiApi(api);
    } else {
      _quizApi = null;
      _wordsApi = null;
      _statsApi = null;
      _configApi = null;
      _ttsApi = null;
      _aiApi = null;
    }
  }

  String? get baseUrl => _apiClient?.baseUrl;
  bool get useMock => _apiClient == null;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _isFirstRun = false;
  bool get isFirstRun => _isFirstRun;
  bool _hasPlan = false;

  bool _dailyCompleted = false;
  bool get dailyCompleted => _dailyCompleted;

  bool _expanding = false;
  bool get expanding => _expanding;
  String _expandStatus = '';
  String get expandStatus => _expandStatus;
  int _expandTotal = 0;
  int get expandTotal => _expandTotal;
  int _expandVerified = 0;
  int get expandVerified => _expandVerified;
  int _expandPending = 0;
  int get expandPending => _expandPending;

  String _uiLang = 'en';
  String get uiLang => _uiLang;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  List<LanguageInfo> _languages = [];
  List<LanguageInfo> get languages => _languages;

  List<String> get langCodes => _languages.map((l) => l.code).toList();

  int _activeLanguageIndex = 0;
  int get activeLanguageIndex => _activeLanguageIndex;

  LanguageInfo? get activeLanguage =>
      _languages.isNotEmpty ? _languages[_activeLanguageIndex] : null;

  String get activeLangCode => activeLanguage?.code ?? 'en';

  QuizProgress? _progress;
  QuizProgress? get progress => _progress;

  TodayStats? _todayStats;
  TodayStats? get todayStats => _todayStats;

  Map<String, double> _bubbleStats = {};
  Map<String, double> get bubbleStats => _bubbleStats;

  List<Word> _recentMistakes = [];
  List<Word> get recentMistakes => _recentMistakes;

  Map<String, int> _heatmap = {};
  Map<String, int> get heatmap => _heatmap;

  Future<void> init() async {
    if (useMock) {
      _loadMockData();
    } else {
      await _loadApiData();
    }
    // First run only if no languages AND no saved plan
    _isFirstRun = _languages.isEmpty && !_hasPlan;
    _initialized = true;
    notifyListeners();
  }

  String? _apiKey;
  String? _model;
  String? _baseUrl;
  String? get apiKey => _apiKey;

  bool _aiConfigured = false;
  bool get aiConfigured => _aiConfigured;

  Future<void> completeOnboarding({
    required String uiLang,
    required ThemeMode themeMode,
    required String learnLang,
    required int dailyTarget,
    String? apiKey,
    String? model,
    String? baseUrl,
    String? profileText,
    String? direction,
  }) async {
    _uiLang = uiLang;
    _themeMode = themeMode;
    _apiKey = apiKey;
    _model = model;
    _baseUrl = baseUrl;
    AppTheme.setThemeMode(themeMode);

    // Build language list starting with selected learning language
    final displayNames = {'en': 'English', 'ja': 'Japanese', 'zh': 'Chinese', 'ko': 'Korean'};
    final nativeNames = {'en': 'English', 'ja': '日本語', 'zh': '中文', 'ko': '한국어'};
    _languages = [LanguageInfo(
      code: learnLang,
      displayName: displayNames[learnLang] ?? learnLang,
      nativeName: nativeNames[learnLang] ?? learnLang,
      index: 0,
    )];
    _activeLanguageIndex = 0;
    AppTheme.setActiveIndex(0);
    _isFirstRun = false;

    // Update backend config and load real data
    if (!useMock && _configApi != null) {
      try {
        await _configApi!.updateConfig(activeLang: learnLang, dailyTarget: dailyTarget);
      } catch (_) {}
      // Save AI profile if generated during interview
      if (profileText != null && profileText.isNotEmpty && _aiApi != null) {
        try {
          await _aiApi!.updateProfile({
            'language': learnLang,
            'level': 'beginner',
            'direction': direction ?? 'general',
            'profile': profileText,
          });
        } catch (_) {}
      }
      if (direction != null && direction.isNotEmpty && _quizApi != null) {
        try {
          await _quizApi!.updateDirection(direction);
        } catch (_) {}
      }
      await _loadApiDashboard();
    } else {
      _mockInitialized = true;
      _loadMockDashboard();
    }
    notifyListeners();

    // Auto-expand words after onboarding (real mode only, with AI)
    if (!useMock) {
      await expandWords(count: 10);
    }
  }

  Future<void> expandWords({int count = 10}) async {
    if (_expanding) return;
    _expanding = true;
    _expandStatus = 'AI 正在生成词汇...';
    notifyListeners();
    final wordsApi = _wordsApi;
    if (wordsApi != null) {
      try {
        final result = await wordsApi.expand(count: count);
        final verified = (result['verified'] as List<dynamic>?) ?? [];
        final pending = (result['pending_review'] as List<dynamic>?) ?? [];
        _expandVerified = verified.length;
        _expandPending = pending.length;
        _expandTotal = _expandVerified + _expandPending;
        if (_expandTotal > 0) {
          _expandStatus = '生成 $_expandTotal 个词汇（$_expandVerified 已入库，$_expandPending 待审核）';
        } else {
          _expandStatus = result['message']?.toString() ?? '未生成新词汇';
        }
        notifyListeners();
        await _loadApiDashboard();
      } catch (e) {
        _expandStatus = '词汇生成失败: $e';
        notifyListeners();
      }
    } else {
      _expandStatus = 'API 未连接，无法生成词汇';
      notifyListeners();
    }
    _expanding = false;
    notifyListeners();
  }

  Future<void> completeDaily() async {
    _dailyCompleted = true;
    if (!useMock && _quizApi != null) {
      try {
        await _quizApi!.complete();
      } catch (_) {}
    }
    notifyListeners();
  }

  static bool _mockInitialized = false;

  void _loadMockData() {
    if (!_mockInitialized) {
      // First run: no languages yet, onboarding will set them up
      // Simulate AI pre-configured for testing
      _aiConfigured = true;
      _languages = [];
      _initialized = true;
      notifyListeners();
      return;
    }
    _languages = MockData.languages;
    if (_languages.isNotEmpty) {
      _activeLanguageIndex = 0;
      AppTheme.setActiveIndex(0);
    }
    _loadMockDashboard();
  }

  static void markMockInitialized() {
    _mockInitialized = true;
  }

  void _loadMockDashboard() {
    _progress = MockData.progress(activeLangCode);
    _todayStats = MockData.todayStats(activeLangCode);
    _bubbleStats = MockData.bubbles(activeLangCode);
    _heatmap = MockData.heatmap();
    _recentMistakes = MockData.words(activeLangCode).take(4).toList();
    _dailyCompleted = _progress != null && _progress!.remaining <= 0;
    notifyListeners();
  }

  Future<void> _loadApiData() async {
    final configApi = _configApi;
    if (configApi == null) return;
    try {
      final codes = await configApi.getLanguages();
      _languages = codes.asMap().entries.map((e) {
        final displayNames = {'en': 'English', 'ja': 'Japanese', 'zh': 'Chinese', 'ko': 'Korean'};
        final nativeNames = {'en': 'English', 'ja': '日本語', 'zh': '中文', 'ko': '한국어'};
        final code = e.value;
        return LanguageInfo(
          code: code,
          displayName: displayNames[code] ?? code,
          nativeName: nativeNames[code] ?? code,
          index: e.key,
        );
      }).toList();

      if (_languages.isNotEmpty) {
        _activeLanguageIndex = 0;
        AppTheme.setActiveIndex(0);
      }

      // Check if AI is already configured (e.g. via env var)
      if (_aiApi != null) {
        try {
          final profile = await _aiApi!.getProfile();
          _aiConfigured = profile['configured'] == true;
        } catch (_) {}
      }

      // Check if training plan exists (indicates onboarding was done)
      // Use active_lang from config if languages list is empty
      if (_quizApi != null) {
        final checkLang = _languages.isNotEmpty ? _languages[0].code : 'zh';
        try {
          final plan = await _quizApi!.getPlan(language: checkLang);
          _hasPlan = plan.id != null;
        } catch (_) {}
      }

      await _loadApiDashboard();
    } catch (_) {
      _languages = MockData.languages;
      if (_languages.isNotEmpty) {
        _activeLanguageIndex = 0;
        AppTheme.setActiveIndex(0);
      }
      _loadMockDashboard();
      return;
    }
    notifyListeners();
  }

  Future<void> _loadApiDashboard() async {
    final quizApi = _quizApi;
    final statsApi = _statsApi;
    final wordsApi = _wordsApi;
    if (quizApi == null || statsApi == null || wordsApi == null) return;
    final lang = activeLangCode;
    try {
      _progress = await quizApi.getProgress(language: lang);
      _todayStats = await quizApi.getTodayStats(language: lang);
      _heatmap = await statsApi.getHeatmap(language: lang);
      _recentMistakes = (await wordsApi.list(language: lang, limit: 20)).words;
      _bubbleStats = {};
    } catch (_) {
      _loadMockDashboard();
      return;
    }
    notifyListeners();
  }

  Future<void> switchLanguage(int index) async {
    if (index < 0 || index >= _languages.length) return;
    _activeLanguageIndex = index;
    AppTheme.setActiveIndex(index);

    if (useMock) {
      _loadMockDashboard();
    } else {
      final configApi = _configApi;
      if (configApi != null) {
        try {
          await configApi.updateConfig(activeLang: _languages[index].code);
          await _loadApiDashboard();
        } catch (_) {
          _loadMockDashboard();
        }
      }
    }
    notifyListeners();
  }

  Future<Question?> getNextQuestion() async {
    final lang = activeLangCode;
    if (useMock) {
      return MockData.nextQuestion(lang);
    }
    final quizApi = _quizApi;
    if (quizApi == null) return MockData.nextQuestion(lang);
    try {
      return await quizApi.getNext(language: lang);
    } catch (_) {
      return MockData.nextQuestion(lang);
    }
  }

  Future<SubmitResult?> submitAnswer({
    required String questionId,
    required int wordId,
    required String questionType,
    required String answer,
  }) async {
    final lang = activeLangCode;
    if (useMock) {
      return MockData.submitResult();
    }
    final quizApi = _quizApi;
    if (quizApi == null) return null;
    try {
      return await quizApi.submit(
        questionId: questionId,
        wordId: wordId,
        questionType: questionType,
        answer: answer,
        language: lang,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Word>> getStudyWords() async {
    if (useMock) {
      return MockData.words(activeLangCode);
    }
    final wordsApi = _wordsApi;
    if (wordsApi == null) return MockData.words(activeLangCode);
    try {
      final result = await wordsApi.list(language: activeLangCode, limit: 20);
      return result.words;
    } catch (_) {
      return MockData.words(activeLangCode);
    }
  }

  void refresh() {
    if (useMock) {
      _loadMockDashboard();
    } else {
      _loadApiDashboard();
    }
  }
}
