import '../auth/auth_session.dart';
import '../prefs/dialect_prefs.dart';
import 'api_client.dart';

/// Auth mobile : email/mot de passe + téléphone/OTP.
class AuthApi {
  final ApiClient _client;
  AuthApi([ApiClient? client]) : _client = client ?? ApiClient();

  /// Route de destination après une authentification réussie.
  static String nextRoute() =>
      AuthSession.instance.profileComplete ? '/dashboard' : '/profile-setup';

  Future<void> login(String email, String password) async {
    final data = await _client.post('/api/auth/login', {'email': email, 'password': password});
    final map = data as Map;
    AuthSession.instance.setTokens(map['access'] as String?, map['refresh'] as String?);
    if (map['user'] != null) {
      AuthSession.instance.setProfile(Map<String, dynamic>.from(map['user'] as Map));
    }
    await DialectPrefs.clearUser();
    await refreshMe();
  }

  Future<void> register(String name, String email, String password) async {
    final data = await _client.post('/api/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    final map = data as Map;
    AuthSession.instance.setTokens(map['access'] as String?, map['refresh'] as String?);
    if (map['user'] != null) {
      AuthSession.instance.setProfile(Map<String, dynamic>.from(map['user'] as Map));
    }
    await DialectPrefs.clearUser();
    await refreshMe();
  }

  Future<void> requestOtp(String phone) async {
    await _client.post('/api/auth/otp', {'phone': phone});
  }

  /// Recharge le profil courant (points/niveau à jour) depuis GET /api/me.
  Future<void> refreshMe() async {
    final data = await _client.get('/api/me');
    AuthSession.instance.setProfile(Map<String, dynamic>.from(data as Map));
  }

  /// Enregistre le profil linguistique côté serveur puis rafraîchit /me.
  Future<void> saveProfile({
    required String language,
    required String dialect,
    required String region,
    required bool commercialConsent,
  }) async {
    await _client.post('/api/me/profile', {
      'language': language, 'dialect': dialect, 'region': region,
      'commercialConsent': commercialConsent,
    });
    await refreshMe();
  }

  Future<void> verifyOtp(String phone, String code) async {
    final data = await _client.post('/api/auth/verify', {'phone': phone, 'code': code});
    final map = data as Map;
    AuthSession.instance.setTokens(map['access'] as String?, map['refresh'] as String?);
    if (map['user'] != null) {
      AuthSession.instance.setProfile(Map<String, dynamic>.from(map['user'] as Map));
    }
    await DialectPrefs.clearUser();
    await refreshMe();
  }
}
