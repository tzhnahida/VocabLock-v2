import '../models/question.dart';
import '../models/quiz_result.dart';
import '../models/stats.dart';
import 'api_client.dart';

class QuizApi {
  final ApiClient _client;

  QuizApi(this._client);

  Future<QuizProgress> getProgress() async {
    final r = await _client.get('/api/v1/quiz/progress');
    return QuizProgress.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Question?> getNext() async {
    final r = await _client.get('/api/v1/quiz/next');
    final data = r.data as Map<String, dynamic>;
    if (data['completed'] == true) return null;
    return Question.fromJson(data);
  }

  Future<SubmitResult> submit({
    required String questionId,
    required int wordId,
    required String questionType,
    required String answer,
  }) async {
    final r = await _client.post('/api/v1/quiz/submit', data: {
      'question_id': questionId,
      'word_id': wordId,
      'question_type': questionType,
      'answer': answer,
    });
    return SubmitResult.fromJson(r.data as Map<String, dynamic>);
  }

  Future<TodayStats> getTodayStats() async {
    final r = await _client.get('/api/v1/quiz/today-stats');
    return TodayStats.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> complete() async {
    final r = await _client.post('/api/v1/quiz/complete');
    return r.data as Map<String, dynamic>;
  }
}
