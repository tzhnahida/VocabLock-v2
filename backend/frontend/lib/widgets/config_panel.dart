import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class ConfigPanel extends StatefulWidget {
  final AppState state;
  const ConfigPanel({super.key, required this.state});

  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic> _appConfig = {};
  Map<String, dynamic>? _aiConfig;
  List<Map<String, dynamic>> _ttsProviders = [];
  List<Map<String, dynamic>> _dictProviders = [];
  Map<String, dynamic>? _langConfig;
  String? _langCode;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 1, vsync: this);
    _loadApp();
  }

  Future<void> _loadApp() async {
    setState(() => _loading = true);
    final configApi = widget.state.configApi;
    if (configApi != null) {
      try {
        _appConfig = await configApi.getConfig();
      } catch (_) {
        _appConfig = _defaults();
      }
    } else {
      _appConfig = _defaults();
    }
    // Build tabs: 通用 + each language
    final langs = (_appConfig['languages'] as List<dynamic>?)?.cast<String>() ?? [];
    _tabCtrl = TabController(length: 1 + langs.length, vsync: this);
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _defaults() => {
    'active_lang': widget.state.activeLangCode,
    'daily_target': 20,
    'min_accuracy': 0.8,
    'passive_enabled': true,
    'passive_min_interval': 25,
    'passive_max_interval': 60,
    'auto_expand_words': true,
    'expand_batch_size': 10,
    'sm2_max_interval_days': 180,
    'session_time_budget': 0,
    'max_slow_type_ratio': 0.0,
    'model': 'deepseek-chat',
    'base_url': 'https://api.deepseek.com',
    'languages': [],
    'assignment': {'cadence_days': 3, 'cadence_count': 2, 'max_per_session': 1, 'ai_recommend': true},
  };

  Future<void> _save(String key, dynamic value) async {
    setState(() { _appConfig[key] = value; _saving = true; });
    final configApi = widget.state.configApi;
    if (configApi != null) {
      try {
        await configApi.updateConfigRaw({key: value});
      } catch (_) {}
    }
    if (mounted) setState(() => _saving = false);
  }

  void _saveAssignment(String key, dynamic value) {
    final assignment = Map<String, dynamic>.from(_appConfig['assignment'] as Map<String, dynamic>? ?? {});
    assignment[key] = value;
    _save('assignment', assignment);
  }

  // ——— Lazy load ———

  void _onTabChanged(int index) {
    if (index == 0 && _aiConfig == null) _loadAI();
    else if (index > 0) _loadLanguage(index - 1);
  }

  Future<void> _loadAI() async {
    final configApi = widget.state.configApi;
    if (configApi == null) return;
    try {
      final ai = await configApi.getAIConfig();
      final tts = await configApi.getTTSConfig();
      final dict = await configApi.getDictConfig();
      if (mounted) setState(() {
        _aiConfig = ai;
        _ttsProviders = (tts['providers'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        _dictProviders = (dict['providers'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      });
    } catch (_) {}
  }

  Future<void> _loadLanguage(int idx) async {
    final langs = (_appConfig['languages'] as List<dynamic>?)?.cast<String>() ?? [];
    if (idx >= langs.length) return;
    final code = langs[idx];
    final configApi = widget.state.configApi;
    if (configApi == null) return;
    try {
      final lc = await configApi.getLanguageConfig(code);
      if (mounted) setState(() { _langConfig = lc; _langCode = code; });
    } catch (_) {}
  }

  Future<void> _saveLanguage(String code, Map<String, dynamic> data) async {
    final configApi = widget.state.configApi;
    if (configApi == null) return;
    setState(() => _saving = true);
    try {
      await configApi.updateLanguageConfig(code, data);
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  List<String> get _langs => (_appConfig['languages'] as List<dynamic>?)?.cast<String>() ?? [];

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              if (_saving) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton(onPressed: _loadApp, icon: const Icon(Icons.refresh, size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textHint,
            indicatorColor: AppTheme.primary,
            onTap: _onTabChanged,
            tabs: [
              const Tab(text: '通用'),
              ..._langs.map((c) => Tab(text: c.toUpperCase())),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildGeneralTab(),
                ..._langs.map((c) => _buildLanguageTab(c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── General Tab ─────────────────────────────────────

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('学习'),
          _intField('每日目标', 'daily_target', 1, 200),
          _percentField('最低正确率', 'min_accuracy'),
          _intField('学习时长(分钟, 0=不限)', 'session_time_budget', 0, 120),
          _percentField('慢速题型上限', 'max_slow_type_ratio'),

          _section('AI 学习方案'),
          _buildPlanPanel(),

          _section('被动答题 (即将推出)'),
          _dimmedField(_boolField('启用', 'passive_enabled')),
          _dimmedField(_intField('最小间隔(分钟)', 'passive_min_interval', 5, 120)),
          _dimmedField(_intField('最大间隔(分钟)', 'passive_max_interval', 10, 240)),

          _section('AI 扩词'),
          _boolField('自动扩词', 'auto_expand_words'),
          _intField('每批扩词数', 'expand_batch_size', 3, 50),
          _intField('SM-2 最大间隔(天)', 'sm2_max_interval_days', 30, 365),

          _section('课后作业'),
          _assignmentIntField('每几天一次', 'cadence_days', 1, 30),
          _assignmentIntField('每次几题', 'cadence_count', 1, 10),
          _assignmentBoolField('AI 推荐', 'ai_recommend'),

          _section('AI 模型'),
          if (_aiConfig != null) ...[
            _aiRow('模型', _aiConfig!['model'] ?? '-'),
            _aiRow('地址', _aiConfig!['base_url'] ?? '-'),
            _aiRow('状态', _aiConfig!['configured'] == true ? '已配置' : '未配置'),
          ] else
            const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),

          _section('TTS 提供者'),
          if (_ttsProviders.isEmpty)
            _hint('点击刷新加载 TTS 配置')
          else
            ..._ttsProviders.map((p) => _providerRow(
              name: p['name'] ?? '',
              binary: p['binary'] ?? '',
              healthy: p['healthy'] == true,
              badge: (p['voices'] as Map?)?.length.toString() ?? '0',
              badgeLabel: 'voices',
              onTap: () {},
            )),

          _section('词典提供者'),
          if (_dictProviders.isEmpty)
            _hint('点击刷新加载词典配置')
          else
            ..._dictProviders.map((p) => _providerRow(
              name: p['name'] ?? '',
              binary: p['binary'] ?? '',
              healthy: p['healthy'] == true,
              badge: p['exam_levels'] == true ? 'Lv' : null,
              badgeLabel: p['exam_levels'] == true ? '带等级' : '无等级',
              onTap: () {},
            )),

          _section('系统'),
          _dimmedField(_boolField('开机自启 (即将推出)', 'auto_start')),
          _readOnly('当前语言', _appConfig['active_lang']?.toString().toUpperCase() ?? '-'),
          _readOnly('可用语言', _langs.join(', ').toUpperCase()),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Language Tab ────────────────────────────────────

  Widget _buildLanguageTab(String code) {
    if (_langCode != code) _loadLanguage(_langs.indexOf(code));
    final lc = _langConfig;
    if (lc == null) return const Center(child: CircularProgressIndicator());

    final ttsVoices = _collectTTsVoices(lc['tts_provider']);
    final dictNames = _dictProviders.map((p) => (p['name'] ?? '') as String).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('基本信息'),
          _readOnly('语言', lc['display_name'] ?? code),
          _readOnly('本地名称', lc['native_name'] ?? code),

          _section('TTS'),
          _dropdown('提供者', lc['tts_provider'] ?? '', (v) {
            _saveLanguage(code, {'tts_provider': v});
            setState(() => _langConfig!['tts_provider'] = v);
          }, _ttsProviders.map((p) => (p['name'] ?? '') as String).toList()),
          _dropdown('声音', lc['tts_voice'] ?? '', (v) {
            _saveLanguage(code, {'tts_voice': v});
            setState(() => _langConfig!['tts_voice'] = v);
          }, ttsVoices),

          _section('词典'),
          _dropdown('提供者', lc['dict_provider'] ?? '', (v) {
            _saveLanguage(code, {'dict_provider': v});
            setState(() => _langConfig!['dict_provider'] = v);
          }, dictNames),

          if (lc['prompt_context'] != null) ...[
            _section('AI Prompt'),
            _readOnly('老师角色', lc['prompt_context']['teacher_role'] ?? '-'),
            _readOnly('解释语言', lc['prompt_context']['explanation_lang'] ?? '-'),
            _readOnly('等级描述', (lc['prompt_context']['level_descriptions'] as Map?)?.keys.join(', ') ?? '-'),
          ],

          if (lc['question_types'] != null) ...[
            _section('题型'),
            _readOnly('启用的题型', (lc['question_types'] as List?)?.join(', ') ?? '-'),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<String> _collectTTsVoices(String? providerName) {
    if (providerName == null) return [];
    for (final p in _ttsProviders) {
      if (p['name'] == providerName) {
        return (p['voices'] as Map?)?.keys.cast<String>().toList() ?? [];
      }
    }
    return [];
  }

  // ─── Widgets ─────────────────────────────────────────

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textHint, letterSpacing: 0.5)),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
    );
  }

  Widget _readOnly(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _aiRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _providerRow({
    required String name,
    required String binary,
    required bool healthy,
    String? badge,
    String? badgeLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: healthy ? Colors.green : Colors.red.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(binary, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badgeLabel ?? badge, style: TextStyle(fontSize: 10, color: AppTheme.primary)),
            ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String current, ValueChanged<String> onChanged, List<String> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.contains(current) ? current : (items.isNotEmpty ? items.first : null),
                isExpanded: true,
                style: TextStyle(fontSize: 14, color: AppTheme.primary),
                dropdownColor: AppTheme.cardBg,
                items: items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) { if (v != null) onChanged(v); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intField(String label, String key, int min, int max) {
    final value = (_appConfig[key] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          SizedBox(width: 44, child: IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: value > min ? () => _save(key, value - 1) : null, padding: EdgeInsets.zero)),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary))),
          SizedBox(width: 44, child: IconButton(icon: const Icon(Icons.add, size: 18), onPressed: value < max ? () => _save(key, value + 1) : null, padding: EdgeInsets.zero)),
        ],
      ),
    );
  }

  Widget _percentField(String label, String key) {
    final value = ((_appConfig[key] as num?)?.toDouble() ?? 0) * 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          SizedBox(
            width: 180,
            child: Slider(value: value.clamp(0, 100), min: 0, max: 100, divisions: 20, activeColor: AppTheme.primary, label: '${value.toInt()}%', onChanged: (v) => _save(key, v / 100.0)),
          ),
          SizedBox(width: 44, child: Text('${value.toInt()}%', textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary))),
        ],
      ),
    );
  }

  Widget _assignmentIntField(String label, String key, int min, int max) {
    final assignment = _appConfig['assignment'] as Map<String, dynamic>? ?? {};
    final value = (assignment[key] as num?)?.toInt() ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          SizedBox(width: 44, child: IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: value > min ? () => _saveAssignment(key, value - 1) : null, padding: EdgeInsets.zero)),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary))),
          SizedBox(width: 44, child: IconButton(icon: const Icon(Icons.add, size: 18), onPressed: value < max ? () => _saveAssignment(key, value + 1) : null, padding: EdgeInsets.zero)),
        ],
      ),
    );
  }

  Widget _assignmentBoolField(String label, String key) {
    final assignment = _appConfig['assignment'] as Map<String, dynamic>? ?? {};
    final value = assignment[key] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          Switch(value: value, activeColor: AppTheme.primary, onChanged: (v) => _saveAssignment(key, v)),
        ],
      ),
    );
  }

  Widget _boolField(String label, String key) {
    final value = _appConfig[key] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          Switch(value: value, activeColor: AppTheme.primary, onChanged: (v) => _save(key, v)),
        ],
      ),
    );
  }

  Widget _dimmedField(Widget child) {
    return Opacity(opacity: 0.4, child: child);
  }

  Widget _buildPlanPanel() {
    return FutureBuilder(
      future: widget.state.quizApi?.getPlan(),
      builder: (context, snapshot) {
        final plan = snapshot.data;
        if (plan == null || plan.planJson.isEmpty) {
          return _hint('完成一次学习后 AI 将生成方案');
        }

        Map<String, dynamic> tomorrow;
        try {
          final parsed = const JsonDecoder().convert(plan.planJson);
          tomorrow = (parsed['tomorrow'] as Map<String, dynamic>?) ?? {};
        } catch (_) {
          return _hint('计划数据解析失败');
        }

        final ratio = tomorrow['question_type_ratio'] as Map<String, dynamic>?;
        final wordCount = (tomorrow['word_count'] as num?)?.toInt() ?? 0;
        final grammarFocus = (tomorrow['grammar_focus'] as List?)?.cast<String>() ?? [];
        final difficulty = tomorrow['difficulty'] as String? ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (difficulty.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('难度', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    Text(difficulty, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ],
                ),
              ),
            if (wordCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('建议扩词数', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    Text('$wordCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ],
                ),
              ),
            if (ratio != null && ratio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('题型配比', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
              const SizedBox(height: 4),
              ...ratio.entries.map((e) {
                final pct = (e.value as num).toDouble();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      SizedBox(width: 80, child: Text(e.key, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100.0,
                            minHeight: 8,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 36, child: Text('${pct.toInt()}%', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary))),
                    ],
                  ),
                );
              }),
            ],
            if (grammarFocus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('语法重点', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6, runSpacing: 4,
                children: grammarFocus.map((g) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(g, style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                )).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}
