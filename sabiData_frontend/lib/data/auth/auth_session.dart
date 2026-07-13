import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profil minimal de l'utilisateur connecté (rempli après login/register).
class UserProfile {
  final String id;
  final String name;
  final String role;
  final int competence;
  final int points;
  final int contributionsValidated;
  final String level; // 'bronze' | 'argent' | 'or'
  final bool profileComplete;
  final bool commercialConsent;
  final String? language;
  final String? dialect;
  final String? region;
  final String? email;
  final String? phone;
  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.competence,
    this.points = 0,
    this.contributionsValidated = 0,
    this.level = 'bronze',
    this.profileComplete = false,
    this.commercialConsent = false,
    this.language,
    this.dialect,
    this.region,
    this.email,
    this.phone,
  });

  /// Initiales pour l'avatar (ex: "Adama Ouédraogo" → "AO").
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id:          j['id']?.toString()          ?? '',
    name:        j['name']?.toString()        ?? 'Contributeur',
    role:        j['role']?.toString()        ?? 'contributor',
    competence:  (j['competence'] as num?)?.toInt() ?? 0,
    points:      (j['points'] as num?)?.toInt() ?? 0,
    contributionsValidated: (j['contributionsValidated'] as num?)?.toInt() ?? 0,
    level:       j['level']?.toString()       ?? 'bronze',
    profileComplete:    j['profileComplete'] == true,
    commercialConsent:  j['commercialConsent'] == true,
    language:    j['language']?.toString(),
    dialect:     j['dialect']?.toString(),
    region:      j['region']?.toString(),
    email:       j['email']?.toString(),
    phone:       j['phone']?.toString(),
  );
}

/// Détient le jeton d'accès courant et le profil utilisateur.
/// Le token est persisté (shared_preferences) pour garder la session entre
/// deux lancements de l'app. NOTE sécurité : passer à flutter_secure_storage
/// (chiffré) avant la prod.
class AuthSession {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  static const _kToken = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kProfile = 'auth_profile';

  final ValueNotifier<String?> token = ValueNotifier<String?>(null);
  final ValueNotifier<UserProfile?> user  = ValueNotifier<UserProfile?>(null);

  /// Refresh token (renouvelle l'access token expiré). Non réactif.
  String? refreshToken;

  bool get isAuthenticated => token.value != null;

  bool get canDoActivities {
    final u = user.value;
    return u != null && u.profileComplete && u.commercialConsent;
  }
  bool get profileComplete => user.value?.profileComplete ?? false;

  /// Enregistre la paire de jetons (access + refresh) et la persiste.
  void setTokens(String? access, String? refresh) {
    token.value = access;
    refreshToken = refresh;
    unawaited(_persist(access, refresh));
  }

  Future<void> _persist(String? access, String? refresh) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      access == null ? p.remove(_kToken) : p.setString(_kToken, access),
      refresh == null ? p.remove(_kRefresh) : p.setString(_kRefresh, refresh),
    ]);
  }

  /// Restaure jetons ET dernier profil connu au démarrage (avant le premier
  /// rendu). Le profil persisté permet un routage et un affichage corrects
  /// même hors-ligne (le token seul ne suffit pas — profileComplete retomberait
  /// à false et renverrait à tort vers /profile-setup).
  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    token.value = p.getString(_kToken);
    refreshToken = p.getString(_kRefresh);
    final rawProfile = p.getString(_kProfile);
    if (rawProfile != null) {
      try {
        user.value = UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(rawProfile) as Map));
      } catch (_) {/* profil corrompu : ignoré */}
    }
  }

  void setProfile(Map<String, dynamic> json) {
    user.value = UserProfile.fromJson(json);
    unawaited(_persistProfile(json));
  }

  Future<void> _persistProfile(Map<String, dynamic> json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProfile, jsonEncode(json));
  }

  void clear() {
    token.value = null;
    refreshToken = null;
    user.value  = null;
    unawaited(_persist(null, null));
    unawaited(SharedPreferences.getInstance().then((p) => p.remove(_kProfile)));
  }
}
