import 'api_client.dart';

class AiApi {
  final ApiClient _client;

  AiApi(this._client);

  Future<Map<String, dynamic>> chat(String message, {List<Map<String, String>>? history}) async {
    final r = await _client.post('/api/v1/ai/chat', data: {
      'message': message,
      if (history != null) 'history': history,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final r = await _client.get('/api/v1/ai/profile');
    return r.data as Map<String, dynamic>;
  }
}
