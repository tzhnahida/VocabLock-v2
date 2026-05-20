enum QuestionType {
  choice,
  fill,
  spelling,
  reading,
  listening,
  readingComp,
  grammar;

  static QuestionType fromString(String s) {
    switch (s) {
      case 'choice':
        return QuestionType.choice;
      case 'fill':
        return QuestionType.fill;
      case 'spelling':
        return QuestionType.spelling;
      case 'reading':
        return QuestionType.reading;
      case 'listening':
        return QuestionType.listening;
      case 'reading_comp':
        return QuestionType.readingComp;
      case 'grammar':
        return QuestionType.grammar;
      default:
        return QuestionType.choice;
    }
  }

  String get apiValue {
    switch (this) {
      case QuestionType.readingComp:
        return 'reading_comp';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case QuestionType.choice:
        return 'Choice';
      case QuestionType.fill:
        return 'Fill';
      case QuestionType.spelling:
        return 'Spelling';
      case QuestionType.reading:
        return 'Reading';
      case QuestionType.listening:
        return 'Listening';
      case QuestionType.readingComp:
        return 'Reading Comp';
      case QuestionType.grammar:
        return 'Grammar';
    }
  }

  bool get isAI => this == listening || this == readingComp || this == grammar;

  /// Whether the answer IS the word itself — hide the word in the prompt for these types.
  bool get wordIsAnswer => this == fill || this == spelling;
}

class Question {
  final String id;
  final QuestionType type;
  final String subjectType;
  final int subjectId;
  final String prompt;
  final List<String>? options;

  const Question({
    required this.id,
    required this.type,
    required this.subjectType,
    required this.subjectId,
    required this.prompt,
    this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] ?? '',
        type: QuestionType.fromString(json['type'] ?? 'choice'),
        subjectType: json['subject_type'] ?? 'word',
        subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
        prompt: json['prompt'] ?? '',
        options: (json['options'] as List<dynamic>?)?.cast<String>(),
      );

  bool get isCompleted => id.isEmpty;
}

class GrammarPoint {
  final int id;
  final String title;
  final String explanation;
  final String example;
  final String language;

  const GrammarPoint({
    required this.id,
    required this.title,
    required this.explanation,
    required this.example,
    this.language = '',
  });

  factory GrammarPoint.fromJson(Map<String, dynamic> json) => GrammarPoint(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title'] ?? '',
        explanation: json['explanation'] ?? '',
        example: json['example'] ?? '',
        language: json['language'] ?? '',
      );
}
