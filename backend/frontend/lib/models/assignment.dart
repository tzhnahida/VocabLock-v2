class Assignment {
  final String id;
  final String type;
  final String prompt;
  final String? context;
  final String? answer;
  final double? score;
  final String? feedback;
  final String status;

  const Assignment({
    required this.id,
    required this.type,
    required this.prompt,
    this.context,
    this.answer,
    this.score,
    this.feedback,
    this.status = 'pending',
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: (json['id'] ?? '').toString(),
        type: json['type'] ?? '',
        prompt: json['prompt'] ?? '',
        context: json['context'] as String?,
        answer: json['answer'] as String?,
        score: (json['score'] as num?)?.toDouble(),
        feedback: json['feedback'] as String?,
        status: json['status'] ?? 'pending',
      );

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
}

class AssignmentGrade {
  final String original;
  final String corrected;
  final double score;
  final String feedback;
  final List<String> errors;

  const AssignmentGrade({
    required this.original,
    required this.corrected,
    required this.score,
    this.feedback = '',
    this.errors = const [],
  });

  factory AssignmentGrade.fromJson(Map<String, dynamic> json) => AssignmentGrade(
        original: json['original'] ?? '',
        corrected: json['corrected'] ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        feedback: json['feedback'] ?? '',
        errors: (json['errors'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}

class CadenceRecommendation {
  final int cadenceDays;
  final int cadenceCount;
  final String reason;

  const CadenceRecommendation({
    required this.cadenceDays,
    required this.cadenceCount,
    this.reason = '',
  });

  factory CadenceRecommendation.fromJson(Map<String, dynamic> json) => CadenceRecommendation(
        cadenceDays: (json['cadence_days'] as num?)?.toInt() ?? 3,
        cadenceCount: (json['cadence_count'] as num?)?.toInt() ?? 2,
        reason: json['reason'] ?? '',
      );

  String get display => '每$cadenceDays天$cadenceCount题';
}

class AssignmentBatch {
  final List<Assignment> assignments;
  final bool pending;

  /// Why the batch is empty, when it is: "no_due" (cadence not reached yet),
  /// "ai_required" (no AI provider configured) or "generation_failed".
  /// Older backends send only a human-readable [message].
  final String? reason;

  /// RFC3339 timestamp of the next due assignment (or "now").
  final String? nextDueAt;

  const AssignmentBatch({
    required this.assignments,
    this.pending = false,
    this.reason,
    this.nextDueAt,
  });

  factory AssignmentBatch.fromJson(Map<String, dynamic> json) => AssignmentBatch(
        assignments: (json['assignments'] as List<dynamic>?)
                ?.map((e) => Assignment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        pending: json['pending'] ?? false,
        reason: json['reason'] as String?,
        nextDueAt: json['next_due_at'] as String?,
      );

  /// True while an already-generated assignment is waiting to be answered —
  /// the empty state should not claim "nothing due" in that case.
  bool get isEmpty => assignments.isEmpty;

  /// Next due time as a short local date-time (empty when unknown/unparsable).
  String get nextDueLabel {
    final raw = nextDueAt;
    if (raw == null || raw.isEmpty) return '';
    if (raw == 'now') return raw;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:$mm';
  }
}
