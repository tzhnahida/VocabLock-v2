import 'dart:math';
import '../models/word.dart';
import '../models/question.dart';
import '../models/quiz_result.dart';
import '../models/stats.dart';
import '../models/language.dart';

class MockData {
  MockData._();

  static final _rng = Random(42);

  static const List<String> _langCodes = ['zh', 'en', 'ja', 'ko'];

  static List<LanguageInfo> get languages => List.generate(
        _langCodes.length,
        (i) => LanguageInfo(
          code: _langCodes[i],
          displayName: _displayNames[_langCodes[i]] ?? _langCodes[i],
          nativeName: _nativeNames[_langCodes[i]] ?? _langCodes[i],
          index: i,
        ),
      );

  static const Map<String, String> _displayNames = {
    'en': 'English',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'ko': 'Korean',
  };

  static const Map<String, String> _nativeNames = {
    'en': 'English',
    'ja': '日本語',
    'zh': '中文',
    'ko': '한국어',
  };

  static const Map<String, List<String>> _questionTypes = {
    'en': ['choice', 'fill', 'reading', 'listening', 'reading_comp', 'grammar'],
    'ja': ['choice', 'fill', 'reading', 'listening', 'reading_comp', 'grammar'],
    'zh': ['choice', 'fill', 'reading', 'listening', 'reading_comp', 'grammar'],
    'ko': ['choice', 'fill', 'reading', 'listening', 'reading_comp', 'grammar'],
  };

  static List<String> questionTypesFor(String lang) =>
      _questionTypes[lang] ?? ['choice', 'fill', 'reading'];

  static final Map<String, List<Word>> _wordPools = {
    'en': [
      Word(id: 1, word: 'abandon', reading: '/əˈbændən/', meaning: 'to leave behind', pos: 'verb', language: 'en'),
      Word(id: 2, word: 'benefit', reading: '/ˈbɛnɪfɪt/', meaning: 'an advantage', pos: 'noun', language: 'en'),
      Word(id: 3, word: 'create', reading: '/kriˈeɪt/', meaning: 'to make something new', pos: 'verb', language: 'en'),
      Word(id: 4, word: 'decision', reading: '/dɪˈsɪʒən/', meaning: 'a choice made', pos: 'noun', language: 'en'),
      Word(id: 5, word: 'explain', reading: '/ɪkˈspleɪn/', meaning: 'to make clear', pos: 'verb', language: 'en'),
    ],
    'ja': [
      Word(id: 101, word: '食べる', reading: 'たべる', meaning: 'to eat', pos: 'verb', language: 'ja'),
      Word(id: 102, word: '歩く', reading: 'あるく', meaning: 'to walk', pos: 'verb', language: 'ja'),
      Word(id: 103, word: '美しい', reading: 'うつくしい', meaning: 'beautiful', pos: 'adj', language: 'ja'),
      Word(id: 104, word: '学校', reading: 'がっこう', meaning: 'school', pos: 'noun', language: 'ja'),
      Word(id: 105, word: '話す', reading: 'はなす', meaning: 'to speak', pos: 'verb', language: 'ja'),
    ],
    'zh': [
      Word(id: 201, word: '学习', reading: 'xuéxí', meaning: 'to study', pos: 'verb', language: 'zh'),
      Word(id: 202, word: '工作', reading: 'gōngzuò', meaning: 'to work', pos: 'verb', language: 'zh'),
      Word(id: 203, word: '美丽', reading: 'měilì', meaning: 'beautiful', pos: 'adj', language: 'zh'),
      Word(id: 204, word: '电脑', reading: 'diànnǎo', meaning: 'computer', pos: 'noun', language: 'zh'),
    ],
    'ko': [
      Word(id: 301, word: '공부하다', reading: 'gongbuhada', meaning: 'to study', pos: 'verb', language: 'ko'),
      Word(id: 302, word: '아름답다', reading: 'areumdapda', meaning: 'beautiful', pos: 'adj', language: 'ko'),
      Word(id: 303, word: '학교', reading: 'hakgyo', meaning: 'school', pos: 'noun', language: 'ko'),
    ],
  };

  static List<Word> words(String lang) => _wordPools[lang] ?? _wordPools['en']!;

  static QuizProgress progress(String lang) {
    final words = _wordPools[lang] ?? _wordPools['en']!;
    final reviewed = _rng.nextInt(words.length * 3) + 5;
    const target = 20;
    return QuizProgress(reviewedToday: reviewed.clamp(0, target), remaining: (target - reviewed).clamp(0, target), dailyTarget: target);
  }

  static TodayStats todayStats(String lang) {
    final reviewed = 8 + _rng.nextInt(8);
    final correct = reviewed - _rng.nextInt(3);
    return TodayStats(reviewed: reviewed, correct: correct, accuracy: correct / reviewed);
  }

  static Map<String, int> heatmap() {
    final map = <String, int>{};
    final now = DateTime.now();
    for (var i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      map[key] = _rng.nextInt(20) + 1;
    }
    return map;
  }

  static Question nextQuestion(String lang) {
    final words = _wordPools[lang] ?? _wordPools['en']!;
    final w = words[_rng.nextInt(words.length)];
    final types = _questionTypes[lang] ?? ['choice'];
    final qt = QuestionType.fromString(types[_rng.nextInt(types.length)]);
    return Question(
      id: 'w${qt.apiValue[0]}${w.id}',
      type: qt,
      subjectType: 'word',
      subjectId: w.id,
      prompt: _promptForType(qt, w),
      options: qt == QuestionType.choice || qt.isAI ? ['Option A', 'Option B', 'Option C', w.meaning] : null,
    );
  }

  static String _promptForType(QuestionType qt, Word w) {
    switch (qt) {
      case QuestionType.choice:
        return 'Select the correct meaning for: ${w.word}';
      case QuestionType.fill:
        return 'Fill in the blank: ${w.word[0]}___ (${w.meaning})';
      case QuestionType.spelling:
        return 'Spell the word for: ${w.meaning}';
      case QuestionType.reading:
        return 'Read this word: ${w.word}';
      case QuestionType.listening:
        return 'Listen and choose the correct meaning.';
      case QuestionType.readingComp:
        return 'Read the passage and answer: ${w.word}';
      case QuestionType.grammar:
        return 'Choose the correct grammar for: ${w.word}';
    }
  }

  static SubmitResult submitResult() => SubmitResult(
        correct: _rng.nextBool(),
        score: 0.5 + _rng.nextDouble() * 0.5,
        feedback: _rng.nextBool() ? 'Correct!' : 'Almost there, review the answer.',
        source: 'exact',
        nextReviewAt: DateTime.now().add(const Duration(days: 1)),
      );

  static Map<String, double> bubbles(String lang) {
    final types = questionTypesFor(lang).where((t) {
      final qt = QuestionType.fromString(t);
      return qt.isAI;
    }).toList();
    final map = <String, double>{};
    for (final t in types) {
      map[t] = 0.05 + _rng.nextDouble() * 0.9;
    }
    return map;
  }
}
