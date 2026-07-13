import 'api_client.dart';

/// File de validation (GET /api/validation/next, POST /api/clips/:id/validations).
class ValidationApi {
  final ApiClient _client;
  ValidationApi([ApiClient? client]) : _client = client ?? ApiClient();

  /// Prochain clip à valider, ou `null` si la file est vide (204).
  Future<Map<String, dynamic>?> next() async {
    final data = await _client.get('/api/validation/next');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Renvoie `{ status, reward }`.
  Future<Map<String, dynamic>> submitVerdict(String clipId, String verdict) async {
    final data = await _client.post('/api/clips/$clipId/validations', {'verdict': verdict});
    return Map<String, dynamic>.from(data as Map);
  }
}
