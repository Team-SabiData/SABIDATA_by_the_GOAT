import 'api_client.dart';

/// Couverture linguistique par région (GET /api/regions).
class RegionsApi {
  final ApiClient _client;
  RegionsApi([ApiClient? client]) : _client = client ?? ApiClient();

  Future<List<Map<String, dynamic>>> coverage() async {
    final data = await _client.get('/api/regions');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
