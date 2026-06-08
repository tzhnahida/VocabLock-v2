// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VocabLock';

  @override
  String get sidebarQuiz => 'Quiz';

  @override
  String get sidebarWords => 'Words';

  @override
  String get sidebarAudio => 'Audio';

  @override
  String get sidebarStats => 'Stats';

  @override
  String get sidebarConfig => 'Settings';

  @override
  String get sidebarAI => 'AI';

  @override
  String get sidebarReview => 'Review';

  @override
  String get sidebarHomework => 'Homework';

  @override
  String get sectionLearning => 'Learning';

  @override
  String get sectionAIPlan => 'AI Study Plan';

  @override
  String get sectionPassive => 'Passive Quiz (Coming Soon)';

  @override
  String get sectionExpand => 'AI Word Expansion';

  @override
  String get sectionAssignment => 'Assignments';

  @override
  String get sectionAIModel => 'AI Model';

  @override
  String get sectionTTS => 'TTS Providers';

  @override
  String get sectionDict => 'Dictionary Providers';

  @override
  String get sectionSystem => 'System';

  @override
  String get dailyTarget => 'Daily Target';

  @override
  String get minAccuracy => 'Min Accuracy';

  @override
  String get sessionTimeBudget => 'Session Time (min, 0=unlimited)';

  @override
  String get maxSlowTypeRatio => 'Max Slow Type Ratio';

  @override
  String get autoExpand => 'Auto Expand';

  @override
  String get expandBatchSize => 'Batch Size';

  @override
  String get sm2MaxInterval => 'SM-2 Max Interval (days)';

  @override
  String get autoStart => 'Auto Start (Coming Soon)';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get suggestedWordCount => 'Suggested Word Count';

  @override
  String get typeRatio => 'Type Ratio';

  @override
  String get grammarFocus => 'Grammar Focus';

  @override
  String get noPlanYet =>
      'Complete a learning session for AI to generate a plan';

  @override
  String get planParseError => 'Failed to parse plan data';

  @override
  String get configured => 'Configured';

  @override
  String get notConfigured => 'Not Configured';

  @override
  String get tapToRefresh => 'Tap refresh to load';

  @override
  String get fieldPos => 'POS';

  @override
  String get fieldLevel => 'Level';

  @override
  String get fieldSyllableCount => 'Syllables';

  @override
  String get fieldMorphology => 'Morphology';

  @override
  String get fieldSyntax => 'Syntax';

  @override
  String get fieldCollocation => 'Collocation';

  @override
  String get fieldRegister => 'Register';

  @override
  String get fieldEtymology => 'Etymology';

  @override
  String get fieldExampleSentence => 'Example';

  @override
  String get statusPendingReview => 'Pending Review';

  @override
  String get statusAIFilled => 'AI Filled';

  @override
  String get tooltipPlayAudio => 'Play pronunciation';

  @override
  String get tabWords => 'Words';

  @override
  String get tabGrammar => 'Grammar';

  @override
  String get headingLibrary => 'Library';

  @override
  String get labelMastered => 'Mastered';

  @override
  String get searchHint => 'Search words or meanings...';

  @override
  String get quizStart => 'Start Quiz';

  @override
  String get quizNext => 'Next Question';

  @override
  String get quizSkip => 'Skip';

  @override
  String get quizSubmit => 'Submit';

  @override
  String get quizCorrect => 'Correct!';

  @override
  String get quizIncorrect => 'Incorrect';

  @override
  String get quizExpired => 'Question expired, please get a new one';

  @override
  String get quizNewWords => 'New Words';

  @override
  String get quizReviewWords => 'Review Words';

  @override
  String get quizNewGrammar => 'New Grammar';

  @override
  String get quizReviewGrammar => 'Review Grammar';

  @override
  String get quizNoItems => 'No items to review';

  @override
  String get quizDailyTargetMet => 'Daily target met';

  @override
  String get quizDismiss => 'Back';

  @override
  String get quizDontKnow => 'I don\'t know, show me the answer';

  @override
  String get recordingStart => 'Start Recording';

  @override
  String get recordingDone => 'Recorded';

  @override
  String get recordingInProgress => 'Recording...';

  @override
  String get recordingStop => 'Stop Recording';

  @override
  String get recordingRetry => 'Re-record';

  @override
  String get recordingDontKnow => 'I can\'t read this, show answer';

  @override
  String get quizTypeAnswer => 'Type your answer...';

  @override
  String get aiPreparingContent => 'AI is preparing learning content...';

  @override
  String get aiPreparingPleaseWait =>
      'Please wait, first-time generation may take 10-20s';

  @override
  String get aiAnalyzing => 'AI is analyzing your learning data...';

  @override
  String get viewAISummary => 'View AI Summary';

  @override
  String get quizCompletedToday => 'Daily learning complete!';

  @override
  String quizAccuracy(Object pct) {
    return 'Accuracy: $pct%';
  }

  @override
  String quizCorrectCount(Object correct, Object answered) {
    return '$correct/$answered correct';
  }

  @override
  String quizQuestionProgress(Object answered, Object correct, Object pct) {
    return '${answered}Q · $correct ✓ · $pct%';
  }

  @override
  String quizTotalEstimate(Object total, Object minutes) {
    return '$total questions · ~$minutes min';
  }

  @override
  String get quizBeginLearning => 'Start Learning';

  @override
  String get quizNoContentReturn => 'No content, go back';

  @override
  String get quizDailyTitle => 'Today\'s Study';

  @override
  String get quizSM2Subtitle => 'SM-2 smart review + AI curated content';

  @override
  String get quizLearnNewContent => 'Learn New Content';

  @override
  String quizBeginWithCount(Object count) {
    return 'Start Quiz ($count questions)';
  }

  @override
  String get quizCongrats => 'Congratulations!';

  @override
  String get quizKeepGoing => 'Keep it up!';

  @override
  String get quizCompletedDone => 'Done';

  @override
  String get quizAppBarTitle => 'Quiz';

  @override
  String get readAloudPass => 'PASS';

  @override
  String get readAloudNeedWork => 'NEED WORK';

  @override
  String readAloudScoreLabel(Object score, Object threshold) {
    return 'Score $score% (need ≥ $threshold%)';
  }

  @override
  String get readAloudListenFirst => 'Listen first, then answer';

  @override
  String get fieldMeaning => 'Meaning';

  @override
  String cardPageOf(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get labelLanguage => 'Language';

  @override
  String get labelCurrentLanguage => 'Current Language';

  @override
  String get labelAvailableLanguages => 'Available Languages';

  @override
  String get labelBaseInfo => 'Basic Info';

  @override
  String get labelNativeName => 'Native Name';

  @override
  String get labelTTS => 'TTS';

  @override
  String get labelProvider => 'Provider';

  @override
  String get labelVoice => 'Voice';

  @override
  String get labelDict => 'Dictionary';

  @override
  String get labelPrompt => 'AI Prompt';

  @override
  String get labelTeacherRole => 'Teacher Role';

  @override
  String get labelExplanationLang => 'Explanation Language';

  @override
  String get labelLevelDescriptions => 'Level Descriptions';

  @override
  String get labelQuestionTypes => 'Question Types';

  @override
  String get labelEnabledTypes => 'Enabled Types';

  @override
  String get labelVoices => 'voices';

  @override
  String get labelWithLevel => 'With Level';

  @override
  String get labelNoLevel => 'No Level';

  @override
  String get tabGeneral => 'General';

  @override
  String get labelEnabled => 'Enabled';

  @override
  String get labelMinIntervalMinutes => 'Min Interval (min)';

  @override
  String get labelMaxIntervalMinutes => 'Max Interval (min)';

  @override
  String get labelCadenceDays => 'Every N Days';

  @override
  String get labelCadenceCount => 'Questions Per Batch';

  @override
  String get labelAIRecommend => 'AI Recommend';

  @override
  String get labelModel => 'Model';

  @override
  String get labelAddress => 'Address';

  @override
  String get labelStatus => 'Status';

  @override
  String get hintRefreshTTS => 'Tap refresh to load TTS config';

  @override
  String get hintRefreshDict => 'Tap refresh to load dictionary config';

  @override
  String get labelSettings => 'Settings';

  @override
  String get labelRetry => 'Retry';

  @override
  String statusRemaining(Object count) {
    return '$count remaining';
  }

  @override
  String get statusDailyComplete => 'Daily task complete';

  @override
  String statusWordsReady(Object count) {
    return '$count words ready, start the quiz';
  }
}
