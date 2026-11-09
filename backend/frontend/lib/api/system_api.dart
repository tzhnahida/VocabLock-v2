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

  Future<Map<String, dynamic>> getPassiveQ() async {
    final r = await _client.get('/api/v1/system/passive-q');
    return r.data as Map<String, dynamic>;
  }

  Future<bool> passiveSubmit() async {
    final r = await _client.post('/api/v1/system/passive-submit');
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
