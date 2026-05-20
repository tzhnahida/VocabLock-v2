import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/quiz_result.dart';
import '../models/word.dart';
import '../models/session_summary.dart';
import '../theme/app_theme.dart';
import '../widgets/session_summary_view.dart';

enum _Phase { overview, learning, quiz, complete }

class QuizSessionPage extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function() onSessionStart;
  final Future<Question?> Function() onNextQuestion;
  final Future<SubmitResult?> Function({required String questionId, required String subjectType, required int subjectId, required String questionType, required String answer}) onSubmit;
  final Future<List<Word>> Function() onGetStudyWords;
  final Future<List<GrammarPoint>> Function()? onGetStudyGrammar;
  final Future<SessionSummary?> Function()? onSummarize;
  final VoidCallback? onComplete;

  const QuizSessionPage({
    super.key,
    required this.onSessionStart,
    required this.onNextQuestion,
    required this.onSubmit,
    required this.onGetStudyWords,
    this.onGetStudyGrammar,
    this.onSummarize,
    this.onComplete,
  });

  @override
  State<QuizSessionPage> createState() => _QuizSessionPageState();
}

class _QuizSessionPageState extends State<QuizSessionPage> {
  _Phase _phase = _Phase.overview;
  bool _loadingOverview = true;

  // Session counts from POST /quiz/session/start
  int _newWords = 0;
  int _newGrammar = 0;
  int _reviewWords = 0;
  int _reviewGrammar = 0;

  // Learning phase
  List<Word> _studyWords = [];
  List<GrammarPoint> _studyGrammar = [];
  bool _loadingStudy = true;

  // Quiz phase
  Question? _question;
  bool _loadingQuestion = true;
  String? _selectedAnswer;
  SubmitResult? _result;
  bool _submitting = false;
  int _answered = 0;
  int _correct = 0;

  final _textController = TextEditingController();
  final _textFocus = FocusNode();

  // Complete phase
  bool _summarizing = false;
  SessionSummary? _summary;
  bool _showSummary = false;

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _loadOverview();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _loadOverview() async {
    setState(() => _loadingOverview = true);
    try {
      final counts = await widget.onSessionStart();
      if (counts != null && mounted) {
        setState(() {
          _newWords = (counts['new_words'] as num?)?.toInt() ?? 0;
          _newGrammar = (counts['new_grammar'] as num?)?.toInt() ?? 0;
          _reviewWords = (counts['review_words'] as num?)?.toInt() ?? 0;
          _reviewGrammar = (counts['review_grammar'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingOverview = false);
  }

  Future<void> _loadStudyWords() async {
    setState(() => _loadingStudy = true);
    try {
      _studyWords = await widget.onGetStudyWords();
    } catch (_) {}
    if (widget.onGetStudyGrammar != null) {
      try {
        _studyGrammar = await widget.onGetStudyGrammar!();
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingStudy = false);
  }

  void _startLearning() {
    final hasNew = _newWords + _newGrammar > 0;
    if (hasNew) {
      _loadStudyWords();
      setState(() => _phase = _Phase.learning);
    } else {
      setState(() { _phase = _Phase.quiz; _loadingQuestion = true; });
      _loadQuestion();
    }
  }

  void _startQuiz() {
    setState(() { _phase = _Phase.quiz; _loadingQuestion = true; });
    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    _textController.clear();
    setState(() {
      _loadingQuestion = true;
      _question = null;
      _selectedAnswer = null;
      _result = null;
    });
    final q = await widget.onNextQuestion();
    if (!mounted) return;
    setState(() {
      _question = q;
      _loadingQuestion = false;
    });
  }

  Future<void> _submit(String answer) async {
    if (_question == null || _submitting) return;
    setState(() { _selectedAnswer = answer; _submitting = true; });
    final result = await widget.onSubmit(
      questionId: _question!.id,
      subjectType: _question!.subjectType,
      subjectId: _question!.subjectId,
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
    _loadQuestion();
  }

  void _dismiss() {
    widget.onComplete?.call();
    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        title: Text('Quiz', style: TextStyle(color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: switch (_phase) {
        _Phase.overview => _buildOverview(),
        _Phase.learning => _buildLearning(),
        _Phase.quiz => _buildQuiz(),
        _Phase.complete => _buildComplete(),
      },
    );
  }

  // ─── Overview ────────────────────────────────────────────

  Widget _buildOverview() {
    if (_loadingOverview) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalNew = _newWords + _newGrammar;
    final totalReview = _reviewWords + _reviewGrammar;
    final total = totalNew + totalReview;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories, size: 64, color: AppTheme.primary),
              const SizedBox(height: 24),
              Text('今日学习', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('SM-2 智能复习 + AI 策展新内容',
                  style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
              const SizedBox(height: 40),
              _CountRow(label: '新单词', count: _newWords, icon: Icons.add_circle, color: Colors.green),
              _CountRow(label: '新语法', count: _newGrammar, icon: Icons.add_circle, color: Colors.green),
              _CountRow(label: '复习单词', count: _reviewWords, icon: Icons.refresh, color: AppTheme.primary),
              _CountRow(label: '复习语法', count: _reviewGrammar, icon: Icons.refresh, color: AppTheme.primary),
              const Divider(height: 32),
              Text('共 $total 题 · 预估 ${(total * 1.5).ceil()} 分钟',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: total > 0 ? _startLearning : _dismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(total > 0 ? '开始学习' : '暂无内容，返回',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Learning ────────────────────────────────────────────

  Widget _buildLearning() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: AppTheme.primary, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('学习新内容', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text('浏览今日新学单词和语法，准备好后开始答题',
                        style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loadingStudy
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._studyWords.map((w) => _StudyCard(word: w)),
                          ..._studyGrammar.map((g) => _GrammarCard(grammar: g)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('开始答题 (${_studyWords.length + _studyGrammar.length + _reviewWords + _reviewGrammar} 题)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quiz ────────────────────────────────────────────────

  Widget _buildQuiz() {
    if (_loadingQuestion) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_question == null || _question!.isCompleted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text('本轮完成！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('已完成 $_answered 题 · 正确 $_correct 题',
                style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _answered = 0;
                _correct = 0;
                _loadOverview();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('开始下一轮'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _dismiss,
              child: Text('完成', style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
            ),
          ],
        ),
      );
    }

    final q = _question!;
    final pct = _answered > 0 ? (_correct / _answered * 100).toInt() : 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
                  child: Text(q.type.displayName,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: q.subjectType == 'grammar'
                        ? Colors.red.withValues(alpha: 0.08)
                        : Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(q.subjectType,
                      style: TextStyle(fontSize: 11,
                          color: q.subjectType == 'grammar' ? Colors.red.shade400 : Colors.blue.shade400)),
                ),
                const Spacer(),
                Text('$_answered 题 · $_correct ✓ · $pct%',
                    style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.prompt,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 24),
                    if (q.options != null)
                      ...q.options!.map((opt) => _OptionChip(
                            text: opt,
                            isSelected: _selectedAnswer == opt,
                            isCorrect: _selectedAnswer == opt ? _result?.correct : null,
                            enabled: _result == null,
                            onTap: () => _submit(opt),
                          ))
                    else ...[
                      TextField(
                        controller: _textController,
                        focusNode: _textFocus,
                        enabled: _result == null,
                        onSubmitted: _result == null ? (v) { if (v.trim().isNotEmpty) _submit(v.trim()); } : null,
                        decoration: InputDecoration(
                          hintText: '输入你的答案...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: AppTheme.cardBg,
                        ),
                        style: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      if (_result == null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _textController.text.trim().isNotEmpty
                                ? () => _submit(_textController.text.trim())
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('提交', style: TextStyle(fontSize: 16, color: AppTheme.textPrimary)),
                          ),
                        ),
                    ],
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
                    ],
                  ],
                ),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('下一题', style: TextStyle(fontSize: 16, color: AppTheme.textPrimary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Complete ────────────────────────────────────────────

  Widget _buildComplete() {
    if (_showSummary) {
      return SessionSummaryView(
        summary: _summary,
        loading: false,
        onRetry: _requestSummary,
        onDismiss: _dismiss,
      );
    }

    final pct = _answered > 0 ? (_correct / _answered * 100).toInt() : 0;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(pct >= 80 ? '\u{1F389}' : '\u{1F4AA}',
                  style: TextStyle(fontSize: 64, color: AppTheme.textPrimary)),
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
                  onPressed: _dismiss,
                  child: Text('完成', style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────

class _CountRow extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _CountRow({required this.label, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: AppTheme.textPrimary))),
          Text('$count 题', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
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

class _GrammarCard extends StatelessWidget {
  final GrammarPoint grammar;
  const _GrammarCard({required this.grammar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: Colors.red.shade400),
              const SizedBox(width: 6),
              Expanded(child: Text(grammar.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
            ],
          ),
          const SizedBox(height: 8),
          Text(grammar.explanation, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis),
          if (grammar.example.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(grammar.example, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textPrimary)),
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
    required this.isSelected,
    this.isCorrect,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (!enabled) {
      bg = AppTheme.cardBg;
    } else if (isSelected) {
      bg = AppTheme.primary.withValues(alpha: 0.15);
    } else {
      bg = AppTheme.cardBg;
    }

    Color border;
    if (isCorrect == true) {
      border = Colors.green;
    } else if (isCorrect == false) {
      border = Colors.red;
    } else if (isSelected) {
      border = AppTheme.primary;
    } else {
      border = Colors.grey.shade200;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Text(text, style: TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
        ),
      ),
    );
  }
}
