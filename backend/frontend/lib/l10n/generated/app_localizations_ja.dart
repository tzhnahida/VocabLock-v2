// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'VocabLock';

  @override
  String get sidebarQuiz => '学習';

  @override
  String get sidebarWords => '単語帳';

  @override
  String get sidebarAudio => '音声';

  @override
  String get sidebarStats => '統計';

  @override
  String get sidebarConfig => '設定';

  @override
  String get sidebarAI => 'AI';

  @override
  String get sidebarReview => 'レビュー';

  @override
  String get sidebarHomework => '宿題';

  @override
  String get sectionLearning => '学習';

  @override
  String get sectionAIPlan => 'AI学習プラン';

  @override
  String get sectionPassive => 'パッシブ出題 (近日公開)';

  @override
  String get sectionExpand => 'AI単語拡張';

  @override
  String get sectionAssignment => '宿題';

  @override
  String get sectionAIModel => 'AIモデル';

  @override
  String get sectionTTS => 'TTSプロバイダー';

  @override
  String get sectionDict => '辞書プロバイダー';

  @override
  String get sectionSystem => 'システム';

  @override
  String get dailyTarget => '1日の目標';

  @override
  String get minAccuracy => '最低正解率';

  @override
  String get sessionTimeBudget => '学習時間(分, 0=無制限)';

  @override
  String get maxSlowTypeRatio => '低速問題の上限';

  @override
  String get autoExpand => '自動拡張';

  @override
  String get expandBatchSize => '1回の拡張数';

  @override
  String get sm2MaxInterval => 'SM-2 最大間隔(日)';

  @override
  String get autoStart => '自動起動 (近日公開)';

  @override
  String get difficulty => '難易度';

  @override
  String get suggestedWordCount => '推奨単語数';

  @override
  String get typeRatio => '問題タイプ比率';

  @override
  String get grammarFocus => '文法フォーカス';

  @override
  String get noPlanYet => '学習セッションを完了するとAIがプランを生成します';

  @override
  String get planParseError => 'プランデータの解析に失敗しました';

  @override
  String get configured => '設定済み';

  @override
  String get notConfigured => '未設定';

  @override
  String get tapToRefresh => 'タップして読み込み';

  @override
  String get fieldPos => '品詞';

  @override
  String get fieldLevel => 'レベル';

  @override
  String get fieldSyllableCount => 'モーラ数';

  @override
  String get fieldMorphology => '形態変化';

  @override
  String get fieldSyntax => '統語機能';

  @override
  String get fieldCollocation => 'よく使う組み合わせ';

  @override
  String get fieldRegister => '使用域';

  @override
  String get fieldEtymology => '語源';

  @override
  String get fieldExampleSentence => '例文';

  @override
  String get fieldPitchAccent => '高低アクセント';

  @override
  String get fieldConjugationClass => '活用型';

  @override
  String get fieldCaseGovernment => '格支配';

  @override
  String get fieldOrthographicVariants => '表記揺れ';

  @override
  String get fieldKeigoLevel => '敬語階層';

  @override
  String get statusPendingReview => '要確認';

  @override
  String get statusAIFilled => 'AI生成';

  @override
  String get tooltipPlayAudio => '発音を再生';

  @override
  String get tabWords => '単語';

  @override
  String get tabGrammar => '文法';

  @override
  String get headingLibrary => 'ライブラリ';

  @override
  String get labelMastered => '習得済み';

  @override
  String get searchHint => '単語や意味を検索...';

  @override
  String get quizStart => '学習開始';

  @override
  String get quizNext => '次の問題';

  @override
  String get quizSkip => 'スキップ';

  @override
  String get quizSubmit => '提出';

  @override
  String get quizCorrect => '正解！';

  @override
  String get quizIncorrect => '不正解';

  @override
  String get quizExpired => '問題の有効期限が切れました';

  @override
  String get quizNewWords => '新しい単語';

  @override
  String get quizReviewWords => '復習単語';

  @override
  String get quizNewGrammar => '新しい文法';

  @override
  String get quizReviewGrammar => '復習文法';

  @override
  String get quizNoItems => '復習項目がありません';

  @override
  String get quizDailyTargetMet => '今日の目標達成';

  @override
  String get labelLanguage => '言語';

  @override
  String get labelCurrentLanguage => '現在の言語';

  @override
  String get labelAvailableLanguages => '利用可能な言語';

  @override
  String get labelBaseInfo => '基本情報';

  @override
  String get labelNativeName => '現地名';

  @override
  String get labelTTS => 'TTS';

  @override
  String get labelProvider => 'プロバイダー';

  @override
  String get labelVoice => '音声';

  @override
  String get labelDict => '辞書';

  @override
  String get labelPrompt => 'AIプロンプト';

  @override
  String get labelTeacherRole => '教師役';

  @override
  String get labelExplanationLang => '説明言語';

  @override
  String get labelLevelDescriptions => 'レベル説明';

  @override
  String get labelQuestionTypes => '問題タイプ';

  @override
  String get labelEnabledTypes => '有効なタイプ';

  @override
  String get labelVoices => '音声';

  @override
  String get labelWithLevel => 'レベル付き';

  @override
  String get labelNoLevel => 'レベルなし';
}
