import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../models/question.dart';
import '../models/quiz_result.dart';
import '../models/word.dart';
import '../models/session_summary.dart';
import '../theme/app_theme.dart';
import '../utils/audio_player.dart';
import '../widgets/session_summary_view.dart';

enum _Phase { overview, learning, quiz, complete }

class QuizSessionPage extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function() onSessionStart;
  final Future<Question?> Function() onNextQuestion;
  final Future<SubmitResult?> Function({required String questionId, required String subjectType, required int subjectId, required String questionType, required String answer, String? audio}) onSubmit;
  final Future<List<Word>> Function() onGetStudyWords;
  final Future<List<GrammarPoint>> Function()? onGetStudyGrammar;
  final Future<SessionSummary?> Function()? onSummarize;
  final VoidCallback? onComplete;
  final Future<void> Function(int wordId) onPlayWordAudio;
  final Future<void> Function(String text) onPlayTextAudio;
  final Future<List<WordFieldConfig>> Function()? onGetFieldConfig;

  const QuizSessionPage({
    super.key,
    required this.onSessionStart,
    required this.onNextQuestion,
    required this.onSubmit,
    required this.onGetStudyWords,
    required this.onPlayWordAudio,
    required this.onPlayTextAudio,
    this.onGetStudyGrammar,
    this.onSummarize,
    this.onComplete,
    this.onGetFieldConfig,
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
  bool _dailyCompleted = false;
  bool _preparing = false;
  Timer? _preparingTimer;

  // Learning phase
  List<Word> _studyWords = [];
  List<GrammarPoint> _studyGrammar = [];
  List<WordFieldConfig>? _fieldConfig;
  bool _loadingStudy = true;
  int _currentPage = 0;
  late final PageController _pageCtrl = PageController();

  // Quiz phase
  Question? _question;
  bool _loadingQuestion = true;
  bool _showWordPreview = false;
  String? _selectedAnswer;
  SubmitResult? _result;
  bool _submitting = false;
  int _answered = 0;
  int _correct = 0;

  final _textController = TextEditingController();
  final _textFocus = FocusNode();

  // Recording state (for read_word / read_sentence)
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Uint8List? _recordedBytes;
  String? _recordedPath;
  final _playbackPlayer = AppAudioPlayer();
  List<PhonemeScore>? _phonemeScores;
  // Complete phase
  bool _summarizing = false;
  SessionSummary? _summary;
  bool _showSummary = false;

  @override
  void dispose() {
    _preparingTimer?.cancel();
    _textController.dispose();
    _textFocus.dispose();
    _pageCtrl.dispose();
    _recorder.dispose();
    _playbackPlayer.dispose();
    super.dispose();
  }

  // ——— Recording ———

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    _recordedBytes = null;
    _phonemeScores = null;
    final tmpDir = Directory.systemTemp;
    final recordPath = '${tmpDir.path}/vocablock_read_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 256000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: recordPath,
    );
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return;
    final file = File(path);
    final bytes = await file.readAsBytes();
    debugPrint('[read-aloud] stopped recording path=$path bytes=${bytes.length}');
    setState(() {
      _isRecording = false;
      _recordedBytes = bytes;
      _recordedPath = path;
    });
  }

  Future<void> _playRecording() async {
    if (_recordedPath == null) return;
    await _playbackPlayer.playFile(_recordedPath!);
  }

  Future<void> _submitRecording() async {
    if (_recordedBytes == null || _question == null || _submitting) return;
    final bytes = _recordedBytes!;
    debugPrint('[read-aloud] submitting qtype=${_question!.type.apiValue} bytes=${bytes.length} base64Len=${base64Encode(bytes).length}');
    setState(() => _submitting = true);
    final audio = base64Encode(bytes);
    final result = await widget.onSubmit(
      questionId: _question!.id,
      subjectType: _question!.subjectType,
      subjectId: _question!.subjectId,
      questionType: _question!.type.apiValue,
      answer: '',
      audio: audio,
    );
    debugPrint('[read-aloud] response correct=${result?.correct} score=${result?.score} phonemes=${result?.phonemes?.length}');
    if (!mounted) return;
    _answered++;
    if (result != null && result.correct) _correct++;
    setState(() {
      _result = result;
      _phonemeScores = result?.phonemes;
      _submitting = false;
    });
  }

  void _retryRecording() {
    setState(() {
      _recordedBytes = null;
      _recordedPath = null;
      _phonemeScores = null;
      _result = null;
    });
  }

  Future<void> _skipReading() async {
    if (_question == null || _submitting) return;
    debugPrint('[read-aloud] skip clicked qtype=${_question!.type.apiValue}');
    setState(() => _submitting = true);
    final result = await widget.onSubmit(
      questionId: _question!.id,
      subjectType: _question!.subjectType,
      subjectId: _question!.subjectId,
      questionType: _question!.type.apiValue,
      answer: '',
      audio: '',  // empty audio = skip
    );
    if (!mounted) return;
    _answered++;
    if (result != null && result.correct) _correct++;
    setState(() {
      _result = result;
      _submitting = false;
    });
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
          _dailyCompleted = counts['daily_completed'] == true;
          _preparing = counts['preparing'] == true;
        });
        if (_preparing) {
          _preparingTimer?.cancel();
          _preparingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) _loadOverview();
          });
        } else {
          _preparingTimer?.cancel();
        }
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
    if (widget.onGetFieldConfig != null) {
      try {
        _fieldConfig = await widget.onGetFieldConfig!();
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingStudy = false);

    // Auto-play first word when study cards appear
    if (mounted && _phase == _Phase.learning && _studyWords.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _studyWords.isNotEmpty) {
          widget.onPlayWordAudio(_studyWords[0].id);
        }
      });
    }
  }

  void _startLearning() {
    if (_dailyCompleted) {
      _dismiss();
      return;
    }
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
      _showWordPreview = q != null && q.showWordPreview;
      // Reset recording state for new question
      _recordedBytes = null;
      _recordedPath = null;
      _phonemeScores = null;
      _isRecording = false;
    });

    // Auto-play audio for choice questions so the user hears
    // the correct pronunciation while picking the meaning.
    if (q != null && q.type == QuestionType.choice && q.subjectType == 'word') {
      widget.onPlayWordAudio(q.subjectId);
    }
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

  Widget _buildReadAloudUI(Question q) {
    final word = q.subjectWord ?? q.prompt.replaceAll(RegExp(r'^[^:]+:\s*'), '');
    final isReadWord = q.type == QuestionType.readWord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Text(word, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        if (isReadWord && q.subjectReading != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(q.subjectReading!, style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
          ),
        const SizedBox(height: 24),
        // Record button
        if (_result == null && !_isRecording)
          ElevatedButton.icon(
            onPressed: _recordedBytes == null ? () => _startRecording() : null,
            icon: Icon(_recordedBytes == null ? Icons.mic : Icons.check, size: 22),
            label: Text(_recordedBytes == null ? '开始录音' : '已录制'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _recordedBytes == null ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        // Recording indicator
        if (_isRecording)
          Column(
            children: [
              Icon(Icons.mic, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('正在录音...', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _stopRecording(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('停止录音'),
              ),
            ],
          ),
        // Result feedback
        if (_result != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _result!.correct ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _result!.correct ? Colors.green : Colors.orange, width: 1.5),
            ),
            child: Column(
              children: [
                Text(
                  _result!.correct ? 'PASS' : 'NEED WORK',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _result!.correct ? Colors.green.shade700 : Colors.orange.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  '总分 ${(_result!.score * 100).round()}% (需 ≥ ${isReadWord ? 50 : 40}%)',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                if (_phonemeScores != null && _phonemeScores!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10, runSpacing: 8,
                    children: _phonemeScores!.map((p) {
                      final passed = p.score >= 0.45;
                      return Container(
                        width: 56,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: passed ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: passed ? Colors.green : Colors.red, width: 2),
                        ),
                        child: Column(
                          children: [
                            Text(p.phoneme, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: passed ? Colors.green.shade700 : Colors.red.shade700)),
                            const SizedBox(height: 2),
                            Text('${(p.score * 100).round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: passed ? Colors.green.shade600 : Colors.red.shade600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _playRecording,
                icon: const Icon(Icons.play_circle, size: 36),
                color: AppTheme.primary,
                tooltip: '试听',
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _retryRecording,
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('重录'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Action buttons
        if (_result == null)
          Column(
            children: [
              if (_recordedBytes != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _playRecording,
                      icon: const Icon(Icons.play_circle, size: 36),
                      color: AppTheme.primary,
                      tooltip: '试听',
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _retryRecording,
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('重录'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submitting ? null : () => _submitRecording(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('提交'),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _submitting ? null : () => _skipReading(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: Text('不会念，告诉我答案', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildWordPreview(Question q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(q.subjectWord ?? '', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          if (q.subjectReading != null && q.subjectReading!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(q.subjectReading!, style: TextStyle(fontSize: 18, color: AppTheme.accent)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PlayButton(onTap: () => widget.onPlayWordAudio(q.subjectId)),
              const SizedBox(width: 12),
              Text('先听读，再作答', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
            ],
          ),
        ],
      ),
    );
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

    if (_preparing) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(height: 24),
              Text('AI 正在准备学习内容...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('请稍候，首次生成可能需要 10-20 秒', style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
            ],
          ),
        ),
      );
    }

    if (_dailyCompleted) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text('今日学习已完成', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _dismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('返回', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
            ],
          ),
        ),
      );
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
    if (_loadingStudy) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalCards = _studyWords.length + _studyGrammar.length;
    if (totalCards == 0) {
      _startQuiz();
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: AppTheme.primary, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('学习新内容', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text('${_currentPage + 1} / $totalCards',
                        style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: _startQuiz,
                  child: const Text('跳过'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: totalCards,
                onPageChanged: (i) {
                        setState(() => _currentPage = i);
                        if (i < _studyWords.length) {
                          widget.onPlayWordAudio(_studyWords[i].id);
                        }
                      },
                itemBuilder: (context, index) {
                  if (index < _studyWords.length) {
                    final w = _studyWords[index];
                    return _StudyCard(
                      word: w,
                      fieldConfig: _fieldConfig,
                      onPlayWord: () => widget.onPlayWordAudio(w.id),
                      onPlayText: widget.onPlayTextAudio,
                    );
                  } else {
                    final g = _studyGrammar[index - _studyWords.length];
                    return _GrammarCard(grammar: g);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            // Navigation: prev — dots — next
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28),
                  onPressed: _currentPage > 0 ? () => _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
                ),
                ...List.generate(totalCards, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentPage ? AppTheme.primary : AppTheme.textHint.withValues(alpha: 0.3),
                  ),
                )),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 28),
                  onPressed: _currentPage < totalCards - 1 ? () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            Text('今日学习完成！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('已完成 $_answered 题 · 正确 $_correct 题',
                style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _dismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  key: ValueKey(q.id),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showWordPreview) _buildWordPreview(q),
                    Text(q.prompt,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 24),
                    if (q.options != null) ...[
                      ...q.options!.map((opt) => _OptionChip(
                            text: opt,
                            isSelected: _selectedAnswer == opt,
                            isCorrect: _selectedAnswer == opt ? _result?.correct : null,
                            enabled: _result == null,
                            onTap: () => _submit(opt),
                          )),
                      if (_result == null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => _submit(''),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: Text('我不知道，告诉我答案', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                          ),
                        ),
                      ],
                    ]
                    else if (q.type == QuestionType.readWord || q.type == QuestionType.readSentence)
                      _buildReadAloudUI(q)
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
                      if (_result == null) ...[
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
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => _submit(''),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: Text('我不知道，告诉我答案', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                          ),
                        ),
                      ],
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
  final List<WordFieldConfig>? fieldConfig;
  final Future<void> Function() onPlayWord;
  final Future<void> Function(String text) onPlayText;

  const _StudyCard({
    required this.word,
    this.fieldConfig,
    required this.onPlayWord,
    required this.onPlayText,
  });

  // Layout categories for smart field placement
  static const _badgeKeys = {'pos', 'level', 'syllable_count', 'register', 'pitch_accent'};
  static const _exampleKeys = {'example_sentence'};
  static const _playableFields = {'word', 'morphology', 'collocation', 'example_sentence'};
  static const _fallbackFieldOrder = [
    'meaning', 'pos', 'level', 'syllable_count',
    'morphology', 'syntax', 'collocation', 'register',
    'etymology', 'example_sentence',
    'pitch_accent', 'conjugation_class', 'case_government',
    'orthographic_variants', 'keigo_level',
  ];
  static const _fallbackLabels = {
    'meaning': '核心释义', 'pos': '词性', 'level': '等级', 'syllable_count': '音拍数',
    'morphology': '形态变化', 'syntax': '句法功能', 'collocation': '常用搭配', 'register': '语体/语域',
    'etymology': '词源/构词', 'example_sentence': '例句',
    'pitch_accent': '高低アクセント', 'conjugation_class': '活用类型', 'case_government': '格支配',
    'orthographic_variants': '表記揺れ', 'keigo_level': '敬語階層',
  };

  @override
  Widget build(BuildContext context) {
    final w = word;
    final detail = Map<String, dynamic>.from(w.detail ?? {});
    detail['meaning'] = w.meaning.isNotEmpty ? w.meaning : detail['meaning'];
    detail['pos'] = w.pos.isNotEmpty ? w.pos : detail['pos'];
    detail['level'] = w.level.isNotEmpty ? w.level : detail['level'];

    final List<String> fieldOrder;
    final Map<String, String> labels;
    if (fieldConfig != null && fieldConfig!.isNotEmpty) {
      fieldOrder = [];
      labels = {};
      for (final fc in fieldConfig!) {
        if (fc.key.isNotEmpty) {
          fieldOrder.add(fc.key);
          labels[fc.key] = fc.label;
        }
      }
    } else {
      fieldOrder = _fallbackFieldOrder;
      labels = _fallbackLabels;
    }

    // Categorize available fields
    final badges = <Widget>[];
    final gridFields = <Widget>[];
    Widget? exampleCard;
    final fullFields = <Widget>[];

    // Meaning always gets a prominent spot (not a badge)
    final meaning = detail['meaning']?.toString() ?? '';
    if (meaning.isNotEmpty) {
      badges.add(_Badge(meaning, AppTheme.accent));
    }

    for (final key in fieldOrder) {
      if (key == 'meaning') continue; // handled above
      final val = (detail[key] ?? '').toString();
      if (val.isEmpty) continue;
      if (_badgeKeys.contains(key)) {
        badges.add(_Badge(labels[key]?.isNotEmpty == true ? '${labels[key]}: $val' : val, AppTheme.primary));
      } else if (_exampleKeys.contains(key)) {
        final play = _playableFields.contains(key);
        exampleCard = _ExampleBlock(text: val, onPlay: play ? () => onPlayText(val) : null);
      } else if (_playableFields.contains(key)) {
        // Playable grid item
        gridFields.add(_GridCell(label: labels[key] ?? key, value: val, onPlay: () => onPlayText(val)));
      } else {
        // Default: try grid, fallback to full-width
        if (val.length < 30) {
          gridFields.add(_GridCell(label: labels[key] ?? key, value: val));
        } else {
          fullFields.add(_CompactRow(label: labels[key] ?? key, value: val));
        }
      }
    }

    // Pad grid to even count
    if (gridFields.length.isOdd) gridFields.add(const SizedBox(width: 1));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // ── Hero: word + reading ──
          Text(w.word, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          if (w.reading.isNotEmpty)
            Text(w.reading, style: TextStyle(fontSize: 20, color: AppTheme.accent)),
          const SizedBox(height: 10),
          _PlayButton(onTap: onPlayWord),
          const SizedBox(height: 20),
          // ── Badge row ──
          if (badges.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: badges),
            const SizedBox(height: 20),
          ],
          // ── Example sentence (highlighted) ──
          if (exampleCard != null) ...[exampleCard, const SizedBox(height: 16)],
          // ── 2-column grid ──
          if (gridFields.isNotEmpty)
            ..._buildGrid(gridFields),
          // ── Full-width compact fields ──
          if (fullFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...fullFields,
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildGrid(List<Widget> cells) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            const SizedBox(width: 10),
            if (i + 1 < cells.length) Expanded(child: cells[i + 1]) else const Spacer(),
          ],
        ),
      ));
    }
    return rows;
  }
}

// ── Study card sub-widgets ──

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ExampleBlock extends StatelessWidget {
  final String text;
  final VoidCallback? onPlay;
  const _ExampleBlock({required this.text, this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.format_quote, size: 18, color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary, height: 1.5)),
          ),
          if (onPlay != null) ...[const SizedBox(width: 8), _PlayButton(onTap: onPlay!)],
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onPlay;
  const _GridCell({required this.label, required this.value, this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textHint))),
              if (onPlay != null) _PlayButton(onTap: onPlay!),
            ],
          ),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  final String label;
  final String value;
  const _CompactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textHint))),
            const SizedBox(width: 8),
            Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _playing = false;

  Future<void> _tap() async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      widget.onTap();
      if (mounted) await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: SizedBox(
        width: 24, height: 24,
        child: _playing
            ? Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)))
            : Icon(Icons.volume_up, size: 20, color: AppTheme.primary),
      ),
    );
  }
}

class _GrammarCard extends StatelessWidget {
  final GrammarPoint grammar;
  const _GrammarCard({required this.grammar});

  Map<String, dynamic> _detail() {
    if (grammar.detail.isEmpty || grammar.detail == '{}') return {};
    try { return const JsonDecoder().convert(grammar.detail) as Map<String, dynamic>; } catch (_) { return {}; }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail();
    final pattern = d['pattern']?.toString() ?? '';
    final usage = d['usage_notes']?.toString() ?? '';
    final formality = d['formality_level']?.toString() ?? '';
    final mistakes = d['common_mistakes']?.toString() ?? '';
    final related = d['related_points']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, size: 28, color: Colors.red.shade400),
              const SizedBox(width: 12),
              Expanded(child: Text(grammar.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
            ],
          ),
          const SizedBox(height: 20),
          // Explanation
          if (grammar.explanation.isNotEmpty)
            Text(grammar.explanation, style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, height: 1.6)),
          // Pattern
          if (pattern.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.isDark ? Colors.white24 : Colors.grey.shade300),
              ),
              child: Text(pattern, style: TextStyle(fontSize: 16, fontFamily: 'monospace', color: AppTheme.textPrimary)),
            ),
          ],
          // Example
          if (grammar.example.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
              ),
              child: Text(grammar.example, style: TextStyle(fontSize: 18, color: AppTheme.textPrimary, height: 1.5)),
            ),
          ],
          // Usage notes
          if (usage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(usage, style: TextStyle(fontSize: 14, color: AppTheme.textHint, height: 1.5)),
          ],
          // DLC tags
          if (formality.isNotEmpty || mistakes.isNotEmpty || related.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (formality.isNotEmpty) _GBadge(formality, Colors.teal),
              if (mistakes.isNotEmpty) _GBadge('⚠ $mistakes', Colors.orange),
              if (related.isNotEmpty) _GBadge('→ $related', Colors.blue),
            ]),
          ],
        ],
      ),
    );
  }
}

class _GBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _GBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 13, color: color)),
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
