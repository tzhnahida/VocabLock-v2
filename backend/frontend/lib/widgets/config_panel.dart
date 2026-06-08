import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
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
    _loadAI(); // eagerly load so the general tab never shows spinner
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
    final l10n = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.labelSettings, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
              Tab(text: l10n.tabGeneral),
              ..._langs.map((c) => Tab(text: c.toUpperCase())),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildGeneralTab(l10n),
                ..._langs.map((c) => _buildLanguageTab(c, l10n)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── General Tab ─────────────────────────────────────

  Widget _buildGeneralTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(l10n.sectionLearning),
          _intField(l10n.dailyTarget, 'daily_target', 1, 200),
          _percentField(l10n.minAccuracy, 'min_accuracy'),
          _intField(l10n.sessionTimeBudget, 'session_time_budget', 0, 120),
          _percentField(l10n.maxSlowTypeRatio, 'max_slow_type_ratio'),

          _section(l10n.sectionAIPlan),
          _buildPlanPanel(l10n),

          _section(l10n.sectionPassive),
          _dimmedField(_boolField(l10n.labelEnabled, 'passive_enabled')),
          _dimmedField(_intField(l10n.labelMinIntervalMinutes, 'passive_min_interval', 5, 120)),
          _dimmedField(_intField(l10n.labelMaxIntervalMinutes, 'passive_max_interval', 10, 240)),

          _section(l10n.sectionExpand),
          _boolField(l10n.autoExpand, 'auto_expand_words'),
          _intField(l10n.expandBatchSize, 'expand_batch_size', 3, 50),
          _intField(l10n.sm2MaxInterval, 'sm2_max_interval_days', 30, 365),

          _section(l10n.sectionAssignment),
          _assignmentIntField(l10n.labelCadenceDays, 'cadence_days', 1, 30),
          _assignmentIntField(l10n.labelCadenceCount, 'cadence_count', 1, 10),
          _assignmentBoolField(l10n.labelAIRecommend, 'ai_recommend'),

          _section(l10n.sectionAIModel),
          if (_aiConfig != null) ...[
            _aiRow(l10n.labelModel, _aiConfig!['model'] ?? '-'),
            _aiRow(l10n.labelAddress, _aiConfig!['base_url'] ?? '-'),
            _aiRow(l10n.labelStatus, _aiConfig!['configured'] == true ? l10n.configured : l10n.notConfigured),
          ] else
            const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),

          _section(l10n.sectionTTS),
          if (_ttsProviders.isEmpty)
            _hint(l10n.hintRefreshTTS)
          else
            ..._ttsProviders.map((p) => _providerRow(
              name: p['name'] ?? '',
              binary: p['binary'] ?? '',
              healthy: p['healthy'] == true,
              badge: (p['voices'] as Map?)?.length.toString() ?? '0',
              badgeLabel: l10n.labelVoices,
              onTap: () {},
            )),

          _section(l10n.sectionDict),
          if (_dictProviders.isEmpty)
            _hint(l10n.hintRefreshDict)
          else
            ..._dictProviders.map((p) => _providerRow(
              name: p['name'] ?? '',
              binary: p['binary'] ?? '',
              healthy: p['healthy'] == true,
              badge: p['exam_levels'] == true ? 'Lv' : null,
              badgeLabel: p['exam_levels'] == true ? l10n.labelWithLevel : l10n.labelNoLevel,
              onTap: () {},
            )),

          _section(l10n.sectionSystem),
          _dimmedField(_boolField(l10n.autoStart, 'auto_start')),
          _readOnly(l10n.labelCurrentLanguage, _appConfig['active_lang']?.toString().toUpperCase() ?? '-'),
          _readOnly(l10n.labelAvailableLanguages, _langs.join(', ').toUpperCase()),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Language Tab ────────────────────────────────────

  Widget _buildLanguageTab(String code, AppLocalizations l10n) {
    if (_langCode != code) _loadLanguage(_langs.indexOf(code));
    final lc = _langConfig;
    if (lc == null) return const Center(child: CircularProgressIndicator());

    final ttsVoices = _collectTTsVoices(lc['tts_provider']);
    final dictNames = _dictProviders.map((p) => (p['name'] ?? '') as String).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(l10n.labelBaseInfo),
          _readOnly(l10n.labelLanguage, lc['display_name'] ?? code),
          _readOnly(l10n.labelNativeName, lc['native_name'] ?? code),

          _section(l10n.labelTTS),
          _dropdown(l10n.labelProvider, lc['tts_provider'] ?? '', (v) {
            _saveLanguage(code, {'tts_provider': v});
            setState(() => _langConfig!['tts_provider'] = v);
          }, _ttsProviders.map((p) => (p['name'] ?? '') as String).toList()),
          _dropdown(l10n.labelVoice, lc['tts_voice'] ?? '', (v) {
            _saveLanguage(code, {'tts_voice': v});
            setState(() => _langConfig!['tts_voice'] = v);
          }, ttsVoices),

          _section(l10n.labelDict),
          _dropdown(l10n.labelProvider, lc['dict_provider'] ?? '', (v) {
            _saveLanguage(code, {'dict_provider': v});
            setState(() => _langConfig!['dict_provider'] = v);
          }, dictNames),

          if (lc['prompt_context'] != null) ...[
            _section(l10n.labelPrompt),
            _readOnly(l10n.labelTeacherRole, lc['prompt_context']['teacher_role'] ?? '-'),
            _readOnly(l10n.labelExplanationLang, lc['prompt_context']['explanation_lang'] ?? '-'),
            _readOnly(l10n.labelLevelDescriptions, (lc['prompt_context']['level_descriptions'] as Map?)?.keys.join(', ') ?? '-'),
          ],

          if (lc['question_types'] != null) ...[
            _section(l10n.labelQuestionTypes),
            _readOnly(l10n.labelEnabledTypes, (lc['question_types'] as List?)?.join(', ') ?? '-'),
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

  Widget _buildPlanPanel(AppLocalizations l10n) {
    return FutureBuilder(
      future: widget.state.quizApi?.getPlan(),
      builder: (context, snapshot) {
        final plan = snapshot.data;
        if (plan == null || plan.planJson.isEmpty) {
          return _hint(l10n.noPlanYet);
        }

        Map<String, dynamic> tomorrow;
        try {
          final parsed = const JsonDecoder().convert(plan.planJson);
          tomorrow = (parsed['tomorrow'] as Map<String, dynamic>?) ?? {};
        } catch (_) {
          return _hint(l10n.planParseError);
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
                    Text(l10n.difficulty, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
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
                    Text(l10n.suggestedWordCount, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                    Text('$wordCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ],
                ),
              ),
            if (ratio != null && ratio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.typeRatio, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
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
              Text(l10n.grammarFocus, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
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
