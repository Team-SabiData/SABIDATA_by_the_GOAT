import 'api_client.dart';

/// File de transcription : clip validé à transcrire (GET /api/transcriptions/next)
/// + soumission (POST /api/transcriptions).
class TranscriptionApi {
  final ApiClient _client;
  TranscriptionApi([ApiClient? client]) : _client = client ?? ApiClient();

  /// Prochain clip validé à transcrire (dans la langue de l'utilisateur),
  /// ou `null` si la file est vide (204).
  Future<Map<String, dynamic>?> next() async {
    final data = await _client.get('/api/transcriptions/next');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Soumet une transcription pour un clip. Renvoie `{ id, reward }`.
  Future<Map<String, dynamic>> submit(String clipId, String text) async {
    final data = await _client.post('/api/transcriptions', {
      'clipId': clipId,
      'text': text,
      'writingSystem': 'std',
      'consistency': 0.6,
    });
    return Map<String, dynamic>.from(data as Map);
  }
}
