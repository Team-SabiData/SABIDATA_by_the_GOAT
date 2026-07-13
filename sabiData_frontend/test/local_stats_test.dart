import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabidata_app/data/gamification/local_stats.dart';

void main() {
  final today = DateTime(2026, 7, 4);

  group('computeStreak', () {
    test('vide → 0', () {
      expect(computeStreak([], today), 0);
    });
    test('aujourd\'hui seul → 1', () {
      expect(computeStreak([DateTime(2026, 7, 4)], today), 1);
    });
    test('3 jours consécutifs finissant aujourd\'hui → 3', () {
      expect(
        computeStreak([
          DateTime(2026, 7, 2),
          DateTime(2026, 7, 3),
          DateTime(2026, 7, 4),
        ], today),
        3,
      );
    });
    test('série finissant hier reste vivante → 2', () {
      expect(
        computeStreak([DateTime(2026, 7, 2), DateTime(2026, 7, 3)], today),
        2,
      );
    });
    test('trou avant-hier → série cassée → 0', () {
      expect(computeStreak([DateTime(2026, 7, 1)], today), 0);
    });
  });

  group('LocalStats', () {
    test('recordSubmission incrémente le compteur du jour', () async {
      SharedPreferences.setMockInitialValues({});
      final stats = LocalStats();
      await stats.recordSubmission(today);
      await stats.recordSubmission(today);
      expect(await stats.todaySubmissions(today), 2);
      expect(await stats.streak(today), 1);
    });
    test('recordValidation compte à part', () async {
      SharedPreferences.setMockInitialValues({});
      final stats = LocalStats();
      await stats.recordValidation(today);
      expect(await stats.todayValidations(today), 1);
      expect(await stats.todaySubmissions(today), 0);
    });
  });
}
