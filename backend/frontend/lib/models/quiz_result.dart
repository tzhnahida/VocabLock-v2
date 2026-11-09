class SubmitResult {
  final bool correct;
  final double score;
  final String feedback;
  final String source;
  final DateTime? nextReviewAt;
  final List<PhonemeScore>? phonemes; // for read_word/read_sentence
  final String transcript; // ASR text for dialogue_speak
  final String expectedAnswer; // reference sentence for dialogue tasks
  final int logId; // review_log row id (for dispute marking)

  const SubmitResult({
    required this.correct,
    required this.score,
    this.feedback = '',
    this.source = 'exact',
    this.nextReviewAt,
    this.phonemes,
    this.transcript = '',
    this.expectedAnswer = '',
    this.logId = 0,
  });

  factory SubmitResult.fromJson(Map<String, dynamic> json) => SubmitResult(
        correct: json['correct'] ?? false,
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        feedback: json['feedback'] ?? '',
        source: json['source'] ?? 'exact',
        nextReviewAt: json['next_review_at'] != null ? DateTime.tryParse(json['next_review_at']) : null,
        phonemes: (json['phonemes'] as List<dynamic>?)
            ?.map((p) => PhonemeScore.fromJson(p as Map<String, dynamic>))
            .toList(),
        transcript: json['transcript'] ?? '',
        expectedAnswer: json['expected_answer'] ?? '',
        logId: (json['log_id'] as num?)?.toInt() ?? 0,
      );
}

class PhonemeScore {
  final String phoneme;
  final double score;

  const PhonemeScore({required this.phoneme, required this.score});

  factory PhonemeScore.fromJson(Map<String, dynamic> json) => PhonemeScore(
        phoneme: json['phoneme'] ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
      );
}
