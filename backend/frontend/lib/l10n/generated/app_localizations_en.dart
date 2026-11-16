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
  String get sectionPassive => 'Passive Quiz';

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
  String get quizTypeChoice => 'Choice';

  @override
  String get quizTypeFill => 'Fill-in';

  @override
  String get quizTypeSpelling => 'Spelling';

  @override
  String get quizTypePronounce => 'Reading';

  @override
  String get quizTypeMeaning => 'Translation';

  @override
  String get quizTypeReadWord => 'Read Aloud';

  @override
  String get quizTypeDialogueWrite => 'Dialogue (write)';

  @override
  String get quizTypeDialogueSpeak => 'Dialogue (speak)';

  @override
  String get quizTypeReadSentence => 'Read Sentence';

  @override
  String get quizTypeListening => 'Listening';

  @override
  String get quizTypeReadingComp => 'Reading Comp';

  @override
  String get quizTypeGrammar => 'Grammar';

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
  String get dialogueSpeakInstruction =>
      'Speak a complete answer using the word';

  @override
  String get dialogueTranscript => 'Recognized speech';

  @override
  String get dialogueReference => 'Reference answer';

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

  @override
  String get onboardingInterface => 'Interface';

  @override
  String get onboardingInterfaceLanguage => 'Interface Language';

  @override
  String get onboardingTheme => 'Theme';

  @override
  String get onboardingLight => 'Light';

  @override
  String get onboardingDark => 'Dark';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingAIConfig => 'AI Setup';

  @override
  String get onboardingAIDesc =>
      'Used for AI-powered quizzes, personalized tutoring, and session summaries';

  @override
  String get onboardingAIRegister =>
      'Sign up at platform.deepseek.com → API Keys';

  @override
  String get onboardingNextAI => 'Next → AI Guide';

  @override
  String get onboardingSkipAI => 'Skip AI Setup';

  @override
  String get onboardingSkipAIHint =>
      'Local quiz mode will be used. You can configure AI later in Settings.';

  @override
  String get onboardingAIAdvisor => 'AI Learning Advisor';

  @override
  String get onboardingGeneratePlan => 'Generate Study Plan';

  @override
  String get onboardingPlanDone => 'Profile created, continue →';

  @override
  String get onboardingSkipInterview => 'Skip interview, go to setup';

  @override
  String get onboardingStudySetup => 'Study Setup';

  @override
  String get onboardingEscapePassword => 'Escape Password';

  @override
  String get onboardingEscapePasswordHint =>
      'Used for emergency unlock (please memorize)';

  @override
  String get onboardingLanguageToStudy => 'Language to study';

  @override
  String get onboardingDailyTarget => 'Daily Study Time';

  @override
  String get onboardingAccuracyHint => 'Accuracy >= 80% required to unlock';

  @override
  String get onboardingMinutes => 'min';

  @override
  String get onboardingQuestionsUnit => 'questions';

  @override
  String get onboardingComplete => 'Complete Setup, Start Learning';

  @override
  String get serverOfflineBanner =>
      'Server unreachable — some features are limited';

  @override
  String get retry => 'Retry';

  @override
  String get completionCongrats => 'Congratulations! Daily goal achieved!';

  @override
  String get completionDone => 'Daily task complete';

  @override
  String get statAnswered => 'Answered';

  @override
  String get statCorrect => 'Correct';

  @override
  String get statAccuracy => 'Accuracy';

  @override
  String get completionHint =>
      'You can browse words, use the AI assistant, or view stats.';

  @override
  String get practiceAgain => 'Practice again';

  @override
  String get onboardingWelcomeTitle => 'Welcome to VocabLock';

  @override
  String get onboardingWelcomeSubtitle =>
      'Master vocabulary through spaced repetition,\nAI-powered quizzes, and immersive practice.';

  @override
  String get onboardingFeature1 =>
      '7 question types with AI-powered generation';

  @override
  String get onboardingFeature2 => 'Listening, reading & grammar practice';

  @override
  String get onboardingFeature3 =>
      'Multi-language support with dynamic theming';

  @override
  String get onboardingFeature4 =>
      'Focus lock screen for distraction-free study';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingAiConfiguredEnv =>
      'AI is configured via environment variable VOCABLOCK_AI_KEY';

  @override
  String get onboardingTestConnection => 'Test connection';

  @override
  String get onboardingTestSuccess => '✅ Connected';

  @override
  String get onboardingTestNoResponse => '❌ No response';

  @override
  String get onboardingTestConfigured => '✅ Configured';

  @override
  String get onboardingTestBadFormat => '⚠️ Key format may be incorrect';

  @override
  String get onboardingTestFailed =>
      '❌ Connection failed — check API key or network';

  @override
  String onboardingInterviewRoundCount(Object rounds) {
    return 'Rounds: $rounds';
  }

  @override
  String get onboardingInterviewDone => ' · Profile created';

  @override
  String get onboardingInterviewReady => ' · Ready to generate plan';

  @override
  String onboardingInterviewMinHint(Object rounds) {
    return ' (min $rounds rounds)';
  }

  @override
  String get onboardingConnectingAI => 'Connecting to AI...';

  @override
  String get onboardingAIThinking => 'AI is thinking...';

  @override
  String get onboardingChatInputHint => 'Type your answer...';

  @override
  String get onboardingAiFailed =>
      'AI assistant connection failed, check your network and retry.';

  @override
  String get onboardingAiTimeout =>
      'AI response timed out — tap below to retry.';

  @override
  String get onboardingVoiceTts => 'Text-to-Speech (TTS)';

  @override
  String get onboardingDictCheck => 'Dictionary check (Dict)';

  @override
  String get onboardingConnected => 'Connected';

  @override
  String get onboardingNotConnected => 'Not connected';

  @override
  String get onboardingNotConfigured => 'Not configured';

  @override
  String get progressToday => 'Today\'s Progress';

  @override
  String get progressWordsUnit => 'words';

  @override
  String get labelRecentMistakes => 'Recent Mistakes';

  @override
  String get labelAccuracy => 'Accuracy';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get homeworkEmpty => 'No homework yet';

  @override
  String get homeworkEmptyHint =>
      'Homework appears according to your cadence — it\'s not time yet.';

  @override
  String get homeworkRecommendedCadence => 'Recommended cadence';

  @override
  String get homeworkAnswerHint => 'Write your answer here...';

  @override
  String get nextQuestion => 'Next question';

  @override
  String get typeSentence => 'Sentence';

  @override
  String get typeTranslation => 'Translation';

  @override
  String get typeFillPassage => 'Fill the passage';

  @override
  String get typeEssay => 'Short essay';

  @override
  String homeworkCadence(Object count, Object days) {
    return 'AI recommends: $count questions every $days days';
  }

  @override
  String get yourAnswer => 'Your answer';

  @override
  String get aiPolish => 'AI polish';

  @override
  String scoreBar(Object pct) {
    return 'Score $pct%';
  }

  @override
  String get errorMarkLabel => 'Error marks:';

  @override
  String get aiSessionSummary => 'AI Session Summary';

  @override
  String get aiAnalyzingSession =>
      'AI is analyzing your session and updating your study plan...';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get aiAnalysisFailed => 'AI analysis failed';

  @override
  String get gotIt => 'Got it';

  @override
  String get sessionAnalysis => 'This session\'s analysis';

  @override
  String get labelStrengths => 'Strengths:';

  @override
  String get labelWeaknesses => 'To improve:';

  @override
  String get labelSuggestions => 'Study suggestions';

  @override
  String get labelUpdatedPlan => 'Updated study plan';

  @override
  String get labelPlanDirection => 'Direction';

  @override
  String get labelPlanConfidence => 'Confidence';

  @override
  String get audioGenerating => 'Generating...';

  @override
  String get audioPlaying => 'Playing...';

  @override
  String get audioPlayed => 'Finished';

  @override
  String get audioNotConfigured =>
      'TTS not configured (external binary required)';

  @override
  String get audioGenerateFailed => 'Generation failed';

  @override
  String get audioPlayFailed => 'Playback failed';

  @override
  String get audioUnavailable => 'TTS unavailable';

  @override
  String audioPlayingWord(Object word) {
    return 'Playing: $word';
  }

  @override
  String audioPlayedWord(Object word) {
    return 'Played: $word';
  }

  @override
  String get audioPreviewHint => 'Type text to preview...';

  @override
  String get audioQuickPlay => 'Quick play';

  @override
  String get audioNoWords => 'No words yet';

  @override
  String approveTitle(Object word) {
    return 'Approve \"$word\"';
  }

  @override
  String get fieldReadingRequired => 'Reading (required)';

  @override
  String get fieldMeaningRequired => 'Meaning (required)';

  @override
  String get fieldPosRequired => 'Part of speech (required)';

  @override
  String get fieldLevelOptional => 'Level (optional)';

  @override
  String get cancel => 'Cancel';

  @override
  String get approve => 'Approve';

  @override
  String approvedMsg(Object word) {
    return '\"$word\" approved';
  }

  @override
  String rejectTitle(Object word) {
    return 'Reject \"$word\"';
  }

  @override
  String get rejectReasonHint => 'Reason (feedback for AI)';

  @override
  String get reject => 'Reject';

  @override
  String rejectedMsg(Object word) {
    return '\"$word\" returned to AI';
  }

  @override
  String editTagsTitle(Object word) {
    return 'Edit tags: $word';
  }

  @override
  String get tagsHint => 'Comma-separated, e.g. hard, confusing, exam focus';

  @override
  String get save => 'Save';

  @override
  String opFailed(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String get pendingTitle => 'Pending Review';

  @override
  String loadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String get pendingEmpty => 'No words pending review';

  @override
  String get pendingEmptyHint =>
      'AI-generated words validated by the dictionary are added automatically;\nwords that fail validation appear here for your review.';

  @override
  String get pendingBadge => 'Pending';

  @override
  String get labelTags => 'Tags';

  @override
  String get tagsUpdated => 'Tags updated';

  @override
  String get submit => 'Submit';

  @override
  String get exit => 'Exit';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statStreak => 'Current Streak';

  @override
  String statOfTotal(Object total) {
    return 'of $total';
  }

  @override
  String get statActivity => 'Activity';

  @override
  String get aiChatTitle => 'AI Chat';

  @override
  String get aiChatEmptyHint => 'Ask me anything about your vocabulary!';

  @override
  String get aiChatInputHint => 'Type a message...';

  @override
  String get expandStatusGenerating => 'AI is generating new words...';

  @override
  String expandStatusDone(Object direction, Object count, Object verified,
      Object pending, Object context) {
    return 'Generated $count words for [$direction] ($verified added, $pending pending review, $context existing words considered)';
  }

  @override
  String expandStatusDoneSimple(Object count, Object verified, Object pending) {
    return 'Generated $count words ($verified added, $pending pending review)';
  }

  @override
  String get expandStatusNone => 'No new words generated';

  @override
  String get expandStatusFailed => 'Word generation failed';

  @override
  String get expandStatusNoApi => 'API not connected — cannot generate words';

  @override
  String quizGoalRemaining(Object count) {
    return 'Today\'s goal: $count more questions to unlock';
  }

  @override
  String get quizReviewPool => 'Due review pool';

  @override
  String quizReviewNote(Object count) {
    return '$count items due — session ends automatically once the goal is met';
  }

  @override
  String quizEstimateGoal(Object count, Object minutes) {
    return 'Goal: $count questions · ~$minutes min';
  }

  @override
  String get disputeGrade => 'I think this was graded wrong';

  @override
  String get sessionEmpty => 'Nothing to study right now';

  @override
  String get sessionEmptyHint =>
      'Import more words, or configure AI expansion. Words on long intervals will return on their due dates.';

  @override
  String get sessionContinue => 'Keep training';

  @override
  String get pendingAcceptAll => 'Accept all';

  @override
  String pendingAcceptAllDone(Object activated, Object skipped) {
    return 'Activated $activated, skipped $skipped (missing meaning)';
  }

  @override
  String get sidebarDiagnostics => 'Diagnostics';

  @override
  String get sidebarPassive => 'Passive';

  @override
  String get diagnosticsTitle => 'Learning diagnostics';

  @override
  String diagnosticsWindowShort(Object count) {
    return '${count}d';
  }

  @override
  String diagnosticsWindow(Object days) {
    return 'Last $days days';
  }

  @override
  String get diagnosticsCoverage => 'Vocabulary coverage';

  @override
  String get diagnosticsWords => 'Words';

  @override
  String get diagnosticsLongTerm => 'Long-term';

  @override
  String get diagnosticsPending => 'Pending';

  @override
  String get diagnosticsErrors => 'Error causes';

  @override
  String get diagnosticsNoErrors => 'No wrong answers in this window.';

  @override
  String get diagnosticsWeakPhonemes => 'Weak phonemes';

  @override
  String get diagnosticsNoPhonemes =>
      'No read-aloud phoneme data yet — it appears after a pronunciation question.';

  @override
  String diagnosticsPhonemesMeasured(Object count) {
    return 'Based on $count read-aloud rows';
  }

  @override
  String get diagnosticsAIDisagreement => 'AI grading disagreement';

  @override
  String get diagnosticsNoAIVerdicts => 'No AI verdicts in this window.';

  @override
  String get diagnosticsAIVerdicts => 'AI verdicts';

  @override
  String get diagnosticsAIFalseNegatives => 'Likely false negatives';

  @override
  String get diagnosticsAISamples => 'Samples (your answer | expected)';

  @override
  String get diagnosticsTypeAccuracy => 'Accuracy by question type';

  @override
  String get diagnosticsNoTypes => 'No answers in this window.';

  @override
  String get diagnosticsEmpty => 'Nothing to diagnose yet';

  @override
  String get diagnosticsEmptyHint =>
      'Finish a few sessions and this panel fills in.';

  @override
  String get errorCategorySimilarity => 'Form / sound confusion';

  @override
  String get errorCategoryEmpty => 'Blank answer';

  @override
  String get errorCategoryOther => 'Other';

  @override
  String get errorCategoryUnlabeled => 'Unlabeled';

  @override
  String get passiveTitle => 'Passive recall';

  @override
  String get passiveHint =>
      'Recall the meaning first — reveal only when you have an answer.';

  @override
  String get passiveReveal => 'Reveal meaning';

  @override
  String get passiveRemember => 'Remembered';

  @override
  String get passiveHard => 'Hard';

  @override
  String get passiveForgot => 'Forgot';

  @override
  String get passiveEmpty => 'Nothing due right now';

  @override
  String get passiveEmptyHint =>
      'Words show up here when they are due for review.';

  @override
  String passiveAnswered(Object count) {
    return 'Rated this round: $count';
  }

  @override
  String get passiveSubmitRejected => 'The server did not accept that rating.';

  @override
  String homeworkNextDue(Object when) {
    return 'Next homework: $when';
  }

  @override
  String get homeworkAIRequired =>
      'Homework needs an AI provider — configure one in Settings.';

  @override
  String get homeworkGenerationFailed =>
      'AI could not generate homework. Try again later.';
}
