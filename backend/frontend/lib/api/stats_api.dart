import '../models/stats.dart';
import 'api_client.dart';

class StatsApi {
  final ApiClient _client;

  StatsApi(this._client);

  Future<Map<String, int>> getHeatmap({int days = 90}) async {
    final r = await _client.get('/api/v1/stats/heatmap', queryParameters: {'days': days});
    final data = r.data as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<int> getStreak() async {
    final r = await _client.get('/api/v1/stats/streak');
    final data = r.data as Map<String, dynamic>;
    return (data['streak'] as num?)?.toInt() ?? 0;
  }

  Future<DailyReport> getDailyReport() async {
    final r = await _client.get('/api/v1/stats/daily-report');
    return DailyReport.fromJson(r.data as Map<String, dynamic>);
  }
}
