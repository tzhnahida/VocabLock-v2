import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
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

  /// Failures used to be swallowed, which made "AI is down" and "nothing is
  /// due" look identical to the user. Both are surfaced now.
  String? _loadError;
  String? _submitError;

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
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final batch = await widget.onGetAssignments();
      if (mounted) setState(() => _batch = batch);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
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
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final grade = await widget.onSubmit(assignmentId: a.id, answer: answer);
      if (mounted) setState(() => _grade = grade);
    } catch (e) {
      if (mounted) setState(() => _submitError = e.toString());
    }
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

  /// Explains why the sheet is empty instead of always claiming "not due yet".
  /// The backend reports a machine-readable reason (no_due / ai_required /
  /// generation_failed) so the copy can be translated instead of echoed.
  String _emptyHint(AppLocalizations l10n) {
    switch (_batch?.reason) {
      case 'ai_required':
        return l10n.homeworkAIRequired;
      case 'generation_failed':
        return l10n.homeworkGenerationFailed;
      case 'no_due':
        final due = _batch?.nextDueLabel ?? '';
        return due.isEmpty ? l10n.homeworkEmptyHint : l10n.homeworkNextDue(due);
      default:
        return l10n.homeworkEmptyHint;
    }
  }

  Widget _buildEmpty() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: AppTheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(l10n.homeworkEmpty, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(_emptyHint(l10n),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
          if (_loadError != null) ...[
            const SizedBox(height: 10),
            Text(l10n.loadFailed(_loadError!),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.redAccent.withValues(alpha: 0.8))),
            TextButton(onPressed: _load, child: Text(l10n.retry)),
          ],
          const SizedBox(height: 20),
          if (_cadence != null)
            _CadenceCard(cadence: _cadence!)
          else
            OutlinedButton.icon(
              onPressed: _loadCadence,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(l10n.homeworkRecommendedCadence),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          if (_showCadenceTip && _cadence != null) ...[
            const SizedBox(height: 12),
            _CadenceCard(cadence: _cadence!),
          ],
          const SizedBox(height: 16),
          TextButton(onPressed: widget.onDone, child: Text(l10n.close, style: TextStyle(color: AppTheme.textHint))),
        ],
      ),
    );
  }

  Widget _buildAssignment() {
    final l10n = AppLocalizations.of(context)!;
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
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onDone,
                child: Icon(Icons.close, size: 20, color: AppTheme.textHint),
              ),
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
                hintText: l10n.homeworkAnswerHint,
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
            Row(
              children: [
                Expanded(
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
                        : Text(l10n.submit, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  ),
                ),
              ],
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 10),
              Text(l10n.homeworkSubmitFailed(_submitError!),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.redAccent.withValues(alpha: 0.8))),
            ],
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(l10n.exit, style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
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
                  _currentIndex + 1 < _batch!.assignments.length ? l10n.nextQuestion : l10n.done,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(l10n.exit, style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _typeName(String type) {
    final l10n = AppLocalizations.of(context);
    switch (type) {
      case 'sentence': return l10n.typeSentence;
      case 'translation': return l10n.typeTranslation;
      case 'fill_passage': return l10n.typeFillPassage;
      case 'essay': return l10n.typeEssay;
      default: return type;
    }
  }
}

class _CadenceCard extends StatelessWidget {
  final CadenceRecommendation cadence;
  const _CadenceCard({required this.cadence});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                Text(l10n.homeworkCadence(cadence.cadenceCount, cadence.cadenceDays),
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
    final l10n = AppLocalizations.of(context)!;
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
          Text(l10n.yourAnswer, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
          const SizedBox(height: 6),
          Text(grade.original, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
          const SizedBox(height: 14),
          Text(l10n.aiPolish, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
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
                child: Text(l10n.scoreBar(pct), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(grade.feedback, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
            ],
          ),
          if (grade.errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.errorMarkLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade400)),
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
