import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../theme/app_theme.dart';

class AssignmentSheet extends StatefulWidget {
  final Future<AssignmentBatch> Function() onGetAssignments;
  final Future<AssignmentGrade> Function({required String assignmentId, required String answer}) onSubmit;
  final Future<CadenceRecommendation> Function() onGetCadence;
  final VoidCallback onDone;

  const AssignmentSheet({
    super.key,
    required this.onGetAssignments,
    required this.onSubmit,
    required this.onGetCadence,
    required this.onDone,
  });

  @override
  State<AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<AssignmentSheet> {
  AssignmentBatch? _batch;
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;

  final _answerCtrl = TextEditingController();
  AssignmentGrade? _grade;

  CadenceRecommendation? _cadence;
  bool _showCadenceTip = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _batch = await widget.onGetAssignments();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCadence() async {
    if (_cadence != null) {
      setState(() => _showCadenceTip = !_showCadenceTip);
      return;
    }
    try {
      _cadence = await widget.onGetCadence();
      setState(() => _showCadenceTip = true);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty || _submitting || _batch == null) return;
    final a = _batch!.assignments[_currentIndex];
    setState(() => _submitting = true);
    try {
      _grade = await widget.onSubmit(assignmentId: a.id, answer: answer);
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
  }

  void _next() {
    if (_batch == null) return;
    if (_currentIndex + 1 < _batch!.assignments.length) {
      setState(() {
        _currentIndex++;
        _grade = null;
        _answerCtrl.clear();
      });
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: _loading
            ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
            : _batch == null || _batch!.isEmpty
                ? _buildEmpty()
                : _buildAssignment(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: AppTheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('暂无课后作业', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('作业按你设定的节奏出现，现在还没有到时间。',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
          const SizedBox(height: 20),
          if (_cadence != null)
            _CadenceCard(cadence: _cadence!)
          else
            OutlinedButton.icon(
              onPressed: _loadCadence,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI 推荐节奏'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          if (_showCadenceTip && _cadence != null) ...[
            const SizedBox(height: 12),
            _CadenceCard(cadence: _cadence!),
          ],
          const SizedBox(height: 16),
          TextButton(onPressed: widget.onDone, child: Text('关闭', style: TextStyle(color: AppTheme.textHint))),
        ],
      ),
    );
  }

  Widget _buildAssignment() {
    final a = _batch!.assignments[_currentIndex];
    final progress = '${_currentIndex + 1}/${_batch!.assignments.length}';
    final typeLabel = _typeName(a.type);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(typeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent)),
              ),
              const Spacer(),
              Text(progress, style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
            ],
          ),
          const SizedBox(height: 20),
          Text(a.prompt, style: TextStyle(fontSize: 16, color: AppTheme.textPrimary, height: 1.6)),
          if (a.context != null && a.context!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.isDark ? const Color(0xFF232438) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(a.context!, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
            ),
          ],
          const SizedBox(height: 20),
          if (_grade == null) ...[
            TextField(
              controller: _answerCtrl,
              maxLines: 6,
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: '在这里写下你的答案...',
                filled: true,
                fillColor: AppTheme.isDark ? const Color(0xFF232438) : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('提交', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
            ),
          ] else ...[
            _GradeCard(grade: _grade!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _currentIndex + 1 < _batch!.assignments.length ? '下一题' : '完成',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _typeName(String type) {
    switch (type) {
      case 'sentence': return '造句';
      case 'translation': return '翻译';
      case 'fill_passage': return '填空短文';
      case 'essay': return '短文写作';
      default: return type;
    }
  }
}

class _CadenceCard extends StatelessWidget {
  final CadenceRecommendation cadence;
  const _CadenceCard({required this.cadence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 推荐: 每${cadence.cadenceDays}天${cadence.cadenceCount}题',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                if (cadence.reason.isNotEmpty)
                  Text(cadence.reason, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final AssignmentGrade grade;
  const _GradeCard({required this.grade});

  @override
  Widget build(BuildContext context) {
    final pct = (grade.score * 100).toInt();
    final color = pct >= 80 ? Colors.green : pct >= 60 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('你的答案', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
          const SizedBox(height: 6),
          Text(grade.original, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
          const SizedBox(height: 14),
          Text('AI 润色', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
          const SizedBox(height: 6),
          Text(grade.corrected, style: TextStyle(fontSize: 13, color: AppTheme.primary, height: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('得分 $pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(grade.feedback, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
            ],
          ),
          if (grade.errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('错误标记:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade400)),
            const SizedBox(height: 4),
            ...grade.errors.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 12, color: Colors.red.shade300),
                  const SizedBox(width: 4),
                  Expanded(child: Text(e, style: TextStyle(fontSize: 12, color: Colors.red.shade300))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
