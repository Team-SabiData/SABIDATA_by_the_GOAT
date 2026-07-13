import 'package:shared_preferences/shared_preferences.dart';

/// Série de jours consécutifs (avec ≥ 1 contribution) se terminant
/// aujourd'hui ou hier — une série finissant hier reste « vivante ».
int computeStreak(List<DateTime> days, DateTime today) {
  if (days.isEmpty) return 0;
  final set = days.map((d) => DateTime(d.year, d.month, d.day)).toSet();
  final t = DateTime(today.year, today.month, today.day);
  var cursor = set.contains(t) ? t : t.subtract(const Duration(days: 1));
  if (!set.contains(cursor)) return 0;
  var streak = 0;
  while (set.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Stats de gamification purement locales (shared_preferences) : série,
/// défi du jour, compteur de validations. Aucun appel réseau — branchable
/// sur le backend plus tard s'il expose ces données.
class LocalStats {
  static const int dailyGoal = 5;
  static const _kDays = 'gamification.submission_days';
  static const _kSubs = 'gamification.today_submissions';
  static const _kVals = 'gamification.today_validations';

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> recordSubmission([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getStringList(_kDays) ?? [];
    if (!days.contains(_dayKey(d))) {
      days.add(_dayKey(d));
      // borne la liste aux 60 derniers jours enregistrés
      while (days.length > 60) {
        days.removeAt(0);
      }
      await prefs.setStringList(_kDays, days);
    }
    await prefs.setInt('$_kSubs.${_dayKey(d)}',
        (prefs.getInt('$_kSubs.${_dayKey(d)}') ?? 0) + 1);
  }

  Future<void> recordValidation([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_kVals.${_dayKey(d)}',
        (prefs.getInt('$_kVals.${_dayKey(d)}') ?? 0) + 1);
  }

  Future<int> streak([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final days = (prefs.getStringList(_kDays) ?? [])
        .map(DateTime.parse)
        .toList();
    return computeStreak(days, d);
  }

  Future<int> todaySubmissions([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kSubs.${_dayKey(d)}') ?? 0;
  }

  Future<int> todayValidations([DateTime? now]) async {
    final d = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kVals.${_dayKey(d)}') ?? 0;
  }
}
