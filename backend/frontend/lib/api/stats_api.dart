import '../models/diagnostics.dart';
import '../models/stats.dart';
import 'api_client.dart';

class StatsApi {
  final ApiClient _client;

  StatsApi(this._client);

  Future<Map<String, int>> getHeatmap({int days = 90, String? language}) async {
    final r = await _client.get('/api/v1/stats/heatmap', queryParameters: {
      'days': days,
      if (language != null) 'language': language,
    });
    final data = r.data as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<int> getStreak({String? language}) async {
    final r = await _client.get('/api/v1/stats/streak', queryParameters: {
      if (language != null) 'language': language,
    });
    final data = r.data as Map<String, dynamic>;
    return (data['streak'] as num?)?.toInt() ?? 0;
  }

  Future<DailyReport> getDailyReport({String? language}) async {
    final r = await _client.get('/api/v1/stats/daily-report', queryParameters: {
      if (language != null) 'language': language,
    });
    return DailyReport.fromJson(r.data as Map<String, dynamic>);
  }

  /// Learning-quality diagnostics: error causes, weak phonemes, AI-vs-
  /// deterministic disagreement, per-type accuracy and dictionary coverage.
  ///
  /// The backend currently resolves the language from the active course, so
  /// [language] is sent for forward compatibility only.
  Future<Diagnostics> getDiagnostics({int days = 30, String? language}) async {
    final r = await _client.get('/api/v1/stats/diagnostics', queryParameters: {
      'days': days,
      if (language != null) 'language': language,
    });
    return Diagnostics.fromJson(r.data as Map<String, dynamic>);
  }
}
