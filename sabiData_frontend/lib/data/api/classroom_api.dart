import 'api_client.dart';

/// Classroom : groupe de collecte rejoint par code d'invitation.
class ClassroomApi {
  final ApiClient _client;
  ClassroomApi([ApiClient? client]) : _client = client ?? ApiClient();

  /// Mon classroom courant (avec stats de groupe) ou `null`.
  Future<Map<String, dynamic>?> mine() async {
    final data = await _client.get('/api/classrooms/mine') as Map;
    final cls = data['classroom'];
    return cls == null ? null : Map<String, dynamic>.from(cls as Map);
  }

  /// Crée un classroom (on le rejoint et on reçoit un code d'invitation).
  Future<Map<String, dynamic>> create(String name, String description) async {
    final data = await _client.post('/api/classrooms', {'name': name, 'description': description});
    return Map<String, dynamic>.from((data as Map)['classroom'] as Map);
  }

  /// Rejoint un classroom via son code d'invitation.
  Future<Map<String, dynamic>> join(String code) async {
    final data = await _client.post('/api/classrooms/join', {'code': code});
    return Map<String, dynamic>.from((data as Map)['classroom'] as Map);
  }

  /// Quitte le classroom courant.
  Future<void> leave() async {
    await _client.post('/api/classrooms/leave', {});
  }
}
