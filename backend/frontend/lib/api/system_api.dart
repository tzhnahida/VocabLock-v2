import 'api_client.dart';

class SystemApi {
  final ApiClient _client;

  SystemApi(this._client);

  Future<Map<String, dynamic>> getStatus() async {
    final r = await _client.get('/api/v1/system/status');
    return r.data as Map<String, dynamic>;
  }

  Future<bool> lock() async {
    final r = await _client.post('/api/v1/system/lock');
    return (r.data as Map<String, dynamic>)['locked'] == true;
  }

  Future<bool> unlock() async {
    final r = await _client.post('/api/v1/system/unlock');
    return (r.data as Map<String, dynamic>)['locked'] == false;
  }

  /// One due word for the passive recall card: word_id / word / reading /
  /// meaning. An empty word means nothing is due right now.
  Future<Map<String, dynamic>> getPassiveQ() async {
    final r = await _client.get('/api/v1/system/passive-q');
    return r.data as Map<String, dynamic>;
  }

  /// Reports a passive recall self-assessment for one word.
  ///
  /// [recall] is one of "easy" (quality 4), "hard" (3) or "forgot" (1) — see
  /// engine.QualityFromPassiveRecall. Submitting is what makes the card count:
  /// the backend applies the light SM-2 update and writes a review_log row.
  Future<bool> passiveSubmit({int wordId = 0, String recall = ''}) async {
    final r = await _client.post('/api/v1/system/passive-submit', data: {
      'word_id': wordId,
      if (recall.isNotEmpty) 'recall': recall,
    });
    return (r.data as Map<String, dynamic>)['accepted'] == true;
  }

  Future<bool> quit() async {
    final r = await _client.post('/api/v1/system/quit');
    return (r.data as Map<String, dynamic>)['quitting'] == true;
  }

  Future<bool> restart() async {
    final r = await _client.post('/api/v1/system/restart');
    return (r.data as Map<String, dynamic>)['restarted'] == true;
  }
}
