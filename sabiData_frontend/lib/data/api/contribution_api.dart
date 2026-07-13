import 'api_client.dart';

/// Contribution : soumission d'un enregistrement (POST /api/clips).
class ContributionApi {
  final ApiClient _client;
  ContributionApi([ApiClient? client]) : _client = client ?? ApiClient();

  /// Renvoie la réponse serveur : `{ clipId, status, reward, licenseTag }`.
  Future<Map<String, dynamic>> submitClip({
    required int rarity,
    required int durationS,
    required bool commercialUse,
    required String consentVersion,
    required String audioPath,
    String? promptId,
    String? language,
    String? dialect,
    String? region,
  }) async {
    final fields = <String, String>{
      'rarity': rarity.toString(),
      'durationS': durationS.toString(),
      'commercialUse': commercialUse.toString(),
      'consentVersion': consentVersion,
      'promptId': ?promptId,
      'language': ?language,
      'dialect': ?dialect,
      'region': ?region,
    };
    final data = await _client.postMultipart('/api/clips', fields, filePath: audioPath);
    return Map<String, dynamic>.from(data as Map);
  }
}
