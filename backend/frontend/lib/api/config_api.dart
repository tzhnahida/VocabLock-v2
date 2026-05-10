import 'api_client.dart';

class ConfigApi {
  final ApiClient _client;

  ConfigApi(this._client);

  Future<Map<String, dynamic>> getConfig() async {
    final r = await _client.get('/api/v1/config');
    return r.data as Map<String, dynamic>;
  }

  Future<List<String>> getLanguages() async {
    final r = await _client.get('/api/v1/config/languages');
    final value = (r.data as Map<String, dynamic>)['value'];
    return (value as List<dynamic>).cast<String>();
  }

  Future<Map<String, dynamic>> updateConfig({
    String? activeLang,
    int? dailyTarget,
  }) async {
    final body = <String, dynamic>{};
    if (activeLang != null) body['active_lang'] = activeLang;
    if (dailyTarget != null) body['daily_target'] = dailyTarget;
    final r = await _client.put('/api/v1/config', data: body);
    return r.data as Map<String, dynamic>;
  }
}
