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
}

class Question {
  final String id;
  final QuestionType type;
  final int wordId;
  final String word;
  final String reading;
  final String prompt;
  final List<String>? options;

  const Question({
    required this.id,
    required this.type,
    required this.wordId,
    required this.word,
    required this.reading,
    required this.prompt,
    this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] ?? '',
        type: QuestionType.fromString(json['type'] ?? 'choice'),
        wordId: (json['word_id'] as num?)?.toInt() ?? 0,
        word: json['word'] ?? '',
        reading: json['reading'] ?? '',
        prompt: json['prompt'] ?? '',
        options: (json['options'] as List<dynamic>?)?.cast<String>(),
      );

  bool get isCompleted => id.isEmpty;
}
