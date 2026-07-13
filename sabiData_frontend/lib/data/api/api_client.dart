import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../auth/auth_session.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// Client HTTP minimal : JSON + jeton Bearer + mapping d'erreurs.
class ApiClient {
  final http.Client _http;
  ApiClient([http.Client? client]) : _http = client ?? http.Client();

  Map<String, String> _headers() {
    final token = AuthSession.instance.token.value;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Les routes d'auth (login/register/otp/verify/refresh) ne doivent PAS
  // déclencher le refresh-sur-401 : un 401 y signifie de mauvais identifiants,
  // pas un token expiré.
  bool _isAuth(String path) => path.startsWith('/api/auth/');

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    return _send(
      () => _http.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers(),
        body: jsonEncode(body),
      ),
      retry: !_isAuth(path),
    );
  }

  Future<dynamic> get(String path) async {
    return _send(
      () => _http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers()),
      retry: !_isAuth(path),
    );
  }

  /// Envoie un fichier + champs en multipart/form-data (upload de clip audio).
  Future<dynamic> postMultipart(
    String path,
    Map<String, String> fields, {
    required String filePath,
    String fileField = 'audio',
    String contentType = 'audio/mp4',
  }) async {
    // Reconstruit la requête à chaque essai (le fichier/flux ne se rejoue pas).
    Future<http.Response> attempt() async {
      final req = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'));
      final token = AuthSession.instance.token.value;
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields.addAll(fields);
      req.files.add(await http.MultipartFile.fromPath(fileField, filePath, contentType: MediaType.parse(contentType)));
      final streamed = await _http.send(req);
      return http.Response.fromStream(streamed);
    }

    http.Response res;
    try {
      res = await attempt();
    } catch (_) {
      throw ApiException('Serveur injoignable. Vérifiez votre connexion.');
    }
    // Token expiré → refresh puis re-tentative une fois.
    if (res.statusCode == 401 && !_isAuth(path) && await _refreshAccess()) {
      try {
        res = await attempt();
      } catch (_) {
        throw ApiException('Serveur injoignable. Vérifiez votre connexion.');
      }
    }
    return _decode(res);
  }

  /// Télécharge un corps binaire (ex. réécoute d'un clip audio).
  Future<Uint8List> getBytes(String path) async {
    http.Response res;
    try {
      res = await _http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers());
    } catch (_) {
      throw ApiException('Serveur injoignable. Vérifiez votre connexion.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Erreur ${res.statusCode}', statusCode: res.statusCode);
    }
    return res.bodyBytes;
  }

  Future<dynamic> _send(Future<http.Response> Function() run, {bool retry = true}) async {
    http.Response res;
    try {
      res = await run();
    } catch (_) {
      throw ApiException('Serveur injoignable. Vérifiez votre connexion.');
    }
    // Access token expiré → tenter un refresh puis rejouer la requête une fois.
    if (res.statusCode == 401 && retry && await _refreshAccess()) {
      try {
        res = await run();
      } catch (_) {
        throw ApiException('Serveur injoignable. Vérifiez votre connexion.');
      }
    }
    return _decode(res);
  }

  /// Renouvelle l'access token via le refresh token. Ne passe pas par [_send]
  /// (évite la boucle). Vide la session si le refresh est explicitement refusé.
  Future<bool> _refreshAccess() async {
    final rt = AuthSession.instance.refreshToken;
    if (rt == null) return false;
    http.Response res;
    try {
      res = await _http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': rt}),
      );
    } catch (_) {
      return false; // réseau : garder la session
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map;
      AuthSession.instance.setTokens(data['access'] as String?, data['refresh'] as String?);
      return true;
    }
    AuthSession.instance.clear(); // refresh refusé → session invalide
    return false;
  }

  dynamic _decode(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = res.body;
      }
    }
    if (!ok) {
      String? code;
      String message = 'Erreur ${res.statusCode}';
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        code = err['code']?.toString();
        message = err['message']?.toString() ?? message;
      }
      throw ApiException(message, statusCode: res.statusCode, code: code);
    }
    return data;
  }
}
