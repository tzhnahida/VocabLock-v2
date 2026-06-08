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
