import 'api_client.dart';

/// Portefeuille de l'utilisateur (GET /api/me/wallet).
class WalletApi {
  final ApiClient _client;
  WalletApi([ApiClient? client]) : _client = client ?? ApiClient();

  Future<Map<String, dynamic>> getWallet() async {
    final data = await _client.get('/api/me/wallet');
    return Map<String, dynamic>.from(data as Map);
  }
}
