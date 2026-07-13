import 'package:shared_preferences/shared_preferences.dart';

/// Persiste toutes les préférences utilisateur de l'app SabiData.
/// Les données survivent aux redémarrages de l'app.
class DialectPrefs {
  // ── Clés ──────────────────────────────────────────────────────────────────
  static const _keyDialect      = 'dialect_name';
  static const _keyRegion       = 'dialect_region';
  static const _keyLang         = 'dialect_lang';
  static const _keyRare         = 'dialect_rare';
  static const _keyLangs        = 'dialect_langs';
  static const _keyWriteLevel   = 'dialect_write_level';
  static const _keyOnboarding   = 'onboarding_done';    // Onboarding vu au moins 1 fois
  static const _keyProfileSetup = 'profile_setup_done'; // Formulaire profil complété
  static const _keyConsent      = 'consent_accepted';   // Politique acceptée (1 seule fois)

  // ── Cache mémoire ─────────────────────────────────────────────────────────
  static String? _dialect;
  static String? _region;
  static String? _lang;
  static int          _rare        = 0;
  static List<String> _langs       = [];
  static int          _writeLevel  = 0;
  static bool         _onboarding  = false;
  static bool         _profileDone = false;
  static bool         _consent     = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  static String? get dialect       => _dialect;
  static String? get region        => _region;
  static String? get lang          => _lang;
  static int     get rare          => _rare;
  static List<String> get langs    => _langs;
  static int     get writeLevel    => _writeLevel;
  static bool    get onboardingDone  => _onboarding;
  static bool    get profileSetupDone => _profileDone;
  static bool    get consentAccepted  => _consent;

  /// Langue principale (première de la liste ou fallback).
  static String get primaryLang =>
      _langs.isNotEmpty ? _langs.first : (_lang ?? 'Mooré');

  /// Multiplicateur de points selon la rareté.
  static String get rareLabel {
    switch (_rare) {
      case 2: return '×3 pts · Très rare';
      case 1: return '×2 pts · Rare';
      default: return '';
    }
  }

  // ── Chargement au démarrage ───────────────────────────────────────────────
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _dialect     = p.getString(_keyDialect);
    _region      = p.getString(_keyRegion);
    _lang        = p.getString(_keyLang);
    _rare        = p.getInt(_keyRare) ?? 0;
    _langs       = p.getStringList(_keyLangs) ?? [];
    _writeLevel  = p.getInt(_keyWriteLevel) ?? 0;
    _onboarding  = p.getBool(_keyOnboarding)   ?? false;
    _profileDone = p.getBool(_keyProfileSetup)  ?? false;
    _consent     = p.getBool(_keyConsent)        ?? false;
  }

  // ── Sauvegarde partielle (tous les paramètres sont optionnels) ────────────
  static Future<void> save({
    String?       dialect,
    String?       region,
    String?       lang,
    int?          rare,
    List<String>? langs,
    int?          writeLevel,
    bool?         onboardingDone,
    bool?         profileSetupDone,
    bool?         consentAccepted,
  }) async {
    if (dialect         != null) _dialect     = dialect;
    if (region          != null) _region      = region;
    if (lang            != null) _lang        = lang;
    if (rare            != null) _rare        = rare;
    if (langs           != null) _langs       = langs;
    if (writeLevel      != null) _writeLevel  = writeLevel;
    if (onboardingDone  != null) _onboarding  = onboardingDone;
    if (profileSetupDone != null) _profileDone = profileSetupDone;
    if (consentAccepted != null) _consent     = consentAccepted;

    final p = await SharedPreferences.getInstance();
    await Future.wait([
      if (dialect          != null) p.setString(_keyDialect,     _dialect!),
      if (region           != null) p.setString(_keyRegion,      _region!),
      if (lang             != null) p.setString(_keyLang,        _lang!),
      if (rare             != null) p.setInt(   _keyRare,        _rare),
      if (langs            != null) p.setStringList(_keyLangs,   _langs),
      if (writeLevel       != null) p.setInt(_keyWriteLevel,     _writeLevel),
      if (onboardingDone   != null) p.setBool(_keyOnboarding,    _onboarding),
      if (profileSetupDone != null) p.setBool(_keyProfileSetup,  _profileDone),
      if (consentAccepted  != null) p.setBool(_keyConsent,       _consent),
    ]);
  }

  /// Efface toutes les données sauf l'onboarding (ne pas ré-afficher).
  static Future<void> clearUser() async {
    _dialect = null; _region = null; _lang = null; _rare = 0;
    _langs = []; _writeLevel = 0; _profileDone = false; _consent = false;
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.remove(_keyDialect),
      p.remove(_keyRegion),
      p.remove(_keyLang),
      p.remove(_keyRare),
      p.remove(_keyLangs),
      p.remove(_keyWriteLevel),
      p.remove(_keyProfileSetup),
      p.remove(_keyConsent),
    ]);
  }
}
