import 'package:flutter/material.dart';
import '../models/language.dart';
import '../models/stats.dart';
import '../models/question.dart';
import '../models/word.dart';
import '../mock/mock_data.dart';
import '../theme/app_theme.dart';

class AppState extends ChangeNotifier {
  bool _useMock = true;
  bool get useMock => _useMock;

  List<LanguageInfo> _languages = [];
  List<LanguageInfo> get languages => _languages;

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

  void init() {
    _loadLanguages();
  }

  void _loadLanguages() {
    if (_useMock) {
      _languages = MockData.languages;
    }
    if (_languages.isNotEmpty) {
      _activeLanguageIndex = 0;
      AppTheme.setActiveIndex(0);
    }
    _loadDashboard();
  }

  void _loadDashboard() {
    if (_useMock) {
      _progress = MockData.progress(activeLangCode);
      _todayStats = MockData.todayStats(activeLangCode);
      _bubbleStats = MockData.bubbles(activeLangCode);
      _heatmap = MockData.heatmap();
      _recentMistakes = MockData.words(activeLangCode).take(4).toList();
    }
  }

  Future<void> switchLanguage(int index) async {
    if (index < 0 || index >= _languages.length) return;
    _activeLanguageIndex = index;
    AppTheme.setActiveIndex(index);
    _loadDashboard();
    notifyListeners();
  }

  Future<Question?> getNextQuestion() {
    if (_useMock) {
      return Future.value(MockData.nextQuestion(activeLangCode));
    }
    // TODO: API call
    return Future.value(null);
  }

  void refresh() {
    _loadDashboard();
    notifyListeners();
  }
}
