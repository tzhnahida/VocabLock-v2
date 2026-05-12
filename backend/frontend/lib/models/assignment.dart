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

  const AssignmentBatch({required this.assignments, this.pending = false});

  factory AssignmentBatch.fromJson(Map<String, dynamic> json) => AssignmentBatch(
        assignments: (json['assignments'] as List<dynamic>?)
                ?.map((e) => Assignment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        pending: json['pending'] ?? false,
      );

  bool get isEmpty => assignments.isEmpty;
}
