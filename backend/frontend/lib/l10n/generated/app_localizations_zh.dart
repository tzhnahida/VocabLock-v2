// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'VocabLock';

  @override
  String get sidebarQuiz => '学习';

  @override
  String get sidebarWords => '单词库';

  @override
  String get sidebarAudio => '音频';

  @override
  String get sidebarStats => '统计';

  @override
  String get sidebarConfig => '设置';

  @override
  String get sidebarAI => 'AI';

  @override
  String get sidebarReview => '审核';

  @override
  String get sidebarHomework => '作业';

  @override
  String get sectionLearning => '学习';

  @override
  String get sectionAIPlan => 'AI 学习方案';

  @override
  String get sectionPassive => '被动答题 (即将推出)';

  @override
  String get sectionExpand => 'AI 扩词';

  @override
  String get sectionAssignment => '课后作业';

  @override
  String get sectionAIModel => 'AI 模型';

  @override
  String get sectionTTS => 'TTS 提供者';

  @override
  String get sectionDict => '词典提供者';

  @override
  String get sectionSystem => '系统';

  @override
  String get dailyTarget => '每日目标';

  @override
  String get minAccuracy => '最低正确率';

  @override
  String get sessionTimeBudget => '学习时长(分钟, 0=不限)';

  @override
  String get maxSlowTypeRatio => '慢速题型上限';

  @override
  String get autoExpand => '自动扩词';

  @override
  String get expandBatchSize => '每批扩词数';

  @override
  String get sm2MaxInterval => 'SM-2 最大间隔(天)';

  @override
  String get autoStart => '开机自启 (即将推出)';

  @override
  String get difficulty => '难度';

  @override
  String get suggestedWordCount => '建议扩词数';

  @override
  String get typeRatio => '题型配比';

  @override
  String get grammarFocus => '语法重点';

  @override
  String get noPlanYet => '完成一次学习后 AI 将生成方案';

  @override
  String get planParseError => '计划数据解析失败';

  @override
  String get configured => '已配置';

  @override
  String get notConfigured => '未配置';

  @override
  String get tapToRefresh => '点击刷新加载';

  @override
  String get fieldPos => '词性';

  @override
  String get fieldLevel => '等级';

  @override
  String get fieldSyllableCount => '音拍数';

  @override
  String get fieldMorphology => '形态变化';

  @override
  String get fieldSyntax => '句法功能';

  @override
  String get fieldCollocation => '常用搭配';

  @override
  String get fieldRegister => '语体/语域';

  @override
  String get fieldEtymology => '词源/构词';

  @override
  String get fieldExampleSentence => '例句';

  @override
  String get statusPendingReview => '待审核';

  @override
  String get statusAIFilled => 'AI填充';

  @override
  String get tooltipPlayAudio => '播放发音';

  @override
  String get tabWords => '单词';

  @override
  String get tabGrammar => '语法';

  @override
  String get headingLibrary => '词库';

  @override
  String get labelMastered => '已掌握';

  @override
  String get searchHint => '搜索单词或释义...';

  @override
  String get quizStart => '开始学习';

  @override
  String get quizNext => '下一题';

  @override
  String get quizSkip => '跳过';

  @override
  String get quizSubmit => '提交';

  @override
  String get quizCorrect => '正确！';

  @override
  String get quizIncorrect => '错误';

  @override
  String get quizExpired => '题目已过期，请获取新题目';

  @override
  String get quizNewWords => '新单词';

  @override
  String get quizReviewWords => '复习单词';

  @override
  String get quizNewGrammar => '新语法';

  @override
  String get quizReviewGrammar => '复习语法';

  @override
  String get quizNoItems => '没有可复习的内容';

  @override
  String get quizDailyTargetMet => '每日目标已达成';

  @override
  String get quizDismiss => '返回';

  @override
  String get quizTypeChoice => '选择题';

  @override
  String get quizTypeFill => '填空题';

  @override
  String get quizTypeSpelling => '拼写题';

  @override
  String get quizTypePronounce => '读音题';

  @override
  String get quizTypeMeaning => '翻译题';

  @override
  String get quizTypeReadWord => '朗读题';

  @override
  String get quizTypeReadSentence => '朗读句子';

  @override
  String get quizTypeListening => '听力题';

  @override
  String get quizTypeReadingComp => '阅读理解';

  @override
  String get quizTypeGrammar => '语法题';

  @override
  String get quizDontKnow => '我不知道，告诉我答案';

  @override
  String get recordingStart => '开始录音';

  @override
  String get recordingDone => '已录制';

  @override
  String get recordingInProgress => '正在录音...';

  @override
  String get recordingStop => '停止录音';

  @override
  String get recordingRetry => '重录';

  @override
  String get recordingDontKnow => '不会念，告诉我答案';

  @override
  String get quizTypeAnswer => '输入你的答案...';

  @override
  String get aiPreparingContent => 'AI 正在准备学习内容...';

  @override
  String get aiPreparingPleaseWait => '请稍候，首次生成可能需要 10-20 秒';

  @override
  String get aiAnalyzing => 'AI 正在分析你的学习数据...';

  @override
  String get viewAISummary => '查看 AI 学习总结';

  @override
  String get quizCompletedToday => '今日学习完成！';

  @override
  String quizAccuracy(Object pct) {
    return '正确率: $pct%';
  }

  @override
  String quizCorrectCount(Object correct, Object answered) {
    return '正确 $correct / $answered 题';
  }

  @override
  String quizQuestionProgress(Object answered, Object correct, Object pct) {
    return '$answered 题 · $correct ✓ · $pct%';
  }

  @override
  String quizTotalEstimate(Object total, Object minutes) {
    return '共 $total 题 · 预估 $minutes 分钟';
  }

  @override
  String get quizBeginLearning => '开始学习';

  @override
  String get quizNoContentReturn => '暂无内容，返回';

  @override
  String get quizDailyTitle => '今日学习';

  @override
  String get quizSM2Subtitle => 'SM-2 智能复习 + AI 策展新内容';

  @override
  String get quizLearnNewContent => '学习新内容';

  @override
  String quizBeginWithCount(Object count) {
    return '开始答题 ($count 题)';
  }

  @override
  String get quizCongrats => '恭喜完成今日学习！';

  @override
  String get quizKeepGoing => '继续加油！';

  @override
  String get quizCompletedDone => '完成';

  @override
  String get quizAppBarTitle => '学习';

  @override
  String get readAloudPass => '通过';

  @override
  String get readAloudNeedWork => '需改进';

  @override
  String readAloudScoreLabel(Object score, Object threshold) {
    return '总分 $score% (需 ≥ $threshold%)';
  }

  @override
  String get readAloudListenFirst => '先听读，再作答';

  @override
  String get fieldMeaning => '释义';

  @override
  String cardPageOf(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get labelLanguage => '语言';

  @override
  String get labelCurrentLanguage => '当前语言';

  @override
  String get labelAvailableLanguages => '可用语言';

  @override
  String get labelBaseInfo => '基本信息';

  @override
  String get labelNativeName => '本地名称';

  @override
  String get labelTTS => 'TTS';

  @override
  String get labelProvider => '提供者';

  @override
  String get labelVoice => '声音';

  @override
  String get labelDict => '词典';

  @override
  String get labelPrompt => 'AI Prompt';

  @override
  String get labelTeacherRole => '老师角色';

  @override
  String get labelExplanationLang => '解释语言';

  @override
  String get labelLevelDescriptions => '等级描述';

  @override
  String get labelQuestionTypes => '题型';

  @override
  String get labelEnabledTypes => '启用的题型';

  @override
  String get labelVoices => '声音';

  @override
  String get labelWithLevel => '带等级';

  @override
  String get labelNoLevel => '无等级';

  @override
  String get tabGeneral => '通用';

  @override
  String get labelEnabled => '启用';

  @override
  String get labelMinIntervalMinutes => '最小间隔(分钟)';

  @override
  String get labelMaxIntervalMinutes => '最大间隔(分钟)';

  @override
  String get labelCadenceDays => '每几天一次';

  @override
  String get labelCadenceCount => '每次几题';

  @override
  String get labelAIRecommend => 'AI 推荐';

  @override
  String get labelModel => '模型';

  @override
  String get labelAddress => '地址';

  @override
  String get labelStatus => '状态';

  @override
  String get hintRefreshTTS => '点击刷新加载 TTS 配置';

  @override
  String get hintRefreshDict => '点击刷新加载词典配置';

  @override
  String get labelSettings => '设置';

  @override
  String get labelRetry => '重试';

  @override
  String statusRemaining(Object count) {
    return '剩余 $count 题';
  }

  @override
  String get statusDailyComplete => '今日任务完成';

  @override
  String statusWordsReady(Object count) {
    return '$count 个词汇已就绪，可以开始答题';
  }
}
