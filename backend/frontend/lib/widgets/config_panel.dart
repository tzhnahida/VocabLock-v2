import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class ConfigPanel extends StatefulWidget {
  final AppState state;
  const ConfigPanel({super.key, required this.state});

  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> {
  Map<String, dynamic> _config = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final configApi = widget.state.configApi;
    if (configApi != null) {
      try {
        _config = await configApi.getConfig();
      } catch (_) {
        _config = _defaults();
      }
    } else {
      _config = _defaults();
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _defaults() => {
    'active_lang': widget.state.activeLangCode,
    'daily_target': 20,
    'min_accuracy': 0.8,
    'listening_ratio': 0.15,
    'reading_ratio': 0.15,
    'grammar_ratio': 0.15,
    'extra_ratio': 0.15,
    'passive_enabled': true,
    'passive_min_interval': 25,
    'passive_max_interval': 60,
    'escape_password_limit': 1,
    'escape_click_limit': 2,
    'auto_start': false,
    'auto_expand_words': true,
    'expand_batch_size': 10,
    'expand_threshold': 0.6,
    'model': 'deepseek-v4-pro',
    'base_url': 'https://api.deepseek.com',
  };

  Future<void> _save(String key, dynamic value) async {
    setState(() { _config[key] = value; _saving = true; });
    final configApi = widget.state.configApi;
    if (configApi != null) {
      try {
        await configApi.updateConfig(activeLang: _config['active_lang'], dailyTarget: _config['daily_target']);
      } catch (_) {}
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const Spacer(),
                if (_saving)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 20)),
              ],
            ),
            const SizedBox(height: 24),

            _section('学习设置'),
            _intField('每日目标', 'daily_target', 1, 200),
            _percentField('最低正确率', 'min_accuracy'),

            _section('题型比例'),
            _percentField('听力题比例', 'listening_ratio'),
            _percentField('阅读题比例', 'reading_ratio'),
            _percentField('语法题比例', 'grammar_ratio'),
            _percentField('额外题目比例', 'extra_ratio'),

            _section('被动答题'),
            _boolField('启用被动答题', 'passive_enabled'),
            _intField('最小间隔（分钟）', 'passive_min_interval', 5, 120),
            _intField('最大间隔（分钟）', 'passive_max_interval', 10, 240),

            _section('AI 扩词'),
            _boolField('自动扩词', 'auto_expand_words'),
            _intField('每批扩词数', 'expand_batch_size', 3, 50),
            _percentField('扩词触发阈值', 'expand_threshold'),

            _section('AI 模型'),
            _textField('模型名称', 'model'),
            _textField('API 地址', 'base_url'),

            _section('逃生限制'),
            _intField('每日密码逃生次数', 'escape_password_limit', 1, 5),
            _intField('每日点击逃生次数', 'escape_click_limit', 1, 10),

            _section('系统'),
            _boolField('开机自启', 'auto_start'),
            _readOnly('当前语言', _config['active_lang']?.toString().toUpperCase() ?? '-'),
            _readOnly('可用语言', (_config['languages'] as List<dynamic>?)?.join(', ') ?? '-'),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textHint, letterSpacing: 0.5)),
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

  Widget _intField(String label, String key, int min, int max) {
    final value = (_config[key] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          SizedBox(
            width: 44,
            child: IconButton(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: value > min ? () => _save(key, value - 1) : null,
              padding: EdgeInsets.zero,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('$value', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: value < max ? () => _save(key, value + 1) : null,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _percentField(String label, String key) {
    final value = ((_config[key] as num?)?.toDouble() ?? 0) * 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          SizedBox(
            width: 180,
            child: Slider(
              value: value.clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: AppTheme.primary,
              label: '${value.toInt()}%',
              onChanged: (v) => _save(key, v / 100.0),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('${value.toInt()}%', textAlign: TextAlign.end,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _boolField(String label, String key) {
    final value = _config[key] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          Switch(
            value: value,
            activeColor: AppTheme.primary,
            onChanged: (v) => _save(key, v),
          ),
        ],
      ),
    );
  }

  Widget _textField(String label, String key) {
    final ctrl = TextEditingController(text: _config[key]?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          ),
          Expanded(
            flex: 5,
            child: TextField(
              controller: ctrl,
              style: TextStyle(fontSize: 13, color: AppTheme.primary),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (v) { if (v.isNotEmpty) _save(key, v); },
            ),
          ),
        ],
      ),
    );
  }
}
