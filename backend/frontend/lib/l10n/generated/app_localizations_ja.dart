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
  String get quizDismiss => '戻る';

  @override
  String get quizTypeChoice => '選択問題';

  @override
  String get quizTypeFill => '穴埋め問題';

  @override
  String get quizTypeSpelling => '綴り問題';

  @override
  String get quizTypePronounce => '読み方問題';

  @override
  String get quizTypeMeaning => '翻訳問題';

  @override
  String get quizTypeReadWord => '音読問題';

  @override
  String get quizTypeReadSentence => '文章音読';

  @override
  String get quizTypeListening => '聴解問題';

  @override
  String get quizTypeReadingComp => '読解問題';

  @override
  String get quizTypeGrammar => '文法問題';

  @override
  String get quizDontKnow => 'わからない、答えを教えて';

  @override
  String get recordingStart => '録音開始';

  @override
  String get recordingDone => '録音完了';

  @override
  String get recordingInProgress => '録音中...';

  @override
  String get recordingStop => '録音停止';

  @override
  String get recordingRetry => '再録音';

  @override
  String get recordingDontKnow => '読めない、答えを教えて';

  @override
  String get quizTypeAnswer => '答えを入力...';

  @override
  String get aiPreparingContent => 'AIが学習コンテンツを準備中...';

  @override
  String get aiPreparingPleaseWait => '初回生成には10-20秒かかることがあります';

  @override
  String get aiAnalyzing => 'AIが学習データを分析中...';

  @override
  String get viewAISummary => 'AI学習サマリーを見る';

  @override
  String get quizCompletedToday => '今日の学習完了！';

  @override
  String quizAccuracy(Object pct) {
    return '正解率: $pct%';
  }

  @override
  String quizCorrectCount(Object correct, Object answered) {
    return '$correct/$answered 正解';
  }

  @override
  String quizQuestionProgress(Object answered, Object correct, Object pct) {
    return '$answered問 · $correct ✓ · $pct%';
  }

  @override
  String quizTotalEstimate(Object total, Object minutes) {
    return '計 $total 問 · 約 $minutes 分';
  }

  @override
  String get quizBeginLearning => '学習開始';

  @override
  String get quizNoContentReturn => 'コンテンツなし、戻る';

  @override
  String get quizDailyTitle => '今日の学習';

  @override
  String get quizSM2Subtitle => 'SM-2スマート復習 + AIキュレーション';

  @override
  String get quizLearnNewContent => '新しい内容を学ぶ';

  @override
  String quizBeginWithCount(Object count) {
    return '問題開始 ($count 問)';
  }

  @override
  String get quizCongrats => 'おめでとう！';

  @override
  String get quizKeepGoing => '頑張りましょう！';

  @override
  String get quizCompletedDone => '完了';

  @override
  String get quizAppBarTitle => '学習';

  @override
  String get readAloudPass => '合格';

  @override
  String get readAloudNeedWork => '要改善';

  @override
  String readAloudScoreLabel(Object score, Object threshold) {
    return 'スコア $score% (必要 ≥ $threshold%)';
  }

  @override
  String get readAloudListenFirst => 'まず聞いてから答えてください';

  @override
  String get fieldMeaning => '意味';

  @override
  String cardPageOf(Object current, Object total) {
    return '$current / $total';
  }

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

  @override
  String get tabGeneral => '一般';

  @override
  String get labelEnabled => '有効';

  @override
  String get labelMinIntervalMinutes => '最小間隔(分)';

  @override
  String get labelMaxIntervalMinutes => '最大間隔(分)';

  @override
  String get labelCadenceDays => 'N日ごと';

  @override
  String get labelCadenceCount => '1回の問題数';

  @override
  String get labelAIRecommend => 'AIおすすめ';

  @override
  String get labelModel => 'モデル';

  @override
  String get labelAddress => 'アドレス';

  @override
  String get labelStatus => '状態';

  @override
  String get hintRefreshTTS => 'タップしてTTS設定を読み込み';

  @override
  String get hintRefreshDict => 'タップして辞書設定を読み込み';

  @override
  String get labelSettings => '設定';

  @override
  String get labelRetry => 'リトライ';

  @override
  String statusRemaining(Object count) {
    return '残り $count 問';
  }

  @override
  String get statusDailyComplete => '今日のタスク完了';

  @override
  String statusWordsReady(Object count) {
    return '$count 語が準備完了、学習を開始できます';
  }

  @override
  String get onboardingInterface => 'インターフェース';

  @override
  String get onboardingInterfaceLanguage => 'インターフェース言語';

  @override
  String get onboardingTheme => 'テーマ';

  @override
  String get onboardingLight => 'ライト';

  @override
  String get onboardingDark => 'ダーク';

  @override
  String get onboardingContinue => '続ける';

  @override
  String get onboardingAIConfig => 'AI設定';

  @override
  String get onboardingAIDesc => 'AIによる出題、個別指導、学習サマリーに使用';

  @override
  String get onboardingAIRegister => '登録: platform.deepseek.com → API Keys';

  @override
  String get onboardingNextAI => '次へ → AIガイド';

  @override
  String get onboardingSkipAI => 'AI設定をスキップ';

  @override
  String get onboardingSkipAIHint => 'ローカル出題モードを使用します（後で設定から追加可能）';

  @override
  String get onboardingAIAdvisor => 'AI学習アドバイザー';

  @override
  String get onboardingGeneratePlan => '学習プランを生成';

  @override
  String get onboardingPlanDone => 'プロファイル作成済み、続ける →';

  @override
  String get onboardingSkipInterview => 'インタビューをスキップ';

  @override
  String get onboardingStudySetup => '学習設定';

  @override
  String get onboardingEscapePassword => '緊急パスワード';

  @override
  String get onboardingEscapePasswordHint => 'ロック解除に使用（必ず覚えてください）';

  @override
  String get onboardingLanguageToStudy => '学習言語';

  @override
  String get onboardingDailyTarget => '1日の目標';

  @override
  String get onboardingAccuracyHint => '正解率80%以上でロック解除';

  @override
  String get onboardingComplete => '設定完了、学習開始';
}
