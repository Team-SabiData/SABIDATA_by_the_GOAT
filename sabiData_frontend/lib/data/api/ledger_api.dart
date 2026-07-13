import 'api_client.dart';

/// Historique des gains de l'utilisateur (GET /api/me/ledger).
class LedgerApi {
  final ApiClient _client;
  LedgerApi([ApiClient? client]) : _client = client ?? ApiClient();

  Future<List<Map<String, dynamic>>> history() async {
    final data = await _client.get('/api/me/ledger');
    final entries = (data as Map)['entries'] as List? ?? [];
    return entries.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
