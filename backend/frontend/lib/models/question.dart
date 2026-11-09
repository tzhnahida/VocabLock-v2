enum QuestionType {
  choice,
  fill,
  spelling,
  pronounce,
  meaning,
  reading,
  listening,
  readingComp,
  grammar,
  readWord,
  readSentence,
  dialogueWrite,
  dialogueSpeak;

  static QuestionType fromString(String s) {
    switch (s) {
      case 'choice':
        return QuestionType.choice;
      case 'fill':
        return QuestionType.fill;
      case 'spelling':
        return QuestionType.spelling;
      case 'pronounce':
        return QuestionType.pronounce;
      case 'meaning':
        return QuestionType.meaning;
      case 'reading':
        return QuestionType.reading;
      case 'listening':
        return QuestionType.listening;
      case 'reading_comp':
        return QuestionType.readingComp;
      case 'grammar':
        return QuestionType.grammar;
      case 'read_word':
        return QuestionType.readWord;
      case 'read_sentence':
        return QuestionType.readSentence;
      case 'dialogue_write':
        return QuestionType.dialogueWrite;
      case 'dialogue_speak':
        return QuestionType.dialogueSpeak;
      default:
        return QuestionType.choice;
    }
  }

  String get apiValue {
    switch (this) {
      case QuestionType.readingComp:
        return 'reading_comp';
      case QuestionType.readWord:
        return 'read_word';
      case QuestionType.readSentence:
        return 'read_sentence';
      case QuestionType.dialogueWrite:
        return 'dialogue_write';
      case QuestionType.dialogueSpeak:
        return 'dialogue_speak';
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
      case QuestionType.pronounce:
        return 'Pronounce';
      case QuestionType.meaning:
        return 'Meaning';
      case QuestionType.reading:
        return 'Reading';
      case QuestionType.listening:
        return 'Listening';
      case QuestionType.readingComp:
        return 'Reading Comp';
      case QuestionType.grammar:
        return 'Grammar';
      case QuestionType.readWord:
        return 'Read';
      case QuestionType.readSentence:
        return 'Speak';
      case QuestionType.dialogueWrite:
        return 'Dialogue';
      case QuestionType.dialogueSpeak:
        return 'Speak';
    }
  }

  bool get isAI =>
      this == listening ||
      this == readingComp ||
      this == grammar ||
      this == readSentence ||
      this == dialogueWrite ||
      this == dialogueSpeak;

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
  final String? subjectWord;
  final String? subjectReading;
  final String? subjectMeaning;

  const Question({
    required this.id,
    required this.type,
    required this.subjectType,
    required this.subjectId,
    required this.prompt,
    this.options,
    this.subjectWord,
    this.subjectReading,
    this.subjectMeaning,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] ?? '',
        type: QuestionType.fromString(json['type'] ?? 'choice'),
        subjectType: json['subject_type'] ?? 'word',
        subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
        prompt: json['prompt'] ?? '',
        options: (json['options'] as List<dynamic>?)?.cast<String>(),
        subjectWord: json['subject_word'] as String?,
        subjectReading: json['subject_reading'] as String?,
        subjectMeaning: json['subject_meaning'] as String?,
      );

  bool get isCompleted => id.isEmpty;

  /// Whether this question type should show a word preview card before answering.
  /// Listening questions must NOT show the word — the answer (correct meaning)
  /// is a choice on the same screen, and revealing the word text would give it
  /// away. Their audio is played via the listening play bar instead.
  bool get showWordPreview =>
      subjectType == 'word' && type != QuestionType.listening && !type.wordIsAnswer &&
      (subjectWord != null || subjectReading != null);
}

class GrammarPoint {
  final int id;
  final String title;
  final String explanation;
  final String example;
  final String detail;
  final String language;

  const GrammarPoint({
    required this.id,
    required this.title,
    required this.explanation,
    required this.example,
    this.detail = '',
    this.language = '',
  });

  factory GrammarPoint.fromJson(Map<String, dynamic> json) => GrammarPoint(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title'] ?? '',
        explanation: json['explanation'] ?? '',
        example: json['example'] ?? '',
        detail: json['detail'] ?? '',
        language: json['language'] ?? '',
      );
}
