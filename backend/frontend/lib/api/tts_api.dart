import 'api_client.dart';

class TtsApi {
  final ApiClient _client;

  TtsApi(this._client);

  Future<Map<String, dynamic>> getWordAudio(int wordId) async {
    final r = await _client.get('/api/v1/tts/word/$wordId');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTextAudio(String text, {String? voice}) async {
    final r = await _client.post('/api/v1/tts/text', data: {
      'text': text,
      if (voice != null) 'voice': voice,
    });
    return r.data as Map<String, dynamic>;
  }
}
