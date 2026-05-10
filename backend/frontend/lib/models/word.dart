class Word {
  final int id;
  final String word;
  final String reading;
  final String meaning;
  final String pos;
  final String language;
  final String source;
  final String confidence;
  final double easinessFactor;
  final int interval;
  final int repetitions;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewAt;
  final int totalAttempts;
  final int totalCorrect;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Word({
    required this.id,
    required this.word,
    this.reading = '',
    this.meaning = '',
    this.pos = '',
    this.language = '',
    this.source = '',
    this.confidence = '',
    this.easinessFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.nextReviewAt,
    this.lastReviewAt,
    this.totalAttempts = 0,
    this.totalCorrect = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        id: (json['id'] as num?)?.toInt() ?? 0,
        word: json['word'] ?? '',
        reading: json['reading'] ?? '',
        meaning: json['meaning'] ?? '',
        pos: json['pos'] ?? '',
        language: json['language'] ?? '',
        source: json['source'] ?? '',
        confidence: json['confidence'] ?? '',
        easinessFactor: (json['easiness_factor'] as num?)?.toDouble() ?? 2.5,
        interval: (json['interval'] as num?)?.toInt() ?? 0,
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        nextReviewAt: json['next_review_at'] != null ? DateTime.tryParse(json['next_review_at']) : null,
        lastReviewAt: json['last_review_at'] != null ? DateTime.tryParse(json['last_review_at']) : null,
        totalAttempts: (json['total_attempts'] as num?)?.toInt() ?? 0,
        totalCorrect: (json['total_correct'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'reading': reading,
        'meaning': meaning,
        'pos': pos,
        'language': language,
      };
}
