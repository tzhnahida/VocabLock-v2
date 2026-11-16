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
  String get sectionPassive => '被动答题';

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
  String get quizTypeDialogueWrite => '情境造句';

  @override
  String get quizTypeDialogueSpeak => '口头造句';

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
  String get dialogueSpeakInstruction => '用这个词说出完整回答';

  @override
  String get dialogueTranscript => '识别结果';

  @override
  String get dialogueReference => '参考答案';

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

  @override
  String get onboardingInterface => '界面设置';

  @override
  String get onboardingInterfaceLanguage => '界面语言';

  @override
  String get onboardingTheme => '界面颜色';

  @override
  String get onboardingLight => '浅色';

  @override
  String get onboardingDark => '深色';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingAIConfig => 'AI 配置';

  @override
  String get onboardingAIDesc => '用于 AI 智能出题、个性化辅导、学习总结';

  @override
  String get onboardingAIRegister => '注册地址: platform.deepseek.com → API Keys';

  @override
  String get onboardingNextAI => '下一步 → AI 引导';

  @override
  String get onboardingSkipAI => '跳过 AI 引导';

  @override
  String get onboardingSkipAIHint => '跳过后使用本地出题模式，可在设置中随时配置';

  @override
  String get onboardingAIAdvisor => 'AI 学习顾问';

  @override
  String get onboardingGeneratePlan => '生成培养方案';

  @override
  String get onboardingPlanDone => '学习档案已建立，继续 →';

  @override
  String get onboardingSkipInterview => '跳过 AI 引导，直接设置';

  @override
  String get onboardingStudySetup => '学习设置';

  @override
  String get onboardingEscapePassword => '紧急密码';

  @override
  String get onboardingEscapePasswordHint => '锁屏状态下紧急退出用（请务必记住）';

  @override
  String get onboardingLanguageToStudy => '学习语言';

  @override
  String get onboardingDailyTarget => '每日学习时间';

  @override
  String get onboardingAccuracyHint => '正确率 ≥ 80% 方可解锁';

  @override
  String get onboardingMinutes => '分钟';

  @override
  String get onboardingQuestionsUnit => '题';

  @override
  String get onboardingComplete => '完成设置，开始学习';

  @override
  String get serverOfflineBanner => '服务器连接断开 — 部分功能受限';

  @override
  String get retry => '重试';

  @override
  String get completionCongrats => '恭喜完成今日学习！';

  @override
  String get completionDone => '今日任务完成';

  @override
  String get statAnswered => '答题';

  @override
  String get statCorrect => '正确';

  @override
  String get statAccuracy => '正确率';

  @override
  String get completionHint => '你可以继续浏览单词、使用AI助手或查看统计。';

  @override
  String get practiceAgain => '再次练习';

  @override
  String get onboardingWelcomeTitle => '欢迎使用 VocabLock';

  @override
  String get onboardingWelcomeSubtitle => '通过间隔重复、AI 出题和沉浸式练习掌握词汇。';

  @override
  String get onboardingFeature1 => '7 种题型，AI 智能出题';

  @override
  String get onboardingFeature2 => '听力、阅读与语法练习';

  @override
  String get onboardingFeature3 => '多语言支持与动态主题';

  @override
  String get onboardingFeature4 => '专注锁屏，沉浸学习';

  @override
  String get onboardingGetStarted => '开始';

  @override
  String get onboardingAiConfiguredEnv => 'AI 已通过环境变量 VOCABLOCK_AI_KEY 配置';

  @override
  String get onboardingTestConnection => '测试连接';

  @override
  String get onboardingTestSuccess => '✅ 连接成功';

  @override
  String get onboardingTestNoResponse => '❌ 无响应';

  @override
  String get onboardingTestConfigured => '✅ 连接已配置';

  @override
  String get onboardingTestBadFormat => '⚠️ 格式可能不正确';

  @override
  String get onboardingTestFailed => '❌ 连接失败 — 请检查 API Key 或网络';

  @override
  String onboardingInterviewRoundCount(Object rounds) {
    return '已对话 $rounds 轮';
  }

  @override
  String get onboardingInterviewDone => ' · 档案已建立';

  @override
  String get onboardingInterviewReady => ' · 可生成方案';

  @override
  String onboardingInterviewMinHint(Object rounds) {
    return '（最少 $rounds 轮后可生成）';
  }

  @override
  String get onboardingConnectingAI => '正在连接 AI...';

  @override
  String get onboardingAIThinking => 'AI 思考中...';

  @override
  String get onboardingChatInputHint => '输入你的回答...';

  @override
  String get onboardingAiFailed => 'AI 助手连接失败，请检查网络后重试。';

  @override
  String get onboardingAiTimeout => 'AI 响应超时，请点击下方按钮重试。';

  @override
  String get onboardingVoiceTts => '语音合成 (TTS)';

  @override
  String get onboardingDictCheck => '词典校验 (Dict)';

  @override
  String get onboardingConnected => '已连接';

  @override
  String get onboardingNotConnected => '未连接';

  @override
  String get onboardingNotConfigured => '未配置';

  @override
  String get progressToday => '今日进度';

  @override
  String get progressWordsUnit => '个词';

  @override
  String get labelRecentMistakes => '近期错题';

  @override
  String get labelAccuracy => '正确率';

  @override
  String get close => '关闭';

  @override
  String get done => '完成';

  @override
  String get homeworkEmpty => '暂无课后作业';

  @override
  String get homeworkEmptyHint => '作业按你设定的节奏出现，现在还没有到时间。';

  @override
  String get homeworkRecommendedCadence => 'AI 推荐节奏';

  @override
  String get homeworkAnswerHint => '在这里写下你的答案...';

  @override
  String get nextQuestion => '下一题';

  @override
  String get typeSentence => '造句';

  @override
  String get typeTranslation => '翻译';

  @override
  String get typeFillPassage => '填空短文';

  @override
  String get typeEssay => '短文写作';

  @override
  String homeworkCadence(Object count, Object days) {
    return 'AI 推荐: 每$days天$count题';
  }

  @override
  String get yourAnswer => '你的答案';

  @override
  String get aiPolish => 'AI 润色';

  @override
  String scoreBar(Object pct) {
    return '得分 $pct%';
  }

  @override
  String get errorMarkLabel => '错误标记:';

  @override
  String get aiSessionSummary => 'AI 学习总结';

  @override
  String get aiAnalyzingSession => 'AI 正在分析你本次的学习表现并更新培养方案...';

  @override
  String get analyzing => '正在分析...';

  @override
  String get aiAnalysisFailed => 'AI 分析失败';

  @override
  String get gotIt => '知道了';

  @override
  String get sessionAnalysis => '本次学习分析';

  @override
  String get labelStrengths => '优势:';

  @override
  String get labelWeaknesses => '待改进:';

  @override
  String get labelSuggestions => '学习建议';

  @override
  String get labelUpdatedPlan => '更新后的培养方案';

  @override
  String get labelPlanDirection => '学习方向';

  @override
  String get labelPlanConfidence => '方向置信度';

  @override
  String get audioGenerating => '生成中...';

  @override
  String get audioPlaying => '播放中...';

  @override
  String get audioPlayed => '播放完毕';

  @override
  String get audioNotConfigured => 'TTS 未配置（需要外部二进制）';

  @override
  String get audioGenerateFailed => '生成失败';

  @override
  String get audioPlayFailed => 'TTS 播放失败';

  @override
  String get audioUnavailable => 'TTS 不可用';

  @override
  String audioPlayingWord(Object word) {
    return '播放: $word';
  }

  @override
  String audioPlayedWord(Object word) {
    return '已播放: $word';
  }

  @override
  String get audioPreviewHint => '输入文本试听...';

  @override
  String get audioQuickPlay => '快速播放';

  @override
  String get audioNoWords => '暂无单词';

  @override
  String approveTitle(Object word) {
    return '审核 \"$word\"';
  }

  @override
  String get fieldReadingRequired => '读法（必填）';

  @override
  String get fieldMeaningRequired => '释义（必填）';

  @override
  String get fieldPosRequired => '词性（必填）';

  @override
  String get fieldLevelOptional => '等级（可选）';

  @override
  String get cancel => '取消';

  @override
  String get approve => '通过';

  @override
  String approvedMsg(Object word) {
    return '\"$word\" 已通过校验';
  }

  @override
  String rejectTitle(Object word) {
    return '拒绝 \"$word\"';
  }

  @override
  String get rejectReasonHint => '拒绝原因（反馈给AI）';

  @override
  String get reject => '拒绝';

  @override
  String rejectedMsg(Object word) {
    return '\"$word\" 已打回AI';
  }

  @override
  String editTagsTitle(Object word) {
    return '编辑标签: $word';
  }

  @override
  String get tagsHint => '用逗号分隔，如: 难记, 易混淆, 考试重点';

  @override
  String get save => '保存';

  @override
  String opFailed(Object error) {
    return '操作失败: $error';
  }

  @override
  String get pendingTitle => '待审核词汇';

  @override
  String loadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String get pendingEmpty => '没有待审核词汇';

  @override
  String get pendingEmptyHint => 'AI 生成的词汇通过词典校验后会自动入库，\n未通过校验的会出现在这里供你审核。';

  @override
  String get pendingBadge => '待审核';

  @override
  String get labelTags => '标签';

  @override
  String get tagsUpdated => '标签已更新';

  @override
  String get submit => '提交';

  @override
  String get exit => '退出';

  @override
  String get statsTitle => '统计';

  @override
  String get statStreak => '连续学习';

  @override
  String statOfTotal(Object total) {
    return '共 $total 题';
  }

  @override
  String get statActivity => '活跃度';

  @override
  String get aiChatTitle => 'AI 助手';

  @override
  String get aiChatEmptyHint =>
      '关于你的词汇,随便问我!Ask me anything about your vocabulary!';

  @override
  String get aiChatInputHint => '输入消息...';

  @override
  String get expandStatusGenerating => 'AI 正在生成新词...';

  @override
  String expandStatusDone(Object direction, Object count, Object verified,
      Object pending, Object context) {
    return '已为【$direction】生成 $count 个词(入库 $verified,待审核 $pending,参考 $context 个旧词)';
  }

  @override
  String expandStatusDoneSimple(Object count, Object verified, Object pending) {
    return '已生成 $count 个词(入库 $verified,待审核 $pending)';
  }

  @override
  String get expandStatusNone => '没有生成新词';

  @override
  String get expandStatusFailed => '词汇生成失败';

  @override
  String get expandStatusNoApi => 'API 未连接,无法生成词汇';

  @override
  String quizGoalRemaining(Object count) {
    return '今日目标:再完成 $count 题解锁';
  }

  @override
  String get quizReviewPool => '到期复习池';

  @override
  String quizReviewNote(Object count) {
    return '$count 项到期 —— 达成目标后会话自动结束';
  }

  @override
  String quizEstimateGoal(Object count, Object minutes) {
    return '目标:$count 题 · 约 $minutes 分钟';
  }

  @override
  String get disputeGrade => '我觉得判错了';

  @override
  String get sessionEmpty => '当前没有可学习的内容';

  @override
  String get sessionEmptyHint => '请导入更多词汇,或配置 AI 自动扩词。长间隔的单词会在到期时自动出现。';

  @override
  String get sessionContinue => '继续训练';

  @override
  String get pendingAcceptAll => '全部验收';

  @override
  String pendingAcceptAllDone(Object activated, Object skipped) {
    return '已入库 $activated 个,跳过 $skipped 个(缺少释义)';
  }

  @override
  String get sidebarDiagnostics => '诊断';

  @override
  String get sidebarPassive => '被动';

  @override
  String get diagnosticsTitle => '学习诊断';

  @override
  String diagnosticsWindowShort(Object count) {
    return '$count 天';
  }

  @override
  String diagnosticsWindow(Object days) {
    return '近 $days 天';
  }

  @override
  String get diagnosticsCoverage => '词汇覆盖';

  @override
  String get diagnosticsWords => '词条';

  @override
  String get diagnosticsLongTerm => '长期掌握';

  @override
  String get diagnosticsPending => '待审核';

  @override
  String get diagnosticsErrors => '错因分布';

  @override
  String get diagnosticsNoErrors => '这段时间没有答错记录。';

  @override
  String get diagnosticsWeakPhonemes => '弱音素';

  @override
  String get diagnosticsNoPhonemes => '还没有跟读的音素数据 —— 做过发音题后才会出现。';

  @override
  String diagnosticsPhonemesMeasured(Object count) {
    return '基于 $count 条跟读记录';
  }

  @override
  String get diagnosticsAIDisagreement => 'AI 判定分歧';

  @override
  String get diagnosticsNoAIVerdicts => '这段时间没有 AI 判定。';

  @override
  String get diagnosticsAIVerdicts => 'AI 判定次数';

  @override
  String get diagnosticsAIFalseNegatives => '疑似误判';

  @override
  String get diagnosticsAISamples => '样例(你的答案 | 期望答案)';

  @override
  String get diagnosticsTypeAccuracy => '各题型准确率';

  @override
  String get diagnosticsNoTypes => '这段时间没有作答记录。';

  @override
  String get diagnosticsEmpty => '还没有可诊断的数据';

  @override
  String get diagnosticsEmptyHint => '完成几次练习后,这里就会有内容。';

  @override
  String get errorCategorySimilarity => '形近 / 音近';

  @override
  String get errorCategoryEmpty => '空答';

  @override
  String get errorCategoryOther => '其他';

  @override
  String get errorCategoryUnlabeled => '未归类';

  @override
  String get passiveTitle => '被动答题';

  @override
  String get passiveHint => '先自己回忆释义,想好再翻面。';

  @override
  String get passiveReveal => '显示释义';

  @override
  String get passiveRemember => '记得';

  @override
  String get passiveHard => '有点难';

  @override
  String get passiveForgot => '忘了';

  @override
  String get passiveEmpty => '当前没有到期的词';

  @override
  String get passiveEmptyHint => '单词到期后会出现在这里。';

  @override
  String passiveAnswered(Object count) {
    return '本轮已评 $count 个';
  }

  @override
  String get passiveSubmitRejected => '服务器没有接受这次评分。';

  @override
  String homeworkNextDue(Object when) {
    return '下次作业:$when';
  }

  @override
  String get homeworkAIRequired => '作业需要 AI —— 请先在设置里配置。';

  @override
  String get homeworkGenerationFailed => 'AI 生成作业失败,稍后再试。';

  @override
  String homeworkSubmitFailed(Object error) {
    return '提交失败:$error';
  }
}
