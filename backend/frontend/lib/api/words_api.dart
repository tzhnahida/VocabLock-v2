import '../models/word.dart';
import '../models/question.dart';
import 'api_client.dart';

class WordsApi {
  final ApiClient _client;

  WordsApi(this._client);

  Future<({List<Word> words, int total})> list({
    String? language,
    int limit = 50,
    int offset = 0,
  }) async {
    final r = await _client.get('/api/v1/words', queryParameters: {
      if (language != null) 'language': language,
      'limit': limit,
      'offset': offset,
    });
    final data = r.data as Map<String, dynamic>;
    final words = (data['words'] as List<dynamic>)
        .map((j) => Word.fromJson(j as Map<String, dynamic>))
        .toList();
    final total = (data['total'] as num?)?.toInt() ?? words.length;
    return (words: words, total: total);
  }

  Future<Word> get(int id) async {
    final r = await _client.get('/api/v1/words/$id');
    return Word.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Word> create(Map<String, dynamic> body) async {
    final r = await _client.post('/api/v1/words', data: body);
    return Word.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Word> update(int id, Map<String, dynamic> body) async {
    final r = await _client.put('/api/v1/words/$id', data: body);
    return Word.fromJson(r.data as Map<String, dynamic>);
  }

  Future<bool> delete(int id) async {
    final r = await _client.delete('/api/v1/words/$id');
    return (r.data as Map<String, dynamic>)['deleted'] == true;
  }

  Future<bool> reset(int id) async {
    final r = await _client.post('/api/v1/words/$id/reset');
    return (r.data as Map<String, dynamic>)['reset'] == true;
  }

  Future<List<Map<String, dynamic>>> exportWords({String? language}) async {
    final r = await _client.get('/api/v1/words/export', queryParameters: {
      if (language != null) 'language': language,
    });
    return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<({int imported, int skipped, List<String>? errors})> importWords(
    List<Map<String, dynamic>> words,
  ) async {
    final r = await _client.post('/api/v1/words/import', data: words);
    final data = r.data as Map<String, dynamic>;
    return (
      imported: (data['imported'] as num?)?.toInt() ?? 0,
      skipped: (data['skipped'] as num?)?.toInt() ?? 0,
      errors: (data['errors'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Future<Map<String, dynamic>> expand({int count = 5, List<String>? context}) async {
    final r = await _client.post('/api/v1/words/expand', data: {
      'count': count,
      if (context != null) 'context': context,
    });
    return r.data as Map<String, dynamic>;
  }

  // —— Pending Review ——

  Future<List<Word>> listPendingReview({String? language}) async {
    final r = await _client.get('/api/v1/words/pending-review', queryParameters: {
      if (language != null) 'language': language,
    });
    final data = r.data as Map<String, dynamic>;
    return (data['words'] as List<dynamic>)
        .map((j) => Word.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Word> acceptPendingReview(int id, {required String reading, required String meaning, required String pos, String level = ''}) async {
    final r = await _client.post('/api/v1/words/pending-review/$id/accept', data: {
      'reading': reading,
      'meaning': meaning,
      'pos': pos,
      'level': level,
    });
    return Word.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> rejectPendingReview(int id, {String? reason}) async {
    await _client.post('/api/v1/words/pending-review/$id/reject', data: {
      if (reason != null) 'reason': reason,
    });
  }

  // —— Tags ——

  Future<void> updateTags(int id, List<String> tags) async {
    await _client.put('/api/v1/words/$id/tags', data: {'tags': tags});
  }

  // —— Grammar Points ——

  Future<({List<GrammarPoint> points, int total})> listGrammarPoints({
    String? language,
    int limit = 50,
    int offset = 0,
  }) async {
    final r = await _client.get('/api/v1/grammar-points', queryParameters: {
      if (language != null) 'language': language,
      'limit': limit,
      'offset': offset,
    });
    final data = r.data as Map<String, dynamic>;
    final points = (data['grammar_points'] as List<dynamic>)
        .map((j) => GrammarPoint.fromJson(j as Map<String, dynamic>))
        .toList();
    final total = (data['total'] as num?)?.toInt() ?? points.length;
    return (points: points, total: total);
  }

  Future<GrammarPoint> createGrammarPoint(Map<String, dynamic> body) async {
    final r = await _client.post('/api/v1/grammar-points', data: body);
    return GrammarPoint.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> updateGrammarPoint(int id, Map<String, dynamic> body) async {
    await _client.put('/api/v1/grammar-points/$id', data: body);
  }

  Future<void> deleteGrammarPoint(int id) async {
    await _client.delete('/api/v1/grammar-points/$id');
  }
}
