/// Learning-quality signals returned by GET /api/v1/stats/diagnostics.
///
/// Mirrors internal/db/diagnostics.go. Every window is "the last [days] days"
/// and every map may be empty — the backend never fabricates values, so an
/// absent section means "no rows yet", not "everything is fine".
class Diagnostics {
  final int days;

  /// error_category → number of wrong answers carrying that category.
  final Map<String, int> byCategory;

  /// phoneme → number of times it scored below the weak threshold.
  final Map<String, int> weakPhonemes;

  /// How many read-aloud rows carried structured phoneme data. Zero means the
  /// phoneme section is not merely empty but unmeasurable.
  final int phonemeSamples;

  final AIDisagreement? aiDisagreement;
  final Map<String, TypeRate> typeRates;
  final Coverage coverage;

  const Diagnostics({
    required this.days,
    this.byCategory = const {},
    this.weakPhonemes = const {},
    this.phonemeSamples = 0,
    this.aiDisagreement,
    this.typeRates = const {},
    this.coverage = const Coverage(),
  });

  factory Diagnostics.fromJson(Map<String, dynamic> json) {
    final ratesRaw = json['type_rates'];
    final rates = <String, TypeRate>{};
    if (ratesRaw is Map) {
      ratesRaw.forEach((k, v) {
        if (v is Map) {
          rates[k.toString()] = TypeRate.fromJson(v.cast<String, dynamic>());
        }
      });
    }

    final aiRaw = json['ai_disagreement'];
    final coverageRaw = json['coverage'];

    return Diagnostics(
      days: (json['days'] as num?)?.toInt() ?? 30,
      byCategory: _countMap(json['by_category']),
      weakPhonemes: _countMap(json['weak_phonemes']),
      phonemeSamples: (json['phoneme_samples'] as num?)?.toInt() ?? 0,
      aiDisagreement: aiRaw is Map ? AIDisagreement.fromJson(aiRaw.cast<String, dynamic>()) : null,
      typeRates: rates,
      coverage: coverageRaw is Map
          ? Coverage.fromJson(coverageRaw.cast<String, dynamic>())
          : const Coverage(),
    );
  }

  /// Total wrong answers in the window (the denominator of the category view).
  int get wrongAnswers => byCategory.values.fold(0, (a, b) => a + b);

  /// True when the backend has nothing to say yet. The panel uses this to show
  /// one honest empty state instead of five empty cards.
  bool get isEmpty =>
      wrongAnswers == 0 &&
      typeRates.isEmpty &&
      coverage.totalWords == 0 &&
      coverage.pendingReview == 0 &&
      coverage.longTermWords == 0 &&
      aiDisagreement == null &&
      phonemeSamples == 0;

  /// Wrong-answer categories, biggest first.
  List<MapEntry<String, int>> get categoriesDesc {
    final out = byCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  /// Weak phonemes, most frequent first.
  List<MapEntry<String, int>> get phonemesDesc {
    final out = weakPhonemes.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  /// Question types, weakest accuracy first — the list is meant to be acted on,
  /// so the worst row is the one you read first.
  List<MapEntry<String, TypeRate>> get typesByAccuracy {
    final out = typeRates.entries.toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));
    return out;
  }

  static Map<String, int> _countMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      if (v is num) out[k.toString()] = v.toInt();
    });
    return out;
  }
}

/// AI verdicts that contradict a deterministic match — the cheapest trust
/// signal available without human labelling.
class AIDisagreement {
  final int aiVerdicts;

  /// AI said "wrong" while the answer equalled the expected answer exactly.
  final int wrongButExactHit;
  final List<String> samples;

  const AIDisagreement({
    this.aiVerdicts = 0,
    this.wrongButExactHit = 0,
    this.samples = const [],
  });

  factory AIDisagreement.fromJson(Map<String, dynamic> json) => AIDisagreement(
        aiVerdicts: (json['ai_verdicts'] as num?)?.toInt() ?? 0,
        wrongButExactHit: (json['wrong_but_exact_hit'] as num?)?.toInt() ?? 0,
        samples: (json['samples'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  double get falseNegativeRate =>
      aiVerdicts > 0 ? wrongButExactHit / aiVerdicts : 0.0;
}

/// One question type's tally inside the window.
class TypeRate {
  final int total;
  final int correct;

  const TypeRate({this.total = 0, this.correct = 0});

  factory TypeRate.fromJson(Map<String, dynamic> json) => TypeRate(
        total: (json['total'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
      );

  double get accuracy => total > 0 ? correct / total : 0.0;
}

/// Dictionary size signals: everything known, everything verified long-term,
/// and everything still waiting for review.
class Coverage {
  final int totalWords;
  final int pendingReview;

  /// reps >= 4 && interval > 14 days (SM-2 long-term tier).
  final int longTermWords;

  const Coverage({
    this.totalWords = 0,
    this.pendingReview = 0,
    this.longTermWords = 0,
  });

  factory Coverage.fromJson(Map<String, dynamic> json) => Coverage(
        totalWords: (json['total_words'] as num?)?.toInt() ?? 0,
        pendingReview: (json['pending_review'] as num?)?.toInt() ?? 0,
        longTermWords: (json['long_term_words'] as num?)?.toInt() ?? 0,
      );

  /// Share of the active dictionary that reached long-term memory.
  double get longTermShare =>
      totalWords > 0 ? longTermWords / totalWords : 0.0;
}
