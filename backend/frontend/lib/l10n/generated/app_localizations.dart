import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('ja')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'VocabLock'**
  String get appTitle;

  /// No description provided for @sidebarQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get sidebarQuiz;

  /// No description provided for @sidebarWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get sidebarWords;

  /// No description provided for @sidebarAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get sidebarAudio;

  /// No description provided for @sidebarStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get sidebarStats;

  /// No description provided for @sidebarConfig.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sidebarConfig;

  /// No description provided for @sidebarAI.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get sidebarAI;

  /// No description provided for @sidebarReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get sidebarReview;

  /// No description provided for @sidebarHomework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get sidebarHomework;

  /// No description provided for @sectionLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get sectionLearning;

  /// No description provided for @sectionAIPlan.
  ///
  /// In en, this message translates to:
  /// **'AI Study Plan'**
  String get sectionAIPlan;

  /// No description provided for @sectionPassive.
  ///
  /// In en, this message translates to:
  /// **'Passive Quiz (Coming Soon)'**
  String get sectionPassive;

  /// No description provided for @sectionExpand.
  ///
  /// In en, this message translates to:
  /// **'AI Word Expansion'**
  String get sectionExpand;

  /// No description provided for @sectionAssignment.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get sectionAssignment;

  /// No description provided for @sectionAIModel.
  ///
  /// In en, this message translates to:
  /// **'AI Model'**
  String get sectionAIModel;

  /// No description provided for @sectionTTS.
  ///
  /// In en, this message translates to:
  /// **'TTS Providers'**
  String get sectionTTS;

  /// No description provided for @sectionDict.
  ///
  /// In en, this message translates to:
  /// **'Dictionary Providers'**
  String get sectionDict;

  /// No description provided for @sectionSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get sectionSystem;

  /// No description provided for @dailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily Target'**
  String get dailyTarget;

  /// No description provided for @minAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Min Accuracy'**
  String get minAccuracy;

  /// No description provided for @sessionTimeBudget.
  ///
  /// In en, this message translates to:
  /// **'Session Time (min, 0=unlimited)'**
  String get sessionTimeBudget;

  /// No description provided for @maxSlowTypeRatio.
  ///
  /// In en, this message translates to:
  /// **'Max Slow Type Ratio'**
  String get maxSlowTypeRatio;

  /// No description provided for @autoExpand.
  ///
  /// In en, this message translates to:
  /// **'Auto Expand'**
  String get autoExpand;

  /// No description provided for @expandBatchSize.
  ///
  /// In en, this message translates to:
  /// **'Batch Size'**
  String get expandBatchSize;

  /// No description provided for @sm2MaxInterval.
  ///
  /// In en, this message translates to:
  /// **'SM-2 Max Interval (days)'**
  String get sm2MaxInterval;

  /// No description provided for @autoStart.
  ///
  /// In en, this message translates to:
  /// **'Auto Start (Coming Soon)'**
  String get autoStart;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @suggestedWordCount.
  ///
  /// In en, this message translates to:
  /// **'Suggested Word Count'**
  String get suggestedWordCount;

  /// No description provided for @typeRatio.
  ///
  /// In en, this message translates to:
  /// **'Type Ratio'**
  String get typeRatio;

  /// No description provided for @grammarFocus.
  ///
  /// In en, this message translates to:
  /// **'Grammar Focus'**
  String get grammarFocus;

  /// No description provided for @noPlanYet.
  ///
  /// In en, this message translates to:
  /// **'Complete a learning session for AI to generate a plan'**
  String get noPlanYet;

  /// No description provided for @planParseError.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse plan data'**
  String get planParseError;

  /// No description provided for @configured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get configured;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not Configured'**
  String get notConfigured;

  /// No description provided for @tapToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Tap refresh to load'**
  String get tapToRefresh;

  /// No description provided for @fieldPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get fieldPos;

  /// No description provided for @fieldLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get fieldLevel;

  /// No description provided for @fieldSyllableCount.
  ///
  /// In en, this message translates to:
  /// **'Syllables'**
  String get fieldSyllableCount;

  /// No description provided for @fieldMorphology.
  ///
  /// In en, this message translates to:
  /// **'Morphology'**
  String get fieldMorphology;

  /// No description provided for @fieldSyntax.
  ///
  /// In en, this message translates to:
  /// **'Syntax'**
  String get fieldSyntax;

  /// No description provided for @fieldCollocation.
  ///
  /// In en, this message translates to:
  /// **'Collocation'**
  String get fieldCollocation;

  /// No description provided for @fieldRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get fieldRegister;

  /// No description provided for @fieldEtymology.
  ///
  /// In en, this message translates to:
  /// **'Etymology'**
  String get fieldEtymology;

  /// No description provided for @fieldExampleSentence.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get fieldExampleSentence;

  /// No description provided for @statusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get statusPendingReview;

  /// No description provided for @statusAIFilled.
  ///
  /// In en, this message translates to:
  /// **'AI Filled'**
  String get statusAIFilled;

  /// No description provided for @tooltipPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Play pronunciation'**
  String get tooltipPlayAudio;

  /// No description provided for @tabWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get tabWords;

  /// No description provided for @tabGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get tabGrammar;

  /// No description provided for @headingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get headingLibrary;

  /// No description provided for @labelMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get labelMastered;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search words or meanings...'**
  String get searchHint;

  /// No description provided for @quizStart.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get quizStart;

  /// No description provided for @quizNext.
  ///
  /// In en, this message translates to:
  /// **'Next Question'**
  String get quizNext;

  /// No description provided for @quizSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get quizSkip;

  /// No description provided for @quizSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get quizSubmit;

  /// No description provided for @quizCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get quizCorrect;

  /// No description provided for @quizIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get quizIncorrect;

  /// No description provided for @quizExpired.
  ///
  /// In en, this message translates to:
  /// **'Question expired, please get a new one'**
  String get quizExpired;

  /// No description provided for @quizNewWords.
  ///
  /// In en, this message translates to:
  /// **'New Words'**
  String get quizNewWords;

  /// No description provided for @quizReviewWords.
  ///
  /// In en, this message translates to:
  /// **'Review Words'**
  String get quizReviewWords;

  /// No description provided for @quizNewGrammar.
  ///
  /// In en, this message translates to:
  /// **'New Grammar'**
  String get quizNewGrammar;

  /// No description provided for @quizReviewGrammar.
  ///
  /// In en, this message translates to:
  /// **'Review Grammar'**
  String get quizReviewGrammar;

  /// No description provided for @quizNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items to review'**
  String get quizNoItems;

  /// No description provided for @quizDailyTargetMet.
  ///
  /// In en, this message translates to:
  /// **'Daily target met'**
  String get quizDailyTargetMet;

  /// No description provided for @quizDismiss.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get quizDismiss;

  /// No description provided for @quizTypeChoice.
  ///
  /// In en, this message translates to:
  /// **'Choice'**
  String get quizTypeChoice;

  /// No description provided for @quizTypeFill.
  ///
  /// In en, this message translates to:
  /// **'Fill-in'**
  String get quizTypeFill;

  /// No description provided for @quizTypeSpelling.
  ///
  /// In en, this message translates to:
  /// **'Spelling'**
  String get quizTypeSpelling;

  /// No description provided for @quizTypePronounce.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get quizTypePronounce;

  /// No description provided for @quizTypeMeaning.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get quizTypeMeaning;

  /// No description provided for @quizTypeReadWord.
  ///
  /// In en, this message translates to:
  /// **'Read Aloud'**
  String get quizTypeReadWord;

  /// No description provided for @quizTypeReadSentence.
  ///
  /// In en, this message translates to:
  /// **'Read Sentence'**
  String get quizTypeReadSentence;

  /// No description provided for @quizTypeListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get quizTypeListening;

  /// No description provided for @quizTypeReadingComp.
  ///
  /// In en, this message translates to:
  /// **'Reading Comp'**
  String get quizTypeReadingComp;

  /// No description provided for @quizTypeGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get quizTypeGrammar;

  /// No description provided for @quizDontKnow.
  ///
  /// In en, this message translates to:
  /// **'I don\'t know, show me the answer'**
  String get quizDontKnow;

  /// No description provided for @recordingStart.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get recordingStart;

  /// No description provided for @recordingDone.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get recordingDone;

  /// No description provided for @recordingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recordingInProgress;

  /// No description provided for @recordingStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get recordingStop;

  /// No description provided for @recordingRetry.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get recordingRetry;

  /// No description provided for @recordingDontKnow.
  ///
  /// In en, this message translates to:
  /// **'I can\'t read this, show answer'**
  String get recordingDontKnow;

  /// No description provided for @quizTypeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Type your answer...'**
  String get quizTypeAnswer;

  /// No description provided for @aiPreparingContent.
  ///
  /// In en, this message translates to:
  /// **'AI is preparing learning content...'**
  String get aiPreparingContent;

  /// No description provided for @aiPreparingPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait, first-time generation may take 10-20s'**
  String get aiPreparingPleaseWait;

  /// No description provided for @aiAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'AI is analyzing your learning data...'**
  String get aiAnalyzing;

  /// No description provided for @viewAISummary.
  ///
  /// In en, this message translates to:
  /// **'View AI Summary'**
  String get viewAISummary;

  /// No description provided for @quizCompletedToday.
  ///
  /// In en, this message translates to:
  /// **'Daily learning complete!'**
  String get quizCompletedToday;

  /// No description provided for @quizAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy: {pct}%'**
  String quizAccuracy(Object pct);

  /// No description provided for @quizCorrectCount.
  ///
  /// In en, this message translates to:
  /// **'{correct}/{answered} correct'**
  String quizCorrectCount(Object correct, Object answered);

  /// No description provided for @quizQuestionProgress.
  ///
  /// In en, this message translates to:
  /// **'{answered}Q · {correct} ✓ · {pct}%'**
  String quizQuestionProgress(Object answered, Object correct, Object pct);

  /// No description provided for @quizTotalEstimate.
  ///
  /// In en, this message translates to:
  /// **'{total} questions · ~{minutes} min'**
  String quizTotalEstimate(Object total, Object minutes);

  /// No description provided for @quizBeginLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get quizBeginLearning;

  /// No description provided for @quizNoContentReturn.
  ///
  /// In en, this message translates to:
  /// **'No content, go back'**
  String get quizNoContentReturn;

  /// No description provided for @quizDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Study'**
  String get quizDailyTitle;

  /// No description provided for @quizSM2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'SM-2 smart review + AI curated content'**
  String get quizSM2Subtitle;

  /// No description provided for @quizLearnNewContent.
  ///
  /// In en, this message translates to:
  /// **'Learn New Content'**
  String get quizLearnNewContent;

  /// No description provided for @quizBeginWithCount.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz ({count} questions)'**
  String quizBeginWithCount(Object count);

  /// No description provided for @quizCongrats.
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get quizCongrats;

  /// No description provided for @quizKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep it up!'**
  String get quizKeepGoing;

  /// No description provided for @quizCompletedDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get quizCompletedDone;

  /// No description provided for @quizAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quizAppBarTitle;

  /// No description provided for @readAloudPass.
  ///
  /// In en, this message translates to:
  /// **'PASS'**
  String get readAloudPass;

  /// No description provided for @readAloudNeedWork.
  ///
  /// In en, this message translates to:
  /// **'NEED WORK'**
  String get readAloudNeedWork;

  /// No description provided for @readAloudScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Score {score}% (need ≥ {threshold}%)'**
  String readAloudScoreLabel(Object score, Object threshold);

  /// No description provided for @readAloudListenFirst.
  ///
  /// In en, this message translates to:
  /// **'Listen first, then answer'**
  String get readAloudListenFirst;

  /// No description provided for @fieldMeaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get fieldMeaning;

  /// No description provided for @cardPageOf.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String cardPageOf(Object current, Object total);

  /// No description provided for @labelLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get labelLanguage;

  /// No description provided for @labelCurrentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Current Language'**
  String get labelCurrentLanguage;

  /// No description provided for @labelAvailableLanguages.
  ///
  /// In en, this message translates to:
  /// **'Available Languages'**
  String get labelAvailableLanguages;

  /// No description provided for @labelBaseInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get labelBaseInfo;

  /// No description provided for @labelNativeName.
  ///
  /// In en, this message translates to:
  /// **'Native Name'**
  String get labelNativeName;

  /// No description provided for @labelTTS.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get labelTTS;

  /// No description provided for @labelProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get labelProvider;

  /// No description provided for @labelVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get labelVoice;

  /// No description provided for @labelDict.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get labelDict;

  /// No description provided for @labelPrompt.
  ///
  /// In en, this message translates to:
  /// **'AI Prompt'**
  String get labelPrompt;

  /// No description provided for @labelTeacherRole.
  ///
  /// In en, this message translates to:
  /// **'Teacher Role'**
  String get labelTeacherRole;

  /// No description provided for @labelExplanationLang.
  ///
  /// In en, this message translates to:
  /// **'Explanation Language'**
  String get labelExplanationLang;

  /// No description provided for @labelLevelDescriptions.
  ///
  /// In en, this message translates to:
  /// **'Level Descriptions'**
  String get labelLevelDescriptions;

  /// No description provided for @labelQuestionTypes.
  ///
  /// In en, this message translates to:
  /// **'Question Types'**
  String get labelQuestionTypes;

  /// No description provided for @labelEnabledTypes.
  ///
  /// In en, this message translates to:
  /// **'Enabled Types'**
  String get labelEnabledTypes;

  /// No description provided for @labelVoices.
  ///
  /// In en, this message translates to:
  /// **'voices'**
  String get labelVoices;

  /// No description provided for @labelWithLevel.
  ///
  /// In en, this message translates to:
  /// **'With Level'**
  String get labelWithLevel;

  /// No description provided for @labelNoLevel.
  ///
  /// In en, this message translates to:
  /// **'No Level'**
  String get labelNoLevel;

  /// No description provided for @tabGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get tabGeneral;

  /// No description provided for @labelEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get labelEnabled;

  /// No description provided for @labelMinIntervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Min Interval (min)'**
  String get labelMinIntervalMinutes;

  /// No description provided for @labelMaxIntervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Max Interval (min)'**
  String get labelMaxIntervalMinutes;

  /// No description provided for @labelCadenceDays.
  ///
  /// In en, this message translates to:
  /// **'Every N Days'**
  String get labelCadenceDays;

  /// No description provided for @labelCadenceCount.
  ///
  /// In en, this message translates to:
  /// **'Questions Per Batch'**
  String get labelCadenceCount;

  /// No description provided for @labelAIRecommend.
  ///
  /// In en, this message translates to:
  /// **'AI Recommend'**
  String get labelAIRecommend;

  /// No description provided for @labelModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get labelModel;

  /// No description provided for @labelAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get labelAddress;

  /// No description provided for @labelStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get labelStatus;

  /// No description provided for @hintRefreshTTS.
  ///
  /// In en, this message translates to:
  /// **'Tap refresh to load TTS config'**
  String get hintRefreshTTS;

  /// No description provided for @hintRefreshDict.
  ///
  /// In en, this message translates to:
  /// **'Tap refresh to load dictionary config'**
  String get hintRefreshDict;

  /// No description provided for @labelSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get labelSettings;

  /// No description provided for @labelRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get labelRetry;

  /// No description provided for @statusRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String statusRemaining(Object count);

  /// No description provided for @statusDailyComplete.
  ///
  /// In en, this message translates to:
  /// **'Daily task complete'**
  String get statusDailyComplete;

  /// No description provided for @statusWordsReady.
  ///
  /// In en, this message translates to:
  /// **'{count} words ready, start the quiz'**
  String statusWordsReady(Object count);

  /// No description provided for @onboardingInterface.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get onboardingInterface;

  /// No description provided for @onboardingInterfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface Language'**
  String get onboardingInterfaceLanguage;

  /// No description provided for @onboardingTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get onboardingTheme;

  /// No description provided for @onboardingLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get onboardingLight;

  /// No description provided for @onboardingDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get onboardingDark;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingAIConfig.
  ///
  /// In en, this message translates to:
  /// **'AI Setup'**
  String get onboardingAIConfig;

  /// No description provided for @onboardingAIDesc.
  ///
  /// In en, this message translates to:
  /// **'Used for AI-powered quizzes, personalized tutoring, and session summaries'**
  String get onboardingAIDesc;

  /// No description provided for @onboardingAIRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign up at platform.deepseek.com → API Keys'**
  String get onboardingAIRegister;

  /// No description provided for @onboardingNextAI.
  ///
  /// In en, this message translates to:
  /// **'Next → AI Guide'**
  String get onboardingNextAI;

  /// No description provided for @onboardingSkipAI.
  ///
  /// In en, this message translates to:
  /// **'Skip AI Setup'**
  String get onboardingSkipAI;

  /// No description provided for @onboardingSkipAIHint.
  ///
  /// In en, this message translates to:
  /// **'Local quiz mode will be used. You can configure AI later in Settings.'**
  String get onboardingSkipAIHint;

  /// No description provided for @onboardingAIAdvisor.
  ///
  /// In en, this message translates to:
  /// **'AI Learning Advisor'**
  String get onboardingAIAdvisor;

  /// No description provided for @onboardingGeneratePlan.
  ///
  /// In en, this message translates to:
  /// **'Generate Study Plan'**
  String get onboardingGeneratePlan;

  /// No description provided for @onboardingPlanDone.
  ///
  /// In en, this message translates to:
  /// **'Profile created, continue →'**
  String get onboardingPlanDone;

  /// No description provided for @onboardingSkipInterview.
  ///
  /// In en, this message translates to:
  /// **'Skip interview, go to setup'**
  String get onboardingSkipInterview;

  /// No description provided for @onboardingStudySetup.
  ///
  /// In en, this message translates to:
  /// **'Study Setup'**
  String get onboardingStudySetup;

  /// No description provided for @onboardingEscapePassword.
  ///
  /// In en, this message translates to:
  /// **'Escape Password'**
  String get onboardingEscapePassword;

  /// No description provided for @onboardingEscapePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Used for emergency unlock (please memorize)'**
  String get onboardingEscapePasswordHint;

  /// No description provided for @onboardingLanguageToStudy.
  ///
  /// In en, this message translates to:
  /// **'Language to study'**
  String get onboardingLanguageToStudy;

  /// No description provided for @onboardingDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily Study Time'**
  String get onboardingDailyTarget;

  /// No description provided for @onboardingAccuracyHint.
  ///
  /// In en, this message translates to:
  /// **'Accuracy >= 80% required to unlock'**
  String get onboardingAccuracyHint;

  /// No description provided for @onboardingMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get onboardingMinutes;

  /// No description provided for @onboardingQuestionsUnit.
  ///
  /// In en, this message translates to:
  /// **'questions'**
  String get onboardingQuestionsUnit;

  /// No description provided for @onboardingComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete Setup, Start Learning'**
  String get onboardingComplete;

  /// No description provided for @serverOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable — some features are limited'**
  String get serverOfflineBanner;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @completionCongrats.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! Daily goal achieved!'**
  String get completionCongrats;

  /// No description provided for @completionDone.
  ///
  /// In en, this message translates to:
  /// **'Daily task complete'**
  String get completionDone;

  /// No description provided for @statAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get statAnswered;

  /// No description provided for @statCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get statCorrect;

  /// No description provided for @statAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get statAccuracy;

  /// No description provided for @completionHint.
  ///
  /// In en, this message translates to:
  /// **'You can browse words, use the AI assistant, or view stats.'**
  String get completionHint;

  /// No description provided for @practiceAgain.
  ///
  /// In en, this message translates to:
  /// **'Practice again'**
  String get practiceAgain;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VocabLock'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Master vocabulary through spaced repetition,\nAI-powered quizzes, and immersive practice.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingFeature1.
  ///
  /// In en, this message translates to:
  /// **'7 question types with AI-powered generation'**
  String get onboardingFeature1;

  /// No description provided for @onboardingFeature2.
  ///
  /// In en, this message translates to:
  /// **'Listening, reading & grammar practice'**
  String get onboardingFeature2;

  /// No description provided for @onboardingFeature3.
  ///
  /// In en, this message translates to:
  /// **'Multi-language support with dynamic theming'**
  String get onboardingFeature3;

  /// No description provided for @onboardingFeature4.
  ///
  /// In en, this message translates to:
  /// **'Focus lock screen for distraction-free study'**
  String get onboardingFeature4;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingAiConfiguredEnv.
  ///
  /// In en, this message translates to:
  /// **'AI is configured via environment variable VOCABLOCK_AI_KEY'**
  String get onboardingAiConfiguredEnv;

  /// No description provided for @onboardingTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get onboardingTestConnection;

  /// No description provided for @onboardingTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Connected'**
  String get onboardingTestSuccess;

  /// No description provided for @onboardingTestNoResponse.
  ///
  /// In en, this message translates to:
  /// **'❌ No response'**
  String get onboardingTestNoResponse;

  /// No description provided for @onboardingTestConfigured.
  ///
  /// In en, this message translates to:
  /// **'✅ Configured'**
  String get onboardingTestConfigured;

  /// No description provided for @onboardingTestBadFormat.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Key format may be incorrect'**
  String get onboardingTestBadFormat;

  /// No description provided for @onboardingTestFailed.
  ///
  /// In en, this message translates to:
  /// **'❌ Connection failed — check API key or network'**
  String get onboardingTestFailed;

  /// No description provided for @onboardingInterviewRoundCount.
  ///
  /// In en, this message translates to:
  /// **'Rounds: {rounds}'**
  String onboardingInterviewRoundCount(Object rounds);

  /// No description provided for @onboardingInterviewDone.
  ///
  /// In en, this message translates to:
  /// **' · Profile created'**
  String get onboardingInterviewDone;

  /// No description provided for @onboardingInterviewReady.
  ///
  /// In en, this message translates to:
  /// **' · Ready to generate plan'**
  String get onboardingInterviewReady;

  /// No description provided for @onboardingInterviewMinHint.
  ///
  /// In en, this message translates to:
  /// **' (min {rounds} rounds)'**
  String onboardingInterviewMinHint(Object rounds);

  /// No description provided for @onboardingConnectingAI.
  ///
  /// In en, this message translates to:
  /// **'Connecting to AI...'**
  String get onboardingConnectingAI;

  /// No description provided for @onboardingAIThinking.
  ///
  /// In en, this message translates to:
  /// **'AI is thinking...'**
  String get onboardingAIThinking;

  /// No description provided for @onboardingChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type your answer...'**
  String get onboardingChatInputHint;

  /// No description provided for @onboardingAiFailed.
  ///
  /// In en, this message translates to:
  /// **'AI assistant connection failed, check your network and retry.'**
  String get onboardingAiFailed;

  /// No description provided for @onboardingAiTimeout.
  ///
  /// In en, this message translates to:
  /// **'AI response timed out — tap below to retry.'**
  String get onboardingAiTimeout;

  /// No description provided for @onboardingVoiceTts.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech (TTS)'**
  String get onboardingVoiceTts;

  /// No description provided for @onboardingDictCheck.
  ///
  /// In en, this message translates to:
  /// **'Dictionary check (Dict)'**
  String get onboardingDictCheck;

  /// No description provided for @onboardingConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get onboardingConnected;

  /// No description provided for @onboardingNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get onboardingNotConnected;

  /// No description provided for @onboardingNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get onboardingNotConfigured;

  /// No description provided for @progressToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Progress'**
  String get progressToday;

  /// No description provided for @progressWordsUnit.
  ///
  /// In en, this message translates to:
  /// **'words'**
  String get progressWordsUnit;

  /// No description provided for @labelRecentMistakes.
  ///
  /// In en, this message translates to:
  /// **'Recent Mistakes'**
  String get labelRecentMistakes;

  /// No description provided for @labelAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get labelAccuracy;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @homeworkEmpty.
  ///
  /// In en, this message translates to:
  /// **'No homework yet'**
  String get homeworkEmpty;

  /// No description provided for @homeworkEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Homework appears according to your cadence — it\'s not time yet.'**
  String get homeworkEmptyHint;

  /// No description provided for @homeworkRecommendedCadence.
  ///
  /// In en, this message translates to:
  /// **'Recommended cadence'**
  String get homeworkRecommendedCadence;

  /// No description provided for @homeworkAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'Write your answer here...'**
  String get homeworkAnswerHint;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get nextQuestion;

  /// No description provided for @typeSentence.
  ///
  /// In en, this message translates to:
  /// **'Sentence'**
  String get typeSentence;

  /// No description provided for @typeTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get typeTranslation;

  /// No description provided for @typeFillPassage.
  ///
  /// In en, this message translates to:
  /// **'Fill the passage'**
  String get typeFillPassage;

  /// No description provided for @typeEssay.
  ///
  /// In en, this message translates to:
  /// **'Short essay'**
  String get typeEssay;

  /// No description provided for @homeworkCadence.
  ///
  /// In en, this message translates to:
  /// **'AI recommends: {count} questions every {days} days'**
  String homeworkCadence(Object count, Object days);

  /// No description provided for @yourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get yourAnswer;

  /// No description provided for @aiPolish.
  ///
  /// In en, this message translates to:
  /// **'AI polish'**
  String get aiPolish;

  /// No description provided for @scoreBar.
  ///
  /// In en, this message translates to:
  /// **'Score {pct}%'**
  String scoreBar(Object pct);

  /// No description provided for @errorMarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Error marks:'**
  String get errorMarkLabel;

  /// No description provided for @aiSessionSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Session Summary'**
  String get aiSessionSummary;

  /// No description provided for @aiAnalyzingSession.
  ///
  /// In en, this message translates to:
  /// **'AI is analyzing your session and updating your study plan...'**
  String get aiAnalyzingSession;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// No description provided for @aiAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'AI analysis failed'**
  String get aiAnalysisFailed;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @sessionAnalysis.
  ///
  /// In en, this message translates to:
  /// **'This session\'s analysis'**
  String get sessionAnalysis;

  /// No description provided for @labelStrengths.
  ///
  /// In en, this message translates to:
  /// **'Strengths:'**
  String get labelStrengths;

  /// No description provided for @labelWeaknesses.
  ///
  /// In en, this message translates to:
  /// **'To improve:'**
  String get labelWeaknesses;

  /// No description provided for @labelSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Study suggestions'**
  String get labelSuggestions;

  /// No description provided for @labelUpdatedPlan.
  ///
  /// In en, this message translates to:
  /// **'Updated study plan'**
  String get labelUpdatedPlan;

  /// No description provided for @labelPlanDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get labelPlanDirection;

  /// No description provided for @labelPlanConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get labelPlanConfidence;

  /// No description provided for @audioGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get audioGenerating;

  /// No description provided for @audioPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing...'**
  String get audioPlaying;

  /// No description provided for @audioPlayed.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get audioPlayed;

  /// No description provided for @audioNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'TTS not configured (external binary required)'**
  String get audioNotConfigured;

  /// No description provided for @audioGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get audioGenerateFailed;

  /// No description provided for @audioPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed'**
  String get audioPlayFailed;

  /// No description provided for @audioUnavailable.
  ///
  /// In en, this message translates to:
  /// **'TTS unavailable'**
  String get audioUnavailable;

  /// No description provided for @audioPlayingWord.
  ///
  /// In en, this message translates to:
  /// **'Playing: {word}'**
  String audioPlayingWord(Object word);

  /// No description provided for @audioPlayedWord.
  ///
  /// In en, this message translates to:
  /// **'Played: {word}'**
  String audioPlayedWord(Object word);

  /// No description provided for @audioPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Type text to preview...'**
  String get audioPreviewHint;

  /// No description provided for @audioQuickPlay.
  ///
  /// In en, this message translates to:
  /// **'Quick play'**
  String get audioQuickPlay;

  /// No description provided for @audioNoWords.
  ///
  /// In en, this message translates to:
  /// **'No words yet'**
  String get audioNoWords;

  /// No description provided for @approveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve \"{word}\"'**
  String approveTitle(Object word);

  /// No description provided for @fieldReadingRequired.
  ///
  /// In en, this message translates to:
  /// **'Reading (required)'**
  String get fieldReadingRequired;

  /// No description provided for @fieldMeaningRequired.
  ///
  /// In en, this message translates to:
  /// **'Meaning (required)'**
  String get fieldMeaningRequired;

  /// No description provided for @fieldPosRequired.
  ///
  /// In en, this message translates to:
  /// **'Part of speech (required)'**
  String get fieldPosRequired;

  /// No description provided for @fieldLevelOptional.
  ///
  /// In en, this message translates to:
  /// **'Level (optional)'**
  String get fieldLevelOptional;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @approvedMsg.
  ///
  /// In en, this message translates to:
  /// **'\"{word}\" approved'**
  String approvedMsg(Object word);

  /// No description provided for @rejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject \"{word}\"'**
  String rejectTitle(Object word);

  /// No description provided for @rejectReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (feedback for AI)'**
  String get rejectReasonHint;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @rejectedMsg.
  ///
  /// In en, this message translates to:
  /// **'\"{word}\" returned to AI'**
  String rejectedMsg(Object word);

  /// No description provided for @editTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit tags: {word}'**
  String editTagsTitle(Object word);

  /// No description provided for @tagsHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, e.g. hard, confusing, exam focus'**
  String get tagsHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @opFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String opFailed(Object error);

  /// No description provided for @pendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingTitle;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String loadFailed(Object error);

  /// No description provided for @pendingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No words pending review'**
  String get pendingEmpty;

  /// No description provided for @pendingEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'AI-generated words validated by the dictionary are added automatically;\nwords that fail validation appear here for your review.'**
  String get pendingEmptyHint;

  /// No description provided for @pendingBadge.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingBadge;

  /// No description provided for @labelTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get labelTags;

  /// No description provided for @tagsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Tags updated'**
  String get tagsUpdated;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get statStreak;

  /// No description provided for @statOfTotal.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String statOfTotal(Object total);

  /// No description provided for @statActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get statActivity;

  /// No description provided for @aiChatTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChatTitle;

  /// No description provided for @aiChatEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your vocabulary!'**
  String get aiChatEmptyHint;

  /// No description provided for @aiChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get aiChatInputHint;

  /// No description provided for @expandStatusGenerating.
  ///
  /// In en, this message translates to:
  /// **'AI is generating new words...'**
  String get expandStatusGenerating;

  /// No description provided for @expandStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Generated {count} words for [{direction}] ({verified} added, {pending} pending review, {context} existing words considered)'**
  String expandStatusDone(Object direction, Object count, Object verified,
      Object pending, Object context);

  /// No description provided for @expandStatusDoneSimple.
  ///
  /// In en, this message translates to:
  /// **'Generated {count} words ({verified} added, {pending} pending review)'**
  String expandStatusDoneSimple(Object count, Object verified, Object pending);

  /// No description provided for @expandStatusNone.
  ///
  /// In en, this message translates to:
  /// **'No new words generated'**
  String get expandStatusNone;

  /// No description provided for @expandStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Word generation failed'**
  String get expandStatusFailed;

  /// No description provided for @expandStatusNoApi.
  ///
  /// In en, this message translates to:
  /// **'API not connected — cannot generate words'**
  String get expandStatusNoApi;

  /// No description provided for @quizGoalRemaining.
  ///
  /// In en, this message translates to:
  /// **'Today\'s goal: {count} more questions to unlock'**
  String quizGoalRemaining(Object count);

  /// No description provided for @quizReviewPool.
  ///
  /// In en, this message translates to:
  /// **'Due review pool'**
  String get quizReviewPool;

  /// No description provided for @quizReviewNote.
  ///
  /// In en, this message translates to:
  /// **'{count} items due — session ends automatically once the goal is met'**
  String quizReviewNote(Object count);

  /// No description provided for @quizEstimateGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal: {count} questions · ~{minutes} min'**
  String quizEstimateGoal(Object count, Object minutes);

  /// No description provided for @disputeGrade.
  ///
  /// In en, this message translates to:
  /// **'I think this was graded wrong'**
  String get disputeGrade;

  /// No description provided for @sessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to study right now'**
  String get sessionEmpty;

  /// No description provided for @sessionEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Import more words, or configure AI expansion. Words on long intervals will return on their due dates.'**
  String get sessionEmptyHint;

  /// No description provided for @sessionContinue.
  ///
  /// In en, this message translates to:
  /// **'Keep training'**
  String get sessionContinue;

  /// No description provided for @pendingAcceptAll.
  ///
  /// In en, this message translates to:
  /// **'Accept all'**
  String get pendingAcceptAll;

  /// No description provided for @pendingAcceptAllDone.
  ///
  /// In en, this message translates to:
  /// **'Activated {activated}, skipped {skipped} (missing meaning)'**
  String pendingAcceptAllDone(Object activated, Object skipped);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
