class SubmitResult {
  final bool correct;
  final double score;
  final String feedback;
  final String source;
  final DateTime? nextReviewAt;

  const SubmitResult({
    required this.correct,
    required this.score,
    this.feedback = '',
    this.source = 'exact',
    this.nextReviewAt,
  });

  factory SubmitResult.fromJson(Map<String, dynamic> json) => SubmitResult(
        correct: json['correct'] ?? false,
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        feedback: json['feedback'] ?? '',
        source: json['source'] ?? 'exact',
        nextReviewAt: json['next_review_at'] != null ? DateTime.tryParse(json['next_review_at']) : null,
      );
}
