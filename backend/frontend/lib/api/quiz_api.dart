import '../models/question.dart';
import '../models/quiz_result.dart';
import '../models/stats.dart';
import '../models/assignment.dart';
import '../models/session_summary.dart';
import '../models/training_plan.dart';
import 'api_client.dart';

class QuizApi {
  final ApiClient _client;

  QuizApi(this._client);

  Future<QuizProgress> getProgress({String? language}) async {
    final r = await _client.get('/api/v1/quiz/progress', queryParameters: {
      if (language != null) 'language': language,
    });
    return QuizProgress.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Question?> getNext({String? language}) async {
    final r = await _client.get('/api/v1/quiz/next', queryParameters: {
      if (language != null) 'language': language,
    });
    final data = r.data as Map<String, dynamic>;
    if (data['completed'] == true) return null;
    return Question.fromJson(data);
  }

  Future<SubmitResult> submit({
    required String questionId,
    required int wordId,
    required String questionType,
    required String answer,
    String? language,
  }) async {
    final r = await _client.post('/api/v1/quiz/submit', data: {
      'question_id': questionId,
      'word_id': wordId,
      'question_type': questionType,
      'answer': answer,
      if (language != null) 'language': language,
    });
    return SubmitResult.fromJson(r.data as Map<String, dynamic>);
  }

  Future<TodayStats> getTodayStats({String? language}) async {
    final r = await _client.get('/api/v1/quiz/today-stats', queryParameters: {
      if (language != null) 'language': language,
    });
    return TodayStats.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> complete() async {
    final r = await _client.post('/api/v1/quiz/complete');
    return r.data as Map<String, dynamic>;
  }

  // —— Session ——

  Future<SessionSummary> summarize({String? language}) async {
    final r = await _client.post('/api/v1/quiz/summarize', data: {
      if (language != null) 'language': language,
    });
    return SessionSummary.fromJson(r.data as Map<String, dynamic>);
  }

  Future<TrainingPlan> getPlan({String? language}) async {
    final r = await _client.get('/api/v1/quiz/plan', queryParameters: {
      if (language != null) 'language': language,
    });
    return TrainingPlan.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> updateDirection(String direction) async {
    await _client.put('/api/v1/quiz/direction', data: {'direction': direction});
  }

  // —— Assignments ——

  Future<AssignmentBatch> getAssignment({String? language}) async {
    final r = await _client.get('/api/v1/quiz/assignment', queryParameters: {
      if (language != null) 'language': language,
    });
    return AssignmentBatch.fromJson(r.data as Map<String, dynamic>);
  }

  Future<AssignmentGrade> submitAssignment({
    required String assignmentId,
    required String answer,
  }) async {
    final r = await _client.post('/api/v1/quiz/assignment/submit', data: {
      'assignment_id': assignmentId,
      'answer': answer,
    });
    return AssignmentGrade.fromJson(r.data as Map<String, dynamic>);
  }

  Future<CadenceRecommendation> getCadence({String? language}) async {
    final r = await _client.get('/api/v1/quiz/assignment/cadence', queryParameters: {
      if (language != null) 'language': language,
    });
    return CadenceRecommendation.fromJson(r.data as Map<String, dynamic>);
  }
}
