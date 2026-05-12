import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/quiz_result.dart';
import '../models/word.dart';
import '../models/session_summary.dart';
import '../theme/app_theme.dart';
import 'session_summary_view.dart';

class QuizSheet extends StatefulWidget {
  final Future<Question?> Function() onNextQuestion;
  final Future<SubmitResult?> Function({required String questionId, required int wordId, required String questionType, required String answer}) onSubmit;
  final Future<List<Word>> Function() onGetStudyWords;
  final Future<SessionSummary?> Function()? onSummarize;
  final VoidCallback onDone;
  final VoidCallback? onComplete;

  const QuizSheet({
    super.key,
    required this.onNextQuestion,
    required this.onSubmit,
    required this.onGetStudyWords,
    this.onSummarize,
    required this.onDone,
    this.onComplete,
  });

  @override
  State<QuizSheet> createState() => _QuizSheetState();
}

class _QuizSheetState extends State<QuizSheet> {
  static const int _maxQuestions = 10;

  bool _studyPhase = true;
  List<Word> _studyWords = [];
  int _answered = 0;
  int _correct = 0;

  Question? _question;
  bool _loading = true;
  String? _selectedAnswer;
  SubmitResult? _result;
  bool _submitting = false;
  bool _sessionComplete = false;

  // Summary
  bool _summarizing = false;
  SessionSummary? _summary;
  bool _showSummary = false;

  @override
  void initState() {
    super.initState();
    _loadStudyWords();
  }

  Future<void> _loadStudyWords() async {
    setState(() => _loading = true);
    try {
      _studyWords = await widget.onGetStudyWords();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _startQuiz() {
    setState(() { _studyPhase = false; _loading = true; });
    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _loading = true;
      _question = null;
      _selectedAnswer = null;
      _result = null;
    });
    final q = await widget.onNextQuestion();
    if (!mounted) return;
    setState(() {
      _question = q;
      _loading = false;
    });
  }

  Future<void> _submit(String answer) async {
    if (_question == null || _submitting) return;
    setState(() { _selectedAnswer = answer; _submitting = true; });
    final result = await widget.onSubmit(
      questionId: _question!.id,
      wordId: _question!.wordId,
      questionType: _question!.type.apiValue,
      answer: answer,
    );
    if (!mounted) return;
    _answered++;
    if (result != null && result.correct) _correct++;
    setState(() {
      _result = result;
      _submitting = false;
    });
  }

  void _nextQuestion() {
    if (_answered >= _maxQuestions) {
      setState(() => _sessionComplete = true);
      return;
    }
    _loadQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: _studyPhase ? _buildStudyPhase() : _buildQuizPhase(),
      ),
    );
  }

  Widget _buildStudyPhase() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('先学后考', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  Text('先浏览今日单词，点击 🔊 听发音，准备好后开始答题',
                      style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
              const Spacer(),
              TextButton(onPressed: widget.onDone, child: Text('关闭', style: TextStyle(color: AppTheme.textHint))),
            ],
          ),
          const SizedBox(height: 20),
          _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _studyWords.map((w) => _StudyCard(word: w)).toList(),
                  ),
                ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('开始测试 (${_studyWords.length} 题)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizPhase() {
    if (_loading) {
      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
    }
    if (_sessionComplete) {
      return _buildComplete();
    }
    if (_question == null) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text('All caught up!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: widget.onDone,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                child: Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    final q = _question!;
    final remaining = _maxQuestions - _answered;
    final pct = _answered > 0 ? (_correct / _answered * 100).toInt() : 0;
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
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(q.type.displayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
              ),
              const Spacer(),
              Text('第 $_answered/$_maxQuestions 题 · 正确 $_correct · $pct%',
                  style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ],
          ),
          const SizedBox(height: 16),
          Text(q.word, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Text(q.prompt, style: TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          if (q.options != null)
            ...q.options!.map((opt) => _OptionChip(
                  text: opt,
                  isSelected: _selectedAnswer == opt,
                  isCorrect: _selectedAnswer == opt ? _result?.correct : null,
                  enabled: _result == null,
                  onTap: () => _submit(opt),
                )),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _result!.correct ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(_result!.correct ? Icons.check_circle : Icons.error,
                      color: _result!.correct ? Colors.green : Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_result!.feedback,
                          style: TextStyle(fontSize: 14,
                              color: _result!.correct ? Colors.green.shade800 : Colors.red.shade800))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: remaining > 0
                    ? Text('下一题 ($remaining 题剩余)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))
                    : Text('查看结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _requestSummary() {
    if (widget.onSummarize == null || _summarizing) return;
    setState(() => _summarizing = true);
    widget.onSummarize!().then((s) {
      if (!mounted) return;
      setState(() {
        _summarizing = false;
        _summary = s;
        _showSummary = true;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _summarizing = false);
    });
  }

  Widget _buildComplete() {
    if (_showSummary) {
      return SessionSummaryView(
        summary: _summary,
        loading: false,
        onRetry: _requestSummary,
        onDismiss: () {
          widget.onComplete?.call();
          widget.onDone();
        },
      );
    }

    final pct = _answered > 0 ? (_correct / _answered * 100).toInt() : 0;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎉', style: TextStyle(fontSize: 64, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Text(pct >= 80 ? '恭喜完成今日学习！' : '继续加油！',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          const SizedBox(height: 8),
          Text('正确率: $pct%', style: TextStyle(fontSize: 18, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Text('正确 $_correct / $_answered 题', style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
          const SizedBox(height: 24),
          if (_summarizing)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text('AI 正在分析你的学习数据...', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                TextButton(onPressed: () { widget.onComplete?.call(); widget.onDone(); },
                    child: Text('跳过', style: TextStyle(color: AppTheme.textHint))),
              ],
            )
          else ...[
            if (widget.onSummarize != null)
              OutlinedButton.icon(
                onPressed: _requestSummary,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('查看 AI 学习总结'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                widget.onComplete?.call();
                widget.onDone();
              },
              child: Text('完成', style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  final Word word;
  const _StudyCard({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.isDark ? AppTheme.textPrimary : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(word.word, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
              Icon(Icons.volume_up, size: 18, color: AppTheme.primary),
            ],
          ),
          if (word.reading.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(word.reading, style: TextStyle(fontSize: 12, color: AppTheme.accent)),
          ],
          const SizedBox(height: 6),
          Text(word.meaning, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
          if (word.pos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(word.pos, style: TextStyle(fontSize: 10, color: AppTheme.primary)),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool? isCorrect;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionChip({
    required this.text,
    this.isSelected = false,
    this.isCorrect,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color? borderColor;
    if (isSelected && isCorrect == true) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
    } else if (isSelected && isCorrect == false) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
    } else if (isSelected) {
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade300;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor ?? AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor ?? Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                  child: Text(text,
                      style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
              if (isSelected && isCorrect == true) const Icon(Icons.check_circle, color: Colors.green, size: 20),
              if (isSelected && isCorrect == false) const Icon(Icons.cancel, color: Colors.red, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
