import 'api_client.dart';

class ConfigApi {
  final ApiClient _client;

  ConfigApi(this._client);

  Future<Map<String, dynamic>> getConfig() async {
    final r = await _client.get('/api/v1/config');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConfigKey(String key) async {
    final r = await _client.get('/api/v1/config/$key');
    return r.data as Map<String, dynamic>;
  }

  Future<List<String>> getLanguages() async {
    final r = await _client.get('/api/v1/config/languages');
    final data = r.data as Map<String, dynamic>;
    return (data['value'] as List<dynamic>).cast<String>();
  }

  Future<Map<String, dynamic>> updateConfig({
    String? activeLang,
    String? interfaceLang,
    int? dailyTarget,
    int? dailyTimeTarget,
    Map<String, dynamic>? assignment,
    String? theme,
  }) async {
    final body = <String, dynamic>{};
    if (activeLang != null) body['active_lang'] = activeLang;
    if (interfaceLang != null) body['interface_lang'] = interfaceLang;
    if (dailyTarget != null) body['daily_target'] = dailyTarget;
    if (dailyTimeTarget != null) body['daily_time_target'] = dailyTimeTarget;
    if (assignment != null) body['assignment'] = assignment;
    if (theme != null) body['theme'] = theme;
    final r = await _client.put('/api/v1/config', data: body);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateConfigRaw(Map<String, dynamic> body) async {
    final r = await _client.put('/api/v1/config', data: body);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setPassword(String password) async {
    final r = await _client.post('/api/v1/config/password', data: {'password': password});
    return r.data as Map<String, dynamic>;
  }

  // —— AI ——

  Future<Map<String, dynamic>> getAIConfig() async {
    final r = await _client.get('/api/v1/config/ai');
    return r.data as Map<String, dynamic>;
  }

  Future<void> updateAIConfig({String? baseUrl, String? apiKey, String? model}) async {
    final body = <String, dynamic>{};
    if (baseUrl != null) body['base_url'] = baseUrl;
    if (apiKey != null) body['api_key'] = apiKey;
    if (model != null) body['model'] = model;
    await _client.put('/api/v1/config/ai', data: body);
  }

  // —— TTS ——

  Future<Map<String, dynamic>> getTTSConfig() async {
    final r = await _client.get('/api/v1/config/tts');
    return r.data as Map<String, dynamic>;
  }

  Future<void> saveTTSProvider(String name, Map<String, dynamic> data) async {
    await _client.put('/api/v1/config/tts/$name', data: data);
  }

  Future<void> deleteTTSProvider(String name) async {
    await _client.delete('/api/v1/config/tts/$name');
  }

  // —— Dict ——

  Future<Map<String, dynamic>> getDictConfig() async {
    final r = await _client.get('/api/v1/config/dict');
    return r.data as Map<String, dynamic>;
  }

  Future<void> saveDictProvider(String name, Map<String, dynamic> data) async {
    await _client.put('/api/v1/config/dict/$name', data: data);
  }

  Future<void> deleteDictProvider(String name) async {
    await _client.delete('/api/v1/config/dict/$name');
  }

  // —— Language ——

  Future<Map<String, dynamic>> getLanguageConfig(String code) async {
    final r = await _client.get('/api/v1/config/language/$code');
    return r.data as Map<String, dynamic>;
  }

  Future<void> updateLanguageConfig(String code, Map<String, dynamic> data) async {
    await _client.put('/api/v1/config/language/$code', data: data);
  }
}
