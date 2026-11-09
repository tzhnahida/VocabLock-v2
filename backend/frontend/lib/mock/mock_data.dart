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
      Word(id: 1, word: 'abandon', reading: '/əˈbændən/', meaning: 'to leave behind', pos: 'verb', language: 'en', level: 'B2',
        detail: {
          'syllable_count': '3',
          'morphology': 'regular verb, -ed/-ing forms',
          'syntax': 'transitive verb, takes direct object',
          'collocation': 'abandon hope',
          'register': 'formal / neutral',
          'etymology': 'Old French "abandoner", from "a bandon" (at will)',
          'example_sentence': 'They had to abandon the sinking ship.',
        }),
      Word(id: 2, word: 'benefit', reading: '/ˈbɛnɪfɪt/', meaning: 'an advantage', pos: 'noun', language: 'en', level: 'B1',
        detail: {
          'syllable_count': '3',
          'syntax': 'countable noun, often followed by "of"',
          'collocation': 'health benefit',
          'register': 'neutral',
          'etymology': 'Latin "benefactum" (good deed)',
          'example_sentence': 'Exercise has many health benefits.',
        }),
      Word(id: 3, word: 'create', reading: '/kriˈeɪt/', meaning: 'to make something new', pos: 'verb', language: 'en', level: 'A2',
        detail: {
          'syllable_count': '2',
          'morphology': 'regular verb, creates/created/creating',
          'syntax': 'transitive verb, takes direct object',
          'collocation': 'create opportunities',
          'register': 'neutral',
          'etymology': 'Latin "creare" (to make, produce)',
          'example_sentence': 'She wants to create a better future.',
        }),
      Word(id: 4, word: 'decision', reading: '/dɪˈsɪʒən/', meaning: 'a choice made', pos: 'noun', language: 'en', level: 'B1',
        detail: {
          'syllable_count': '3',
          'syntax': 'countable noun, often followed by "to" infinitive',
          'collocation': 'make a decision',
          'register': 'neutral',
          'etymology': 'Latin "decisio" (a cutting off)',
          'example_sentence': 'It was a difficult decision to make.',
        }),
      Word(id: 5, word: 'explain', reading: '/ɪkˈspleɪn/', meaning: 'to make clear', pos: 'verb', language: 'en', level: 'A2',
        detail: {
          'syllable_count': '2',
          'morphology': 'regular verb, explains/explained/explaining',
          'syntax': 'transitive, can take "to" indirect object',
          'collocation': 'explain the reason',
          'register': 'neutral',
          'etymology': 'Latin "explanare" (to make plain)',
          'example_sentence': 'Can you explain how this works?',
        }),
    ],
    'ja': [
      Word(id: 101, word: '食べる', reading: 'たべる', meaning: 'to eat', pos: 'verb', language: 'ja', level: 'N5',
        detail: {
          'syllable_count': '3',
          'morphology': '下一段活用動詞、連用形「食べ」',
          'syntax': '他動詞、ヲ格を取る',
          'collocation': 'ご飯を食べる',
          'register': '普通',
          'etymology': '古典日本語「食ぶ」より',
          'example_sentence': '毎日朝ごはんを食べます。',
          'pitch_accent': '中高',
          'conjugation_class': '一段',
          'case_government': 'ヲ',
          'orthographic_variants': '喰べる',
          'keigo_level': '召し上がる（尊敬語）',
        }),
      Word(id: 102, word: '歩く', reading: 'あるく', meaning: 'to walk', pos: 'verb', language: 'ja', level: 'N5',
        detail: {
          'syllable_count': '3',
          'morphology': '五段活用動詞、連用形「歩き」',
          'syntax': '自動詞、ガ格を取る',
          'collocation': '道を歩く',
          'register': '普通',
          'etymology': '古典日本語「歩く」より',
          'example_sentence': '毎日公園を歩きます。',
          'pitch_accent': '中高',
          'conjugation_class': '五段',
          'case_government': 'ガ',
        }),
      Word(id: 103, word: '美しい', reading: 'うつくしい', meaning: 'beautiful', pos: 'adj', language: 'ja', level: 'N5',
        detail: {
          'syllable_count': '5',
          'morphology': '形容詞、連用形「美しく」',
          'syntax': '連体修飾語として名詞を修飾',
          'collocation': '美しい景色',
          'register': '普通',
          'etymology': '古典日本語「うつくし」より',
          'example_sentence': '今日は美しい夕日が見えた。',
          'pitch_accent': '平板',
          'conjugation_class': '形容詞',
        }),
      Word(id: 104, word: '学校', reading: 'がっこう', meaning: 'school', pos: 'noun', language: 'ja', level: 'N5',
        detail: {
          'syllable_count': '4',
          'syntax': '場所名詞、ニ/デ格を取る',
          'collocation': '学校に行く',
          'register': '普通',
          'etymology': '「学」+「校」の漢語',
          'example_sentence': '子供たちは学校へ行きました。',
          'pitch_accent': '頭高',
        }),
      Word(id: 105, word: '話す', reading: 'はなす', meaning: 'to speak', pos: 'verb', language: 'ja', level: 'N5',
        detail: {
          'syllable_count': '3',
          'morphology': '五段活用動詞、連用形「話し」',
          'syntax': '他動詞、ヲ/ニ格を取る',
          'collocation': '日本語を話す',
          'register': '普通',
          'etymology': '「放す」と同源',
          'example_sentence': '私は日本語を少し話します。',
          'pitch_accent': '中高',
          'conjugation_class': '五段',
          'case_government': 'ヲ',
        }),
    ],
    'zh': [
      Word(id: 201, word: '学习', reading: 'xuéxí', meaning: 'to study', pos: 'verb', language: 'zh', level: 'HSK1',
        detail: {
          'syllable_count': '2',
          'morphology': '离合词，可拆分使用',
          'syntax': '及物动词，可带宾语',
          'collocation': '努力学习',
          'register': '普通',
          'example_sentence': '我每天学习中文两个小时。',
        }),
      Word(id: 202, word: '工作', reading: 'gōngzuò', meaning: 'to work', pos: 'verb', language: 'zh', level: 'HSK1',
        detail: {
          'syllable_count': '2',
          'morphology': '兼类词（动/名）',
          'syntax': '不及物动词，也可作名词',
          'collocation': '认真工作',
          'register': '普通',
          'example_sentence': '他在一家大公司工作。',
        }),
      Word(id: 203, word: '美丽', reading: 'měilì', meaning: 'beautiful', pos: 'adj', language: 'zh', level: 'HSK3',
        detail: {
          'syllable_count': '2',
          'syntax': '形容词，修饰名词',
          'collocation': '美丽的风景',
          'register': '书面/正式',
          'example_sentence': '这里的风景非常美丽。',
        }),
      Word(id: 204, word: '电脑', reading: 'diànnǎo', meaning: 'computer', pos: 'noun', language: 'zh', level: 'HSK1',
        detail: {
          'syllable_count': '2',
          'syntax': '名词，可作主语或宾语',
          'collocation': '打开电脑',
          'register': '普通',
          'etymology': '「电子」+「大脑」的缩略',
          'example_sentence': '我的电脑坏了，需要修理。',
        }),
    ],
    'ko': [
      Word(id: 301, word: '공부하다', reading: 'gongbuhada', meaning: 'to study', pos: 'verb', language: 'ko', level: 'TOPIK1',
        detail: {
          'syllable_count': '4',
          'morphology': '하다動詞、規則活用',
          'syntax': '他動詞、을/를を取る',
          'collocation': '열심히 공부하다',
          'register': '普通',
          'example_sentence': '매일 한국어를 공부합니다.',
          'conjugation_class': '하다',
        }),
      Word(id: 302, word: '아름답다', reading: 'areumdapda', meaning: 'beautiful', pos: 'adj', language: 'ko', level: 'TOPIK1',
        detail: {
          'syllable_count': '4',
          'morphology': 'ㅂ不規則形容詞',
          'syntax': '連体形「아름다운」で名詞修飾',
          'collocation': '아름다운 풍경',
          'register': '普通',
          'example_sentence': '오늘 하늘이 정말 아름답습니다.',
          'conjugation_class': 'ㅂ変格',
        }),
      Word(id: 303, word: '학교', reading: 'hakgyo', meaning: 'school', pos: 'noun', language: 'ko', level: 'TOPIK1',
        detail: {
          'syllable_count': '2',
          'syntax': '場所名詞、에/에서を取る',
          'collocation': '학교에 가다',
          'register': '普通',
          'etymology': '漢字語「學校」',
          'example_sentence': '아이들이 학교에 갔습니다.',
        }),
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
      options: qt == QuestionType.choice ||
              (qt.isAI && qt != QuestionType.dialogueWrite && qt != QuestionType.dialogueSpeak)
          ? ['Option A', 'Option B', 'Option C', w.meaning]
          : null,
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
      case QuestionType.readWord:
        return 'Read the word aloud: ${w.word}';
      case QuestionType.pronounce:
        return 'Enter the pronunciation of: ${w.word}';
      case QuestionType.meaning:
        return 'What does this mean?: ${w.word}';
      case QuestionType.readSentence:
        return 'Read the sentence aloud: ${w.meaning}';
      case QuestionType.dialogueWrite:
        return 'Answer in writing with "${w.word}": What did you do today?';
      case QuestionType.dialogueSpeak:
        return 'Answer aloud with "${w.word}": What did you do today?';
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
