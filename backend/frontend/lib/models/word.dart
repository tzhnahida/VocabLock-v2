import 'dart:convert';

class Word {
  final int id;
  final String word;
  final String reading;
  final String meaning;
  final String pos;
  final String language;
  final String source;
  final String confidence;
  final String level;
  final Map<String, dynamic>? detail;
  final String direction;
  final String status;
  final List<String> tags;
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
    this.level = '',
    this.detail,
    this.direction = '',
    this.status = 'active',
    this.tags = const [],
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
        level: json['level'] ?? '',
        detail: _parseDetail(json['detail']),
        direction: json['direction'] ?? '',
        status: json['status'] ?? 'active',
        tags: _parseTags(json['tags']),
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

  static Map<String, dynamic>? _parseDetail(dynamic d) {
    if (d == null) return null;
    if (d is Map<String, dynamic>) return d;
    if (d is String) {
      if (d.isEmpty) return null;
      try {
        final parsed = jsonDecode(d);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return null;
  }

  static List<String> _parseTags(dynamic tags) {
    if (tags == null) return const [];
    if (tags is List) return tags.map((e) => e.toString()).toList();
    if (tags is String) {
      if (tags.isEmpty) return const [];
      try {
        final parsed = jsonDecode(tags);
        if (parsed is List) return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
      return tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'reading': reading,
        'meaning': meaning,
        'pos': pos,
        'language': language,
        'direction': direction,
        'status': status,
        'tags': tags,
      };
}

class WordFieldConfig {
  final String key;
  final String label;
  final String type;
  final List<String>? options;

  const WordFieldConfig({
    required this.key,
    required this.label,
    this.type = 'text',
    this.options,
  });

  factory WordFieldConfig.fromJson(Map<String, dynamic> json) => WordFieldConfig(
        key: json['key'] ?? '',
        label: json['label'] ?? '',
        type: json['type'] ?? 'text',
        options: json['options'] != null ? List<String>.from(json['options']) : null,
      );

  static List<WordFieldConfig> listFromDLC(List<dynamic>? dlc) {
    if (dlc == null) return [];
    final result = <WordFieldConfig>[];
    for (final category in dlc) {
      if (category is Map<String, dynamic>) {
        final fields = category['fields'];
        if (fields is List) {
          for (final f in fields) {
            if (f is Map<String, dynamic>) {
              result.add(WordFieldConfig.fromJson(f));
            }
          }
        }
      }
    }
    return result;
  }
}
