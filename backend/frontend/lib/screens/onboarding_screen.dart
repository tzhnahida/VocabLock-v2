import '../utils/app_log.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function({
    required String uiLang,
    required ThemeMode themeMode,
    required String learnLang,
    required int dailyTarget,
    required int dailyTimeTarget,
    String? apiKey,
    String? model,
    String? baseUrl,
    String? profileText,
    String? direction,
    String? password,
  }) onComplete;
  final Future<String> Function(String message, List<({String role, String content})> history)? onAiChat;
  final Future<Map<String, dynamic>> Function(String code)? onGetLangConfig;
  final bool aiConfigured;

  const OnboardingScreen({super.key, required this.onComplete, this.onAiChat, this.aiConfigured = false, this.onGetLangConfig});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  static const _totalSteps = 5;

  // Step 2: Interface
  String _uiLang = 'en';
  ThemeMode _themeMode = ThemeMode.light;

  // Step 3: AI Config
  String _apiKey = '';
  String _model = 'deepseek-v4-pro';
  String _baseUrl = 'https://api.deepseek.com';
  bool _testing = false;
  String _testResult = '';

  // Step 4: AI Interview
  final List<({String role, String content})> _chatMsgs = [];
  bool _chatLoading = false;
  bool _profileDone = false;
  int _roundCount = 0;
  static const _minRounds = 3;
  final _chatCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Step 5: Learning
  String _learnLang = 'zh';
  Map<String, dynamic>? _langConfig;
  double _studyMinutes = 20.0; // minutes per day → ~10 questions at 2 min/q
  String _password = '';
  String _profileText = '';
  String _profileDirection = '';

  static const _uiLanguages = [
    ('zh-CN', '中文'), ('en', 'English'), ('ja', '日本語'), ('ko', '한국어'),
  ];

  static const _learnLanguages = [
    ('zh', '中文', 'Chinese'), ('en', 'English', 'English'),
    ('ja', '日本語', 'Japanese'), ('ko', '한국어', 'Korean'),
  ];

  @override
  void initState() {
    super.initState();
    _modelCtrl.text = _model;
    _baseUrlCtrl.text = _baseUrl;
    _fetchLangConfig(_learnLang);
  }

  Future<void> _fetchLangConfig(String code) async {
    if (widget.onGetLangConfig == null) return;
    try {
      final cfg = await widget.onGetLangConfig!(code);
      if (mounted) setState(() => _langConfig = cfg);
    } catch (_) {}
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _modelCtrl.dispose();
    _baseUrlCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 2 && _apiKey.isEmpty && !widget.aiConfigured) {
      // Skip AI interview if no API key and not pre-configured
      setState(() => _step = 4);
      return;
    }
    if (_step == 3) {
      _startInterview();
      return;
    }
    if (_step < _totalSteps - 1) {
      final next = _step + 1;
      setState(() => _step = next);
      if (next == 3) _startInterview();
    } else {
      widget.onComplete(
        uiLang: _uiLang,
        themeMode: _themeMode,
        learnLang: _learnLang,
        dailyTarget: (_studyMinutes / 2).round().clamp(3, 60), dailyTimeTarget: _studyMinutes.round(),
        apiKey: _apiKey.isNotEmpty ? _apiKey : null,
        model: _model.isNotEmpty ? _model : null,
        baseUrl: _baseUrl.isNotEmpty ? _baseUrl : null,
        profileText: _profileText.isNotEmpty ? _profileText : null,
        direction: _profileDirection.isNotEmpty ? _profileDirection : null,
      );
    }
  }

  void _setTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    AppTheme.setThemeMode(mode);
    Provider.of<AppState>(context, listen: false).themeMode = mode;
  }

  // Returns '' when not configured; the caller renders the localized
  // "not configured" label (the old hardcoded '未配置' broke non-zh UI).
  String _voiceForLang(dynamic lc) {
    if (lc == null || lc is! Map) return '';
    final provider = (lc['tts_provider'] ?? '').toString();
    final voice = (lc['tts_voice'] ?? '').toString();
    if (provider.isEmpty || voice.isEmpty) return '';
    return '$voice ($provider)';
  }

  String _dictForLang(dynamic lc) {
    if (lc == null || lc is! Map) return '';
    final provider = (lc['dict_provider'] ?? '').toString();
    if (provider.isEmpty) return '';
    return provider;
  }

  Future<void> _testConnection() async {
    if (_apiKey.isEmpty) return;
    setState(() { _testing = true; _testResult = ''; });
    final l10n = AppLocalizations.of(context)!;
    try {
      // Actually test the AI connection with a simple ping message
      final chat = widget.onAiChat;
      if (chat != null) {
        final reply = await chat('ping', []);
        if (mounted) {
          setState(() {
            _testing = false;
            _testResult = reply.isNotEmpty ? l10n.onboardingTestSuccess : l10n.onboardingTestNoResponse;
          });
        }
      } else {
        // No chat callback — check API key format as fallback
        if (mounted) {
          setState(() {
            _testing = false;
            _testResult = _apiKey.startsWith('sk-') ? l10n.onboardingTestConfigured : l10n.onboardingTestBadFormat;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = l10n.onboardingTestFailed;
        });
      }
    }
  }

  void _startInterview() {
    setState(() => _step = 3);
    if (_apiKey.isEmpty && !widget.aiConfigured) return;
    _chatMsgs.clear();
    _roundCount = 0;
    _profileDone = false;
    final ifLang = _uiLang == "zh" ? "中文" : _uiLang == "ja" ? "日本語" : _uiLang == "ko" ? "한국어" : "English";
    final ctx = '（你是AI语言学习顾问。用户界面是$ifLang。'
        '请依次了解：1)想学什么语言 2)当前水平(零基础/初级/中级/高级) '
        '3)每天能学多久(分钟) 4)学习目标(日常交流/考试/工作/兴趣) '
        '5)偏好学习方式(视觉/听觉/动手)。每次只问1-2个问题，自然对话，不要直接生成方案。）';
    _sendInterviewMsg('$ctx 你好！我来帮你制定学习计划。请先告诉我你想学什么语言？', showUser: false);
  }

  Future<void> _sendInterviewMsg(String text, {bool showUser = true}) async {
    if (showUser) {
      setState(() => _chatMsgs.add((role: 'user', content: text)));
    }
    setState(() => _chatLoading = true);
    _roundCount++;

    String reply;
    if (widget.onAiChat != null) {
      try {
        reply = await widget.onAiChat!(text, _chatMsgs);
      } catch (_) {
        reply = AppLocalizations.of(context)!.onboardingAiFailed;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
      reply = switch (_roundCount) {
        1 => '你好！很高兴成为你的学习顾问。请告诉我：\n1. 你想学什么语言？\n2. 你目前的水平如何？（零基础/初级/中级/高级）',
        2 => '明白了！请再告诉我：\n1. 你每天能拿出多少时间学习？（分钟）\n2. 你的学习目标是什么？（日常交流/考试/工作/兴趣）',
        3 => '好的！最后一个问题：你偏好哪种学习方式？\n1. 视觉型（看单词卡片）\n2. 听觉型（多听发音）\n3. 动手型（多写多练）\n\n还是说都可以？',
        _ => '了解了！还有没有其他要补充的？比如：有没有考试截止日期、特别想突破的弱项？',
      };
    }

    if (!mounted) return;
    setState(() {
      _chatMsgs.add((role: 'assistant', content: reply));
      _chatLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _doRequestProfile() async {
    setState(() => _chatLoading = true);
    final prompt = '请根据以上对话，生成一份详细的学习培养方案，必须包含以下所有字段：\n'
        '- 学习语言与等级\n- 当前水平评估\n- 每日可投入时间（基于用户回答的具体分钟数）\n'
        '- 每日建议题数（根据可用时间推算，约每题2分钟）\n- 目标正确率（建议80%）\n'
        '- 学习时间安排（具体到时间段）\n- 重点学习方向\n- 难度递进计划\n\n结尾标注：✅ 学习档案已建立';

    String? reply;
    bool failed = false;
    if (widget.onAiChat != null) {
      try {
        reply = await widget.onAiChat!(prompt, _chatMsgs);
      } catch (_) {
        failed = true;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
      reply = _buildMockProfile();
    }

    if (!mounted) return;
    if (failed || reply == null) {
      setState(() {
        _chatMsgs.add((role: 'assistant', content: AppLocalizations.of(context)!.onboardingAiTimeout));
        _chatLoading = false;
      });
      return;
    }
    final text = reply; // promote to non-null
    _profileText = text;
    _applyProfile(text);
    setState(() {
      _chatMsgs.add((role: 'assistant', content: text));
      _chatLoading = false;
      _profileDone = true;
    });
    _scrollToBottom();
  }

  void _applyProfile(String reply) {
    // Detect language from AI response
    final langPatterns = [
      ('日本語', 'ja'), ('日语', 'ja'), ('日文', 'ja'),
      ('中文', 'zh'), ('汉语', 'zh'),
      ('English', 'en'), ('英语', 'en'), ('英文', 'en'),
      ('한국어', 'ko'), ('韩语', 'ko'), ('韩文', 'ko'), ('Korean', 'ko'),
    ];
    for (final (pattern, code) in langPatterns) {
      if (reply.contains(pattern)) { _learnLang = code; break; }
    }
    // Detect direction keywords
    final directions = ['conversation', 'reading', 'writing', 'listening', 'grammar', 'exam', 'business', 'travel'];
    for (final d in directions) {
      if (reply.toLowerCase().contains(d)) { _profileDirection = d; break; }
    }
    if (_profileDirection.isEmpty) _profileDirection = 'general';

    // Detect daily study time (minutes) or question count from AI reply
    // Prefer minutes first, then fall back to question count → minutes (2 min/q)
    final minRe = RegExp(r'(\d+)\s*分钟');
    final mM = minRe.firstMatch(reply);
    if (mM != null) {
      final t = double.tryParse(mM.group(1) ?? '');
      if (t != null && t >= 5 && t <= 120) { _studyMinutes = t; }
    } else {
      final targets = [
        RegExp(r'每日.*?(\d+)\s*题'), RegExp(r'建议.*?(\d+)\s*题'),
        RegExp(r'(\d+)\s*题.*?每日'), RegExp(r'每天.*?(\d+)\s*题'),
      ];
      for (final re in targets) {
        final m2 = re.firstMatch(reply);
        if (m2 != null) {
          final q = int.tryParse(m2.group(1) ?? '');
          if (q != null && q >= 5 && q <= 100) { _studyMinutes = q * 2.0; break; }
        }
      }
    }
  }

  String _buildMockProfile() {
    final langNames = {'zh': '中文', 'en': '英语', 'ja': '日语', 'ko': '韩语'};
    final lang = langNames[_learnLang] ?? _learnLang;
    final target = _learnLang == 'ja' || _learnLang == 'zh' || _learnLang == 'ko' ? 15 : 10;
    return '好的！根据你的情况，我为你制定了学习方案：\n\n'
        '📚 学习语言: $lang\n'
        '🎯 每日题数建议: $target 题\n'
        '📊 目标正确率: 80%\n'
        '⏱ 预计每日耗时: ${target * 2} 分钟\n'
        '📖 学习重点: 核心词汇 + 基础语法\n'
        '🔤 难度梯度: 选择 → 填空 → 拼写\n\n'
        '后续出题会基于此档案动态调整。\n\n✅ 学习档案已建立';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              width: 520,
              margin: const EdgeInsets.symmetric(vertical: 24),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                boxShadow: AppTheme.cardShadow,
              ),
              child: switch (_step) {
                0 => _buildWelcome(),
                1 => _buildInterface(),
                2 => _buildAIConfig(),
                3 => _buildInterview(),
                _ => _buildLearnSetup(),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ——— Step 0: Welcome ———
  Widget _buildWelcome({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(key: key, mainAxisSize: MainAxisSize.min, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: AppTheme.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ), child: const Icon(Icons.auto_stories, color: Colors.white, size: 40)),
      const SizedBox(height: 28),
      Text(l10n.onboardingWelcomeTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      const SizedBox(height: 12),
      Text(l10n.onboardingWelcomeSubtitle,
          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6)),
      const SizedBox(height: 32),
      _Features(),
      const SizedBox(height: 28),
      _Btn(label: l10n.onboardingGetStarted, onTap: _next),
    ]);
  }

  // ——— Step 1: Interface (UI lang + Theme) ———
  Widget _buildInterface({Key? key}) {
    return Consumer<AppState>(builder: (context, __, _) {
    final l10n = AppLocalizations.of(context)!;
    return Column(key: key, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Header(step: 1, title: l10n.onboardingInterface, onBack: () => setState(() => _step = 0)),
      const SizedBox(height: 24),
      _Label(l10n.onboardingInterfaceLanguage),
      const SizedBox(height: 12),
      ..._uiLanguages.map((e) => _SelectTile(
        label: e.$2, isActive: e.$1 == _uiLang, onTap: () {
          AppLog.debug('[onboarding] TAP lang=${e.$1} before: _uiLang=$_uiLang AppState.uiLang=${Provider.of<AppState>(context, listen: false).uiLang}');
          setState(() => _uiLang = e.$1);
          final appState = Provider.of<AppState>(context, listen: false);
          appState.uiLang = e.$1;
          AppLog.debug('[onboarding] AFTER: _uiLang=$_uiLang AppState.uiLang=${appState.uiLang} AppState.locale=${appState.locale}');
        },
      )),
      const SizedBox(height: 24),
      _Label(l10n.onboardingTheme),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _ThemeCard(icon: Icons.light_mode, label: l10n.onboardingLight, sub: '',
            isActive: _themeMode == ThemeMode.light, onTap: () => _setTheme(ThemeMode.light))),
        const SizedBox(width: 12),
        Expanded(child: _ThemeCard(icon: Icons.dark_mode, label: l10n.onboardingDark, sub: '',
            isActive: _themeMode == ThemeMode.dark, onTap: () => _setTheme(ThemeMode.dark))),
      ]),
      const SizedBox(height: 32),
      _Btn(label: l10n.onboardingContinue, onTap: () => setState(() => _step = 2)),
    ]);
    }); // Consumer builder close
  }

  // ——— Step 2: AI Config ———
  Widget _buildAIConfig({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(key: key, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Header(step: 2, title: l10n.onboardingAIConfig, onBack: () => setState(() => _step = 1)),
      const SizedBox(height: 16),
      Text(l10n.onboardingAIDesc, style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
      Text(l10n.onboardingAIRegister, style: TextStyle(fontSize: 12, color: AppTheme.primary)),
      const SizedBox(height: 20),
      if (widget.aiConfigured)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.onboardingAiConfiguredEnv,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1B5E20)))),
          ]),
        ),
      if (widget.aiConfigured) const SizedBox(height: 16),
      _Label('API Key'),
      TextField(
        obscureText: true,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: _inputDec('sk-... 或使用 \$env:VOCABLOCK_AI_KEY'),
        onChanged: (v) => setState(() => _apiKey = v),
      ),
      const SizedBox(height: 16),
      _Label('Model'),
      TextField(style: TextStyle(color: AppTheme.textPrimary, fontSize: 14), decoration: _inputDec('deepseek-v4-pro'), controller: _modelCtrl, onChanged: (v) => _model = v),
      const SizedBox(height: 16),
      _Label('API Base URL'),
      TextField(style: TextStyle(color: AppTheme.textPrimary, fontSize: 14), decoration: _inputDec('https://api.deepseek.com'), controller: _baseUrlCtrl, onChanged: (v) => _baseUrl = v),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _apiKey.isEmpty || _testing ? null : _testConnection,
            icon: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_find, size: 18),
            label: Text(_testResult.isNotEmpty ? _testResult : l10n.onboardingTestConnection),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ]),
      const SizedBox(height: 24),
      _Btn(label: widget.aiConfigured || _apiKey.isNotEmpty ? l10n.onboardingNextAI : l10n.onboardingSkipAI, onTap: _next),
      if (!widget.aiConfigured && _apiKey.isEmpty)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(l10n.onboardingSkipAIHint, style: TextStyle(fontSize: 12, color: AppTheme.textHint))),
    ]);
  }

  // ——— Step 3: AI Interview ———
  Widget _buildInterview({Key? key}) {
    final canRequestProfile = _roundCount >= _minRounds && !_profileDone && !_chatLoading;
    final l10n = AppLocalizations.of(context)!;
    return Column(key: key, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Header(step: 3, title: l10n.onboardingAIAdvisor, onBack: () => setState(() => _step = 2)),
      const SizedBox(height: 8),
      Text('🤖 ${l10n.onboardingInterviewRoundCount(_roundCount)}'
          '${_profileDone ? l10n.onboardingInterviewDone : canRequestProfile ? l10n.onboardingInterviewReady : l10n.onboardingInterviewMinHint(_minRounds)}',
          style: TextStyle(fontSize: 13, color: _profileDone ? Colors.green : AppTheme.textHint)),
      const SizedBox(height: 12),
      Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppTheme.isDark ? const Color(0xFF0D0E18) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _chatMsgs.isEmpty && _chatLoading
            ? Center(child: Text(l10n.onboardingConnectingAI, style: TextStyle(color: AppTheme.textHint)))
            : ListView.builder(
                controller: _scrollCtrl, padding: const EdgeInsets.all(12), itemCount: _chatMsgs.length,
                itemBuilder: (_, i) {
                  final m = _chatMsgs[i];
                  final isUser = m.role == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 380),
                      decoration: BoxDecoration(
                        color: isUser ? AppTheme.primary : AppTheme.cardBg,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
                          bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                        ),
                      ),
                      child: Text(m.content, style: TextStyle(fontSize: 13, color: isUser ? Colors.white : AppTheme.textPrimary, height: 1.4)),
                    ),
                  );
                },
              ),
      ),
      if (_chatLoading) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.onboardingAIThinking, style: TextStyle(fontSize: 12, color: AppTheme.textHint))),
      const SizedBox(height: 12),
      if (!_profileDone) ...[
        Row(children: [
          Expanded(child: TextField(
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            controller: _chatCtrl,
            decoration: _inputDec(l10n.onboardingChatInputHint),
            enabled: !_chatLoading,
            onSubmitted: (v) { if (v.isNotEmpty) { _sendInterviewMsg(v); _chatCtrl.clear(); } },
          )),
          const SizedBox(width: 8),
          IconButton(onPressed: !_chatLoading && _chatCtrl.text.isNotEmpty ? () { _sendInterviewMsg(_chatCtrl.text); _chatCtrl.clear(); } : null,
              icon: const Icon(Icons.send), style: IconButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white)),
        ]),
        const SizedBox(height: 12),
        if (canRequestProfile || (_roundCount > 0 && !_profileDone && !_chatLoading))
          _Btn(label: l10n.onboardingGeneratePlan, onTap: _doRequestProfile),
      ],
      if (_profileDone) ...[
        const SizedBox(height: 12),
        _Btn(label: l10n.onboardingPlanDone, onTap: () => setState(() => _step = 4)),
      ],
      const SizedBox(height: 8),
      TextButton(onPressed: () => setState(() => _step = 4), child: Text(l10n.onboardingSkipInterview, style: TextStyle(fontSize: 12, color: AppTheme.textHint))),
    ]);
  }

  // ——— Step 4: Password + Learning Setup ———
  Widget _buildLearnSetup({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(key: key, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Header(step: 4, title: l10n.onboardingStudySetup, onBack: () => setState(() => _step = _apiKey.isNotEmpty ? 3 : 2)),
      const SizedBox(height: 16),
      _Label(l10n.onboardingEscapePassword),
      Text(l10n.onboardingEscapePasswordHint, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
      const SizedBox(height: 12),
      TextField(
        obscureText: true,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: _inputDec(l10n.onboardingEscapePassword),
        onChanged: (v) => _password = v,
      ),
      const SizedBox(height: 24),
      _Label(l10n.onboardingLanguageToStudy),
      const SizedBox(height: 12),
      ..._learnLanguages.map((e) => _SelectTile(
        label: '${e.$2}  ${e.$3}', isActive: e.$1 == _learnLang, onTap: () { setState(() => _learnLang = e.$1); _fetchLangConfig(e.$1); },
      )),
      const SizedBox(height: 20),
      _TtsDictInfo(lang: _learnLang, voice: _voiceForLang(_langConfig), provider: _dictForLang(_langConfig)),
      const SizedBox(height: 24),
      _Label(l10n.onboardingDailyTarget),
      Text(l10n.onboardingAccuracyHint, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
      const SizedBox(height: 12),
      // Time-based slider: 5–120 minutes → ~2.5–60 questions at 2 min/q
      Row(children: [
        Text('${_studyMinutes.round()} ${l10n.onboardingMinutes}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        const SizedBox(width: 4),
        Text('≈ ${(_studyMinutes / 2).round()} ${l10n.onboardingQuestionsUnit}', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
      ]),
      Slider(
        value: _studyMinutes,
        min: 5, max: 120,
        divisions: 23, // 5-min steps
        activeColor: AppTheme.primary,
        onChanged: (v) => setState(() => _studyMinutes = v),
      ),
      const SizedBox(height: 32),
      _Btn(label: l10n.onboardingComplete, onTap: () {
        widget.onComplete(
          uiLang: _uiLang, themeMode: _themeMode,
          learnLang: _learnLang, dailyTarget: (_studyMinutes / 2).round().clamp(3, 60), dailyTimeTarget: _studyMinutes.round(),
          apiKey: _apiKey.isNotEmpty ? _apiKey : null,
          model: _model.isNotEmpty ? _model : null,
          baseUrl: _baseUrl.isNotEmpty ? _baseUrl : null,
          profileText: _profileText.isNotEmpty ? _profileText : null,
          direction: _profileDirection.isNotEmpty ? _profileDirection : null,
          password: _password.isNotEmpty ? _password : null,
        );
      }),
    ]);
  }
}

// ——— Shared widget helpers ———

class _Features extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.08), AppTheme.accent.withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ), child: Column(children: [
      _FRow(icon: Icons.quiz, text: l10n.onboardingFeature1),
      const SizedBox(height: 16),
      _FRow(icon: Icons.mic, text: l10n.onboardingFeature2),
      const SizedBox(height: 16),
      _FRow(icon: Icons.language, text: l10n.onboardingFeature3),
      const SizedBox(height: 16),
      _FRow(icon: Icons.lock_outline, text: l10n.onboardingFeature4),
    ]));
  }
}

class _FRow extends StatelessWidget {
  final IconData icon; final String text;
  const _FRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppTheme.primary), const SizedBox(width: 12),
    Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
  ]);
}

class _Header extends StatelessWidget {
  final int step; final String title; final VoidCallback onBack;
  const _Header({required this.step, required this.title, required this.onBack});
  @override
  Widget build(BuildContext context) => Row(children: [
    GestureDetector(onTap: onBack, child: Icon(Icons.arrow_back, color: AppTheme.textHint, size: 20)),
    const SizedBox(width: 12),
    Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
    const Spacer(),
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
    ), child: Text('${step + 1} / 5', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary))),
  ]);
}

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
  ]);
}

class _SelectTile extends StatelessWidget {
  final String label; final bool isActive; final VoidCallback onTap;
  const _SelectTile({required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: isActive ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5) : null,
      ),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.grey.shade300, shape: BoxShape.circle,
        ), child: isActive ? const Icon(Icons.check, color: Colors.white, size: 16) : null),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ]),
    ),
  );
}

class _ThemeCard extends StatelessWidget {
  final IconData icon; final String label; final String sub; final bool isActive; final VoidCallback onTap;
  const _ThemeCard({required this.icon, required this.label, required this.sub, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: isActive ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5) : null,
      ),
      child: Column(children: [
        Icon(icon, size: 32, color: isActive ? AppTheme.primary : AppTheme.textHint),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isActive ? AppTheme.primary : AppTheme.textSecondary)),
        Text(sub, style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
      ]),
    ),
  );
}

class _Btn extends StatelessWidget {
  final String label; final VoidCallback? onTap;
  const _Btn({required this.label, this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 48,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    ),
  );
}

class _TtsDictInfo extends StatelessWidget {
  final String lang;
  final String voice;
  final String provider;
  const _TtsDictInfo({required this.lang, required this.voice, required this.provider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final voiceOk = voice.isNotEmpty;
    final providerOk = provider.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.isDark ? const Color(0xFF1A1B2E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.settings_voice, size: 16, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(l10n.onboardingVoiceTts, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const Spacer(),
            Icon(voiceOk ? Icons.check_circle : Icons.warning_amber, size: 14, color: voiceOk ? Colors.green : Colors.orange),
            const SizedBox(width: 4),
            Text(voiceOk ? l10n.onboardingConnected : l10n.onboardingNotConnected, style: TextStyle(fontSize: 11, color: voiceOk ? Colors.green : Colors.orange)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Text(voiceOk ? voice : l10n.onboardingNotConfigured, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.menu_book, size: 16, color: AppTheme.warm),
            const SizedBox(width: 8),
            Text(l10n.onboardingDictCheck, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const Spacer(),
            Icon(providerOk ? Icons.check_circle : Icons.warning_amber, size: 14, color: providerOk ? Colors.green : Colors.orange),
            const SizedBox(width: 4),
            Text(providerOk ? l10n.onboardingConnected : l10n.onboardingNotConnected, style: TextStyle(fontSize: 11, color: providerOk ? Colors.green : Colors.orange)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Text(providerOk ? provider : l10n.onboardingNotConfigured, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: AppTheme.textHint),
  filled: true,
  fillColor: AppTheme.isDark ? const Color(0xFF2A2B40) : Colors.grey.shade50,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
);
