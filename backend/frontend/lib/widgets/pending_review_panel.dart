import 'package:flutter/material.dart';
import '../models/word.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class PendingReviewPanel extends StatefulWidget {
  final AppState state;
  const PendingReviewPanel({super.key, required this.state});

  @override
  State<PendingReviewPanel> createState() => _PendingReviewPanelState();
}

class _PendingReviewPanelState extends State<PendingReviewPanel> {
  List<Word> _words = [];
  bool _loading = true;
  String? _error;
  String? _actionMessage;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final api = widget.state.wordsApi;
    if (api != null) {
      try {
        _words = await api.listPendingReview(language: widget.state.activeLangCode);
      } catch (e) {
        _error = e.toString();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _accept(Word w) async {
    final readingCtrl = TextEditingController();
    final meaningCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final levelCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('审核 "${w.word}"', style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Field(label: '读法（必填）', hint: '如 たべる', controller: readingCtrl),
              const SizedBox(height: 12),
              _Field(label: '释义（必填）', hint: '如 吃', controller: meaningCtrl),
              const SizedBox(height: 12),
              _Field(label: '词性（必填）', hint: '如 動詞', controller: posCtrl),
              const SizedBox(height: 12),
              _Field(label: '等级（可选）', hint: '如 N5', controller: levelCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (readingCtrl.text.trim().isEmpty || meaningCtrl.text.trim().isEmpty || posCtrl.text.trim().isEmpty) {
                return; // silently ignore — all required fields must be filled
              }
              Navigator.pop(ctx, {
                'reading': readingCtrl.text.trim(),
                'meaning': meaningCtrl.text.trim(),
                'pos': posCtrl.text.trim(),
                'level': levelCtrl.text.trim(),
              });
            },
            child: Text('通过', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (result == null) return;

    setState(() => _acting = true);
    try {
      await widget.state.wordsApi!.acceptPendingReview(
        w.id,
        reading: result['reading']!,
        meaning: result['meaning']!,
        pos: result['pos']!,
        level: result['level'] ?? '',
      );
      _showMessage('"${w.word}" 已通过校验');
    } catch (e) {
      _showMessage('操作失败: $e');
    }
    setState(() => _acting = false);
    if (mounted) _load();
  }

  Future<void> _reject(Word w) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('拒绝 "${w.word}"', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: reasonCtrl,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: '拒绝原因（反馈给AI）',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text),
            child: const Text('拒绝', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _acting = true);
    try {
      await widget.state.wordsApi!.rejectPendingReview(w.id, reason: reason.isNotEmpty ? reason : null);
      _showMessage('"${w.word}" 已打回AI');
    } catch (e) {
      _showMessage('操作失败: $e');
    }
    setState(() => _acting = false);
    if (mounted) _load();
  }

  Future<void> _editTags(Word w) async {
    final tagCtrl = TextEditingController(text: w.tags.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('编辑标签: ${w.word}', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: tagCtrl,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: '用逗号分隔，如: 难记, 易混淆, 考试重点',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, tagCtrl.text),
            child: Text('保存', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    if (result == null) return;
    final tags = result.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    try {
      await widget.state.wordsApi!.updateTags(w.id, tags);
      _showMessage('标签已更新');
      if (mounted) _load();
    } catch (e) {
      _showMessage('标签更新失败: $e');
    }
  }

  void _showMessage(String msg) {
    setState(() => _actionMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _actionMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('待审核词汇', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              if (_acting)
                const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 20)),
            ],
          ),
          if (_actionMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_actionMessage!, style: TextStyle(fontSize: 13, color: AppTheme.primary))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text('加载失败: $_error', style: TextStyle(color: AppTheme.textHint))))
          else if (_words.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: AppTheme.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('没有待审核词汇', style: TextStyle(fontSize: 15, color: AppTheme.textHint)),
                    const SizedBox(height: 8),
                    Text('AI 生成的词汇通过词典校验后会自动入库，\n未通过校验的会出现在这里供你审核。',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _words.length,
                itemBuilder: (_, i) => _ReviewCard(
                  word: _words[i],
                  onAccept: () => _accept(_words[i]),
                  onReject: () => _reject(_words[i]),
                  onEditTags: () => _editTags(_words[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;

  const _Field({required this.label, required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Word word;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEditTags;

  const _ReviewCard({
    required this.word,
    required this.onAccept,
    required this.onReject,
    required this.onEditTags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(word.word, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(width: 8),
                        if (word.pos.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(word.pos, style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(word.reading, style: TextStyle(fontSize: 13, color: AppTheme.accent)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('待审核', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(word.meaning, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          if (word.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: word.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.isDark ? const Color(0xFF2A2B40) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(t, style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
              )).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onEditTags,
                icon: const Icon(Icons.label_outline, size: 16),
                label: const Text('标签'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('拒绝'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('通过'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
