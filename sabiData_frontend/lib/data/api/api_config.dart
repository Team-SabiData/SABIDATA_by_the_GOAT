/// Configuration de l'accès au backend SabiData.
class ApiConfig {
  /// URL de base de l'API.
  ///
  /// Téléphone physique sur le même réseau Wi-Fi que le PC :
  /// IP locale du PC + port du backend. (Émulateur : `http://10.0.2.2:3000`.)
  static const String baseUrl = 'http://192.168.100.189:3000';
}
