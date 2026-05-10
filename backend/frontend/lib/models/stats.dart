class QuizProgress {
  final int reviewedToday;
  final int remaining;
  final int dailyTarget;

  const QuizProgress({
    required this.reviewedToday,
    required this.remaining,
    required this.dailyTarget,
  });

  factory QuizProgress.fromJson(Map<String, dynamic> json) => QuizProgress(
        reviewedToday: (json['reviewed_today'] as num?)?.toInt() ?? 0,
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
        dailyTarget: (json['daily_target'] as num?)?.toInt() ?? 20,
      );

  double get progress => dailyTarget > 0 ? reviewedToday / dailyTarget : 0.0;
}

class TodayStats {
  final int reviewed;
  final int correct;
  final double accuracy;

  const TodayStats({required this.reviewed, required this.correct, required this.accuracy});

  factory TodayStats.fromJson(Map<String, dynamic> json) {
    final reviewed = (json['reviewed'] as num?)?.toInt() ?? 0;
    final correct = (json['correct'] as num?)?.toInt() ?? 0;
    final accuracy = (json['accuracy'] as num?)?.toDouble() ?? (reviewed > 0 ? correct / reviewed : 0.0);
    return TodayStats(reviewed: reviewed, correct: correct, accuracy: accuracy);
  }
}

class DailyReport {
  final String date;
  final int wordsReviewed;
  final int wordsCorrect;
  final double accuracy;
  final int? timeSpentSec;
  final int? newWords;
  final int? masteredWords;

  const DailyReport({
    required this.date,
    required this.wordsReviewed,
    required this.wordsCorrect,
    required this.accuracy,
    this.timeSpentSec,
    this.newWords,
    this.masteredWords,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) => DailyReport(
        date: json['date'] ?? '',
        wordsReviewed: (json['words_reviewed'] as num?)?.toInt() ?? 0,
        wordsCorrect: (json['words_correct'] as num?)?.toInt() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
        timeSpentSec: (json['time_spent_sec'] as num?)?.toInt(),
        newWords: (json['new_words'] as num?)?.toInt(),
        masteredWords: (json['mastered_words'] as num?)?.toInt(),
      );
}
